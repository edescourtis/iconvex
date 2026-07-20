defmodule Iconvex.CoreStreamRecoveryParityTest do
  use ExUnit.Case, async: false

  alias Iconvex.{Error, InvalidByte, TableCodec, Tables}

  @cp1258_undefined [0x81, 0x8A, 0x8D, 0x8E, 0x8F, 0x90, 0x9A, 0x9D, 0x9E]

  @escape_cases [
                  {"C99", ~S(\u00e9)},
                  {"C99", ~S(\U0001f600)},
                  {"JAVA", ~S(\u00e9)},
                  {"JAVA", ~S(\ud83d\ude00)}
                ]
                |> Enum.flat_map(fn {encoding, complete} ->
                  for size <- 1..(byte_size(complete) - 1) do
                    sequence = binary_part(complete, 0, size)
                    {encoding, "ok" <> sequence, sequence}
                  end
                end)
                |> Enum.uniq()

  @stateful_incomplete_encodings [
    "ISO-2022-JP",
    "ISO-2022-JP-1",
    "ISO-2022-JP-2",
    "ISO-2022-JP-MS",
    "ISO-2022-KR",
    "ISO-2022-CN",
    "ISO-2022-CN-EXT"
  ]

  test "CP1258 and TCVN retain only real Vietnamese composition lookahead" do
    for {id, expected_undefined} <- [cp1258: @cp1258_undefined, tcvn: []] do
      entry = %{id: id}
      table = Tables.fetch!(id)

      undefined = for byte <- 0..255, elem(table.one, byte) == nil, do: byte
      assert undefined == expected_undefined

      for byte <- 0..255 do
        codepoints = elem(table.one, byte)

        cond do
          codepoints == nil ->
            assert TableCodec.decode_chunk(entry, <<byte>>, false) ==
                     {:error, :invalid_sequence, 0, <<byte>>}

            assert TableCodec.decode_chunk(entry, <<byte, ?0>>, false) ==
                     {:error, :invalid_sequence, 0, <<byte>>}

          MapSet.member?(table.vietnamese_base_bytes, byte) ->
            assert TableCodec.decode_chunk(entry, <<byte>>, false) == {:ok, [], <<byte>>}

            assert TableCodec.decode_chunk(entry, <<byte>>, true) ==
                     {:ok, Tuple.to_list(codepoints), <<>>}

          true ->
            assert TableCodec.decode_chunk(entry, <<byte>>, false) ==
                     {:ok, Tuple.to_list(codepoints), <<>>}
        end
      end
    end
  end

  test "CP1258 and TCVN composition remains exact in a whole chunk and every split" do
    for {id, encoding, known_encoded, known_expected} <- [
          {:cp1258, "CP1258", <<0x52, 0xF2>>, "Ṛ"},
          {:tcvn, "TCVN", <<0x68, 0xB4>>, "ḥ"}
        ] do
      assert Iconvex.convert(known_encoded, encoding, "UTF-8") == {:ok, known_expected}

      table = Tables.fetch!(id)

      for {encoded, codepoints} <- table.many do
        assert tuple_size(codepoints) == 1
        expected = codepoints |> Tuple.to_list() |> List.to_string()

        assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, expected}

        for split <- 0..byte_size(encoded) do
          assert stream_join(encoded, split, encoding, []) == expected,
                 "#{encoding} #{Base.encode16(encoded)} composition split #{split}"
        end
      end
    end
  end

  test "every CP1258 undefined byte is diagnosed and recovered individually at every split" do
    for byte <- @cp1258_undefined do
      input = <<?0, byte, ?1>>

      assert {:error,
              %Error{
                kind: :invalid_sequence,
                offset: 1,
                sequence: <<^byte>>
              }} = Iconvex.convert(input, "CP1258", "UTF-8")

      assert Iconvex.convert(input, "CP1258", "UTF-8", invalid: :discard) == {:ok, "01"}

      assert Iconvex.convert(input, "CP1258", "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, "0<#{hex2(byte)}>1"}

      {callback_result, [callback_event]} =
        capture_callback(fn callback ->
          Iconvex.convert(input, "CP1258", "UTF-8", on_invalid_byte: callback)
        end)

      assert callback_result == {:ok, "0?1"}
      assert_invalid_event(callback_event, "CP1258", :invalid_sequence, 1, byte, <<byte>>)

      for split <- 0..byte_size(input) do
        error =
          assert_raise Error, fn ->
            stream_join(input, split, "CP1258", [])
          end

        assert error.kind == :invalid_sequence
        assert error.offset == 1
        assert error.sequence == <<byte>>

        assert stream_join(input, split, "CP1258", invalid: :discard) == "01"

        assert stream_join(input, split, "CP1258", byte_substitute: "<%02x>") ==
                 "0<#{hex2(byte)}>1"

        {callback_output, [event]} =
          capture_callback(fn callback ->
            stream_join(input, split, "CP1258", on_invalid_byte: callback)
          end)

        assert callback_output == "0?1"
        assert_invalid_event(event, "CP1258", :invalid_sequence, 1, byte, <<byte>>)
      end
    end
  end

  test "final C99 and JAVA incomplete escapes recover as one reported source unit" do
    for {encoding, input, sequence} <- @escape_cases do
      expected_substitution = "ok" <> substitute_bytes(sequence)

      assert {:error,
              %Error{
                kind: :incomplete_sequence,
                offset: 2,
                sequence: ^sequence
              }} = Iconvex.convert(input, encoding, "UTF-8")

      assert Iconvex.convert(input, encoding, "UTF-8", invalid: :discard) == {:ok, "ok"}

      assert Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected_substitution}

      {callback_result, [callback_event]} =
        capture_callback(fn callback ->
          Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: callback)
        end)

      assert callback_result == {:ok, "ok?"}

      assert_invalid_event(
        callback_event,
        encoding,
        :incomplete_sequence,
        2,
        ?\\,
        sequence
      )

      for split <- 0..byte_size(input) do
        error =
          assert_raise Error, fn ->
            stream_join(input, split, encoding, [])
          end

        assert error.kind == :incomplete_sequence
        assert error.offset == 2
        assert error.sequence == sequence

        assert stream_join(input, split, encoding, invalid: :discard) == "ok",
               "#{encoding} discard split #{split} for #{inspect(sequence)}"

        assert stream_join(input, split, encoding, byte_substitute: "<%02x>") ==
                 expected_substitution,
               "#{encoding} substitution split #{split} for #{inspect(sequence)}"

        {callback_output, [event]} =
          capture_callback(fn callback ->
            stream_join(input, split, encoding, on_invalid_byte: callback)
          end)

        assert callback_output == "ok?"
        assert_invalid_event(event, encoding, :incomplete_sequence, 2, ?\\, sequence)
      end
    end
  end

  test "final stateful escape fragments recover as one source unit at every split" do
    sequence = <<0x1B, ?$>>
    input = "ok" <> sequence
    expected_substitution = "ok" <> substitute_bytes(sequence)

    for encoding <- @stateful_incomplete_encodings do
      assert_terminal_source_unit_contract(input, encoding, sequence, "ok")

      {valid_prefix, first_codepoint} = stateful_target_prefix(encoding)

      assert_earlier_target_error_suppresses_callback(
        valid_prefix,
        sequence,
        encoding,
        first_codepoint
      )

      assert Iconvex.convert(input, encoding, "UTF-8", invalid: :discard) == {:ok, "ok"}

      assert Iconvex.convert(input, encoding, "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected_substitution}

      for split <- 0..byte_size(input) do
        assert stream_join(input, split, encoding, invalid: :discard) == "ok",
               "#{encoding} discard split #{split}"

        assert stream_join(input, split, encoding, byte_substitute: "<%02x>") ==
                 expected_substitution,
               "#{encoding} substitution split #{split}"
      end
    end
  end

  test "ISO-2022-KR treats every short terminal escape as one incomplete unit" do
    for sequence <- [<<0x1B, ?)>>, <<0x1B, ?$, ?X>>, <<0x1B, ?X, ?Y>>] do
      input = "ok" <> sequence
      expected_substitution = "ok" <> substitute_bytes(sequence)

      assert_terminal_source_unit_contract(input, "ISO-2022-KR", sequence, "ok")

      {valid_prefix, first_codepoint} = stateful_target_prefix("ISO-2022-KR")

      assert_earlier_target_error_suppresses_callback(
        valid_prefix,
        sequence,
        "ISO-2022-KR",
        first_codepoint
      )

      assert Iconvex.convert(input, "ISO-2022-KR", "UTF-8", invalid: :discard) ==
               {:ok, "ok"}

      assert Iconvex.convert(input, "ISO-2022-KR", "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected_substitution}

      for split <- 0..byte_size(input) do
        assert stream_join(input, split, "ISO-2022-KR", invalid: :discard) == "ok"

        assert stream_join(input, split, "ISO-2022-KR", byte_substitute: "<%02x>") ==
                 expected_substitution
      end
    end
  end

  test "every EUC-TW incomplete table prefix has one-shot and streaming recovery parity" do
    entry = %{id: :euc_tw}
    prefixes = incomplete_table_prefixes(entry)

    assert length(prefixes) == 678
    assert Enum.frequencies_by(prefixes, &byte_size/1) == %{1 => 67, 2 => 8, 3 => 603}

    for sequence <- prefixes do
      expected_substitution = substitute_bytes(sequence)

      assert TableCodec.decode(entry, sequence) ==
               {:error, :incomplete_sequence, 0, sequence}

      assert_terminal_source_unit_contract("ok" <> sequence, "EUC-TW", sequence, "ok")

      assert_earlier_target_error_suppresses_callback(
        <<0x8E, 0xA4, 0xA9, 0xB8>>,
        sequence,
        "EUC-TW",
        140_811
      )

      assert Iconvex.convert(sequence, "EUC-TW", "UTF-8", invalid: :discard) == {:ok, ""}

      assert Iconvex.convert(sequence, "EUC-TW", "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected_substitution}

      for split <- 0..byte_size(sequence) do
        assert stream_join(sequence, split, "EUC-TW", invalid: :discard) == "",
               "EUC-TW discard split #{split} for #{Base.encode16(sequence)}"

        assert stream_join(sequence, split, "EUC-TW", byte_substitute: "<%02x>") ==
                 expected_substitution,
               "EUC-TW substitution split #{split} for #{Base.encode16(sequence)}"
      end
    end
  end

  defp stream_join(input, split, encoding, options) do
    stream_join_to(input, split, encoding, "UTF-8", options)
  end

  defp stream_join_to(input, split, source, target, options) do
    <<first::binary-size(split), second::binary>> = input

    [first, second]
    |> Iconvex.stream!(source, target, options)
    |> Enum.join()
  end

  defp assert_terminal_source_unit_contract(input, encoding, sequence, expected_prefix) do
    offset = byte_size(input) - byte_size(sequence)

    assert {:error,
            %Error{
              encoding: ^encoding,
              kind: :incomplete_sequence,
              offset: ^offset,
              sequence: ^sequence
            }} = Iconvex.convert(input, encoding, "UTF-8")

    {callback_result, [callback_event]} =
      capture_callback(fn callback ->
        Iconvex.convert(input, encoding, "UTF-8", on_invalid_byte: callback)
      end)

    assert callback_result == {:ok, expected_prefix <> "?"}

    assert_invalid_event(
      callback_event,
      encoding,
      :incomplete_sequence,
      offset,
      :binary.first(sequence),
      sequence
    )

    for split <- 0..byte_size(input) do
      error =
        assert_raise Error, fn ->
          stream_join(input, split, encoding, [])
        end

      assert error.encoding == encoding
      assert error.kind == :incomplete_sequence
      assert error.offset == offset
      assert error.sequence == sequence

      {callback_output, [event]} =
        capture_callback(fn callback ->
          stream_join(input, split, encoding, on_invalid_byte: callback)
        end)

      assert callback_output == expected_prefix <> "?"

      assert_invalid_event(
        event,
        encoding,
        :incomplete_sequence,
        offset,
        :binary.first(sequence),
        sequence
      )
    end
  end

  defp assert_earlier_target_error_suppresses_callback(
         valid_prefix,
         terminal_sequence,
         encoding,
         first_codepoint
       ) do
    owner = self()
    ref = make_ref()
    input = valid_prefix <> terminal_sequence

    callback = fn event ->
      send(owner, {ref, event})
      :discard
    end

    assert {:error, %Error{} = one_shot_error} =
             Iconvex.convert(input, encoding, "ASCII", on_invalid_byte: callback)

    assert_target_error(one_shot_error, first_codepoint)
    refute_received {^ref, _event}

    for split <- 0..byte_size(input) do
      error =
        assert_raise Error, fn ->
          stream_join_to(input, split, encoding, "ASCII", on_invalid_byte: callback)
        end

      assert_target_error(error, first_codepoint)
      refute_received {^ref, _event}
    end
  end

  defp capture_callback(fun) do
    owner = self()
    ref = make_ref()

    callback = fn event ->
      send(owner, {ref, event})
      {:replace, "?"}
    end

    result = fun.(callback)
    {result, collect_events(ref, [])}
  end

  defp incomplete_table_prefixes(entry) do
    entry
    |> Tables.fetch!()
    |> Map.fetch!(:prefixes)
    |> Enum.filter(fn sequence ->
      match?(
        {:error, :incomplete_sequence, 0, ^sequence},
        TableCodec.decode(entry, sequence)
      )
    end)
    |> Enum.sort()
  end

  defp collect_events(ref, acc) do
    receive do
      {^ref, event} -> collect_events(ref, [event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp stateful_target_prefix(encoding)
       when encoding in ["ISO-2022-JP", "ISO-2022-JP-1", "ISO-2022-JP-2", "ISO-2022-JP-MS"] do
    {<<0x1B, "$BF|", 0x1B, "(B">>, 0x65E5}
  end

  defp stateful_target_prefix("ISO-2022-KR"),
    do: {<<0x1B, "$)C", 0x0E, "GQ", 0x0F>>, 0xD55C}

  defp stateful_target_prefix(encoding)
       when encoding in ["ISO-2022-CN", "ISO-2022-CN-EXT"] do
    {<<0x1B, "$)A", 0x0E, "VP", 0x0F>>, 0x4E2D}
  end

  defp assert_target_error(error, codepoint) do
    assert error.kind == :unrepresentable_character
    assert error.encoding == "US-ASCII"
    assert error.codepoint == codepoint
  end

  defp assert_invalid_event(event, encoding, kind, offset, byte, sequence) do
    assert %InvalidByte{
             encoding: ^encoding,
             kind: ^kind,
             offset: ^offset,
             byte: ^byte,
             sequence: ^sequence
           } = event
  end

  defp substitute_bytes(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.map_join(fn byte -> "<#{hex2(byte)}>" end)
  end

  defp hex2(byte),
    do: byte |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")
end
