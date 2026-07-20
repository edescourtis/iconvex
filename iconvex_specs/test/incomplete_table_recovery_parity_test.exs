defmodule Iconvex.Specs.IncompleteTableRecoveryParityTest do
  use ExUnit.Case, async: false

  alias Iconvex.{TableCodec, Tables}
  alias Iconvex.Specs.LegacyComputingN5028.Codecs

  @generated_wrapper_incomplete_cases [
    {Iconvex.Specs.GlibcCharmaps.Codecs.C10, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C12, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C14, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C34, <<0x81, 0x21>>},
    {Iconvex.Specs.ICUArchive.Codecs.C35, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C36, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C37, <<0x81, 0x30>>},
    {Iconvex.Specs.ICUArchive.Codecs.C38, <<0x81, 0x30>>},
    {Iconvex.Specs.ICUArchive.Codecs.C90, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C91, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C92, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C277, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C278, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C279, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C281, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C420, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C503, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C504, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C505, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C506, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C551, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C552, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C577, <<0x81, 0x30>>},
    {Iconvex.Specs.ICUArchive.Codecs.C578, <<0x81, 0x30>>},
    {Iconvex.Specs.ICUArchive.Codecs.C725, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C731, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C732, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C784, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C827, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C830, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C832, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C923, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUArchive.Codecs.C931, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C1, <<0x81, 0x21>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C2, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C3, <<0x8E, 0xA2>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C11, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C12, <<0x8F, 0xB0>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C13, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C22, <<0x8F, 0xA2>>},
    {Iconvex.Specs.ICUMultibyte.Codecs.C23, <<0x8E, 0xA2>>}
  ]

  test "every MINITEL-G0 incomplete table prefix has one-shot and streaming recovery parity" do
    codec = Enum.find(Codecs.modules(), &(&1.canonical_name() == "MINITEL-G0"))
    assert codec

    entry = %{id: codec.codec_id(), table_app: :iconvex_specs}
    prefixes = incomplete_table_prefixes(entry)

    assert length(prefixes) == 6

    for sequence <- prefixes do
      expected_substitution = substitute_bytes(sequence)

      assert codec.decode(sequence) == {:error, :incomplete_sequence, 0, sequence}
      assert convert(sequence, invalid: :discard) == ""
      assert convert(sequence, byte_substitute: "<%02x>") == expected_substitution

      for split <- 0..byte_size(sequence) do
        chunks = split_at(sequence, split)

        assert stream(chunks, invalid: :discard) == "",
               "MINITEL-G0 discard split #{split} for #{Base.encode16(sequence)}"

        assert stream(chunks, byte_substitute: "<%02x>") == expected_substitution,
               "MINITEL-G0 substitution split #{split} for #{Base.encode16(sequence)}"
      end
    end
  end

  test "generated table wrappers recover each terminal incomplete unit atomically" do
    assert length(@generated_wrapper_incomplete_cases) == 41

    for {codec, sequence} <- @generated_wrapper_incomplete_cases do
      assert codec.decode(sequence) == {:error, :incomplete_sequence, 0, sequence}
      assert codec.decode_discard(sequence) == {:ok, []}

      replacement_ref = make_ref()

      assert Iconvex.convert(sequence, codec, "UTF-8",
               on_invalid_byte: fn event ->
                 send(self(), {replacement_ref, event})
                 {:replace, ??}
               end
             ) == {:ok, "?"}

      assert_receive {^replacement_ref,
                      %Iconvex.InvalidByte{
                        kind: :incomplete_sequence,
                        offset: 0,
                        sequence: ^sequence
                      }}

      refute_receive {^replacement_ref, _}

      discard_ref = make_ref()

      assert Iconvex.convert(sequence, codec, "UTF-8",
               on_invalid_byte: fn event ->
                 send(self(), {discard_ref, event})
                 :discard
               end
             ) == {:ok, ""}

      assert_receive {^discard_ref,
                      %Iconvex.InvalidByte{
                        kind: :incomplete_sequence,
                        offset: 0,
                        sequence: ^sequence
                      }}

      refute_receive {^discard_ref, _}

      assert Iconvex.convert(sequence, codec, "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, substitute_bytes(sequence)}
    end
  end

  defp convert(input, options) do
    assert {:ok, output} = Iconvex.convert(input, "MINITEL-G0", "UTF-8", options)
    output
  end

  defp stream(chunks, options) do
    assert {:ok, output} = Iconvex.stream(chunks, "MINITEL-G0", "UTF-8", options)
    output |> Enum.to_list() |> IO.iodata_to_binary()
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

  defp split_at(input, offset) do
    [
      binary_part(input, 0, offset),
      binary_part(input, offset, byte_size(input) - offset)
    ]
  end

  defp substitute_bytes(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.map_join(fn byte ->
      "<#{byte |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")}>"
    end)
  end
end
