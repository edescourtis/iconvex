defmodule Iconvex.GNUEscapeRecurrenceTest.CollidingExternalCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-COLLIDING-UCS2-ID"

  @impl true
  def codec_id, do: :ucs2

  @impl true
  def decode(input), do: {:ok, :binary.bin_to_list(input)}

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode(codepoints), do: encode(codepoints, [])

  @impl true
  def encode_discard(codepoints) do
    output = for codepoint <- codepoints, codepoint < 0x80, into: <<>>, do: <<codepoint>>
    {:ok, output}
  end

  @impl true
  def encode_substitute(codepoints, replacer), do: encode_substitute(codepoints, replacer, [])

  @impl true
  def encode_chunk(codepoints, _final?, :error) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  defp encode([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
  defp encode([codepoint | rest], acc) when codepoint < 0x80, do: encode(rest, [codepoint | acc])
  defp encode([0xFFFD | rest], acc), do: encode(rest, ["R" | acc])

  defp encode([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute([codepoint | rest], replacer, acc)
       when codepoint < 0x80 or codepoint == 0xFFFD do
    {:ok, encoded} = encode([codepoint])
    encode_substitute(rest, replacer, [encoded | acc])
  end

  defp encode_substitute([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> encode_substitute(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.GNUEscapeRecurrenceTest do
  use ExUnit.Case, async: false

  alias Iconvex.{Error, EscapeCodec, InvalidByte}
  alias __MODULE__.CollidingExternalCodec

  setup do
    Iconvex.unregister_codec(CollidingExternalCodec)
    assert :ok = Iconvex.register_codec(CollidingExternalCodec)
    on_exit(fn -> Iconvex.unregister_codec(CollidingExternalCodec) end)
    :ok
  end

  @java_valid_cases [
    {~S(ok\ud83dX), ~S(ok\ud83dX)},
    {~S(ok\ud83d\x), ~S(ok\ud83d\x)},
    {~S(ok\ud83d\U), ~S(ok\ud83d\U)},
    {~S(ok\ud83d!), ~S(ok\ud83d!)},
    {~S(ok\ud83d\uDC/G), ~S(ok\ud83d\uDC/G)},
    {~S(ok\ud83d\u/), ~S(ok\ud83d\u/)},
    {~S(ok\ud83d\u0/), ~S(ok\ud83d\u0/)},
    {~S(ok\u00/X), ~S(ok\u00/X)},
    {~S(ok\u/), ~S(ok\u/)},
    {~S(ok\u0/), ~S(ok\u0/)},
    {~S(ok\q), ~S(ok\q)},
    {"ok\\\\q", "ok\\\\q"},
    {~S(ok\u000X), "ok!"},
    {~S(ok\u000G), "ok" <> <<0x10>>},
    {~S(ok\uZZZZ), "ok" <> <<0x23333::utf8>>},
    {~S(ok\ud83d\uDC0G), "ok🐐"},
    {~S(ok\ud83d\u0041), ~S(ok\ud83d) <> "A"}
  ]

  @java_incomplete_sequences [
    "\\",
    "\\u",
    "\\u0",
    "\\u00",
    "\\u000",
    "\\ud83d",
    "\\ud83d\\",
    "\\ud83d\\u",
    "\\ud83d\\u0",
    "\\ud83d\\uD",
    "\\ud83d\\uDB",
    "\\ud83d\\uDC",
    "\\ud83d\\uDC0",
    "\\ud83d\\uDg",
    "\\ud83d\\uDCG",
    "\\uD80G"
  ]

  @c99_invalid_sequences [
    ~S(\u0041),
    ~S(\u000X),
    ~S(\uD800),
    ~S(\U00000041),
    ~S(\U0000000X),
    ~S(\UG0000000)
  ]

  @c99_valid_cases [
    {~S(ok\u/), ~S(ok\u/)},
    {~S(ok\u00/), ~S(ok\u00/)},
    {~S(ok\u123!), ~S(ok\u123!)},
    {~S(ok\U0/), ~S(ok\U0/)},
    {~S(ok\u00AG), "ok°"}
  ]

  test "GNU JAVA literals, extended letter digits, and surrogate continuations stay exact" do
    for {input, expected} <- @java_valid_cases do
      assert Iconvex.convert(input, "JAVA", "UTF-8") == {:ok, expected}
      assert Iconvex.convert(input, "JAVA", "UTF-8", invalid: :discard) == {:ok, expected}

      assert Iconvex.convert(input, "JAVA", "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected}

      assert {Iconvex.convert(input, "JAVA", "UTF-8", on_invalid_byte: callback(self())),
              receive_events()} == {{:ok, expected}, []}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "JAVA", []) == {:ok, expected}
        assert stream_result(input, split, "JAVA", invalid: :discard) == {:ok, expected}

        assert stream_result(input, split, "JAVA", byte_substitute: "<%02x>") ==
                 {:ok, expected}

        assert {stream_result(input, split, "JAVA", on_invalid_byte: callback(self())),
                receive_events()} == {{:ok, expected}, []}
      end
    end
  end

  test "GNU JAVA reports only syntactic escape prefixes as incomplete at every split" do
    for sequence <- @java_incomplete_sequences do
      input = "ok" <> sequence
      expected_substitution = "ok" <> substitute_bytes(sequence)

      assert_error(Iconvex.convert(input, "JAVA", "UTF-8"), :incomplete_sequence, 2, sequence)
      assert Iconvex.convert(input, "JAVA", "UTF-8", invalid: :discard) == {:ok, "ok"}

      assert Iconvex.convert(input, "JAVA", "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, expected_substitution}

      assert_callback(
        Iconvex.convert(input, "JAVA", "UTF-8", on_invalid_byte: callback(self())),
        {:ok, "ok?"},
        "JAVA",
        :incomplete_sequence,
        2,
        sequence
      )

      for split <- 0..byte_size(input) do
        assert_error(
          stream_result(input, split, "JAVA", []),
          :incomplete_sequence,
          2,
          sequence
        )

        assert stream_result(input, split, "JAVA", invalid: :discard) == {:ok, "ok"}

        assert stream_result(input, split, "JAVA", byte_substitute: "<%02x>") ==
                 {:ok, expected_substitution}

        assert_callback(
          stream_result(input, split, "JAVA", on_invalid_byte: callback(self())),
          {:ok, "ok?"},
          "JAVA",
          :incomplete_sequence,
          2,
          sequence
        )
      end
    end
  end

  test "GNU JAVA preserves the first of two slashes before the incomplete second slash" do
    input = "ok\\\\"
    expected_prefix = "ok\\"

    assert_error(Iconvex.convert(input, "JAVA", "UTF-8"), :incomplete_sequence, 3, "\\")
    assert Iconvex.convert(input, "JAVA", "UTF-8", invalid: :discard) == {:ok, expected_prefix}

    assert Iconvex.convert(input, "JAVA", "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, expected_prefix <> "<5c>"}

    assert_callback(
      Iconvex.convert(input, "JAVA", "UTF-8", on_invalid_byte: callback(self())),
      {:ok, expected_prefix <> "?"},
      "JAVA",
      :incomplete_sequence,
      3,
      "\\"
    )

    for split <- 0..byte_size(input) do
      assert_error(
        stream_result(input, split, "JAVA", []),
        :incomplete_sequence,
        3,
        "\\"
      )

      assert stream_result(input, split, "JAVA", invalid: :discard) ==
               {:ok, expected_prefix}

      assert stream_result(input, split, "JAVA", byte_substitute: "<%02x>") ==
               {:ok, expected_prefix <> "<5c>"}

      assert_callback(
        stream_result(input, split, "JAVA", on_invalid_byte: callback(self())),
        {:ok, expected_prefix <> "?"},
        "JAVA",
        :incomplete_sequence,
        3,
        "\\"
      )
    end
  end

  test "GNU C99 rejects completed restricted universal names as one backslash" do
    for sequence <- @c99_invalid_sequences do
      input = "ok" <> sequence
      tail = binary_part(sequence, 1, byte_size(sequence) - 1)

      assert_error(Iconvex.convert(input, "C99", "UTF-8"), :invalid_sequence, 2, "\\")
      assert Iconvex.convert(input, "C99", "UTF-8", invalid: :discard) == {:ok, "ok" <> tail}

      assert Iconvex.convert(input, "C99", "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, "ok<5c>" <> tail}

      assert_callback(
        Iconvex.convert(input, "C99", "UTF-8", on_invalid_byte: callback(self())),
        {:ok, "ok?" <> tail},
        "C99",
        :invalid_sequence,
        2,
        "\\"
      )

      for split <- 0..byte_size(input) do
        assert_error(stream_result(input, split, "C99", []), :invalid_sequence, 2, "\\")

        assert stream_result(input, split, "C99", invalid: :discard) ==
                 {:ok, "ok" <> tail}

        assert stream_result(input, split, "C99", byte_substitute: "<%02x>") ==
                 {:ok, "ok<5c>" <> tail}

        assert_callback(
          stream_result(input, split, "C99", on_invalid_byte: callback(self())),
          {:ok, "ok?" <> tail},
          "C99",
          :invalid_sequence,
          2,
          "\\"
        )
      end
    end
  end

  test "GNU C99 keeps punctuation literal and accepts GNU extended letter digits" do
    for {input, expected} <- @c99_valid_cases do
      for options <- [[], [invalid: :discard], [byte_substitute: "<%02x>"]] do
        assert Iconvex.convert(input, "C99", "UTF-8", options) == {:ok, expected}

        for split <- 0..byte_size(input) do
          assert stream_result(input, split, "C99", options) == {:ok, expected}
        end
      end

      assert {Iconvex.convert(input, "C99", "UTF-8", on_invalid_byte: callback(self())),
              receive_events()} == {{:ok, expected}, []}

      for split <- 0..byte_size(input) do
        assert {stream_result(
                  input,
                  split,
                  "C99",
                  on_invalid_byte: callback(self())
                ), receive_events()} == {{:ok, expected}, []}
      end
    end
  end

  test "GNU C99 preserves UCS-4 while scalar target policy handles values above Unicode" do
    input = ~S(ok\U00110000Z)
    default_expected = "ok�Z"
    substituted_expected = "ok<U+110000>Z"

    ucs4_expected =
      for codepoint <- [?o, ?k, 0x110000, ?Z], into: <<>>, do: <<codepoint::32-big>>

    for options <- [[], [invalid: :discard], [byte_substitute: "<%02x>"]] do
      assert Iconvex.convert(input, "C99", "UTF-8", options) == {:ok, default_expected}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "C99", options) == {:ok, default_expected}
      end
    end

    assert {Iconvex.convert(input, "C99", "UTF-8", on_invalid_byte: callback(self())),
            receive_events()} == {{:ok, default_expected}, []}

    assert Iconvex.convert(input, "C99", "UTF-8", transliterate: true) ==
             {:ok, default_expected}

    for split <- 0..byte_size(input) do
      assert {stream_result(
                input,
                split,
                "C99",
                on_invalid_byte: callback(self())
              ), receive_events()} == {{:ok, default_expected}, []}
    end

    assert Iconvex.convert(input, "C99", "UTF-8", unrepresentable: :discard) ==
             {:ok, "okZ"}

    assert Iconvex.convert(input, "C99", "UTF-8", unicode_substitute: "<U+%04X>") ==
             {:ok, substituted_expected}

    assert Iconvex.convert(input, "C99", "UTF-8",
             unrepresentable: :discard,
             unicode_substitute: "<U+%04X>"
           ) == {:ok, "okZ"}

    assert Iconvex.convert(input, "C99", "UTF-8",
             transliterate: true,
             unrepresentable: :discard,
             unicode_substitute: "<U+%04X>"
           ) == {:ok, "okZ"}

    assert Iconvex.convert(input, "C99", "UCS-4BE") == {:ok, ucs4_expected}

    for {target, target_expected} <- [
          {"UTF-7", "+//0-"},
          {"JAVA", ~S(\ufffd)},
          {"GB18030", <<0x84, 0x31, 0xA4, 0x37>>}
        ] do
      assert Iconvex.convert(input, "C99", target) == {:ok, "ok" <> target_expected <> "Z"}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "C99", [], target) ==
                 {:ok, "ok" <> target_expected <> "Z"}
      end
    end

    for split <- 0..byte_size(input) do
      assert stream_result(input, split, "C99", unrepresentable: :discard) == {:ok, "okZ"}

      assert stream_result(input, split, "C99", transliterate: true) ==
               {:ok, default_expected}

      assert stream_result(input, split, "C99", unicode_substitute: "<U+%04X>") ==
               {:ok, substituted_expected}

      assert stream_result(input, split, "C99",
               unrepresentable: :discard,
               unicode_substitute: "<U+%04X>"
             ) == {:ok, "okZ"}

      assert stream_result(input, split, "C99",
               transliterate: true,
               unrepresentable: :discard,
               unicode_substitute: "<U+%04X>"
             ) == {:ok, "okZ"}

      assert stream_result(input, split, "C99", []) == {:ok, default_expected}

      assert stream_result(input, split, "C99", [], "UCS-4BE") == {:ok, ucs4_expected}
    end
  end

  test "GNU C99 uses uint32 escape arithmetic and explicit UCS-4 transports all 32 bits" do
    entry = %{id: :c99}

    for {input, codepoint, canonical} <- [
          {~S(\UGGGGGGGG), 0x11111110, ~S(\U11111110)},
          {~S(\UZZZZZZZZ), 0x33333333, ~S(\U33333333)},
          {~S(\Uffffffff), 0xFFFFFFFF, ~S(\Uffffffff)}
        ] do
      assert EscapeCodec.decode(entry, input) == {:ok, [codepoint]}
      assert Iconvex.convert(input, "C99", "C99") == {:ok, canonical}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "C99", [], "C99") == {:ok, canonical}
      end
    end

    assert EscapeCodec.encode(entry, [0xFFFFFFFF]) == {:ok, ~S(\Uffffffff)}

    assert EscapeCodec.encode(entry, [0x100000000]) ==
             {:error, :unrepresentable_character, 0x100000000}

    native = :erlang.system_info(:endian)
    swapped = if native == :big, do: :little, else: :big

    for {target, endian} <- [
          {"UCS-4BE", :big},
          {"UCS-4LE", :little},
          {"UCS-4-INTERNAL", native},
          {"UCS-4-SWAPPED", swapped}
        ],
        {input, codepoint} <- [
          {~S(\Uffffffff), 0xFFFFFFFF},
          {~S(\U81234567), 0x81234567}
        ] do
      expected = word32(codepoint, endian)

      assert Iconvex.convert(input, "C99", target) == {:ok, expected}
      assert Iconvex.convert(expected, target, "C99") == {:ok, canonical_c99(codepoint)}
      assert Iconvex.convert(expected, target, "UTF-8") == {:ok, "�"}

      assert Iconvex.convert(expected, target, "UTF-8", transliterate: true) == {:ok, "�"}

      assert Iconvex.convert(expected, target, "UTF-8", unrepresentable: :discard) ==
               {:ok, <<>>}

      assert Iconvex.convert(expected, target, "UTF-8", unicode_substitute: "<U+%04X>") ==
               {:ok, "<U+" <> String.upcase(Integer.to_string(codepoint, 16), :ascii) <> ">"}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "C99", [], target) == {:ok, expected}
      end

      for split <- 0..byte_size(expected) do
        assert stream_result(expected, split, target, [], "C99") ==
                 {:ok, canonical_c99(codepoint)}

        assert stream_result(expected, split, target, [], "UTF-8") == {:ok, "�"}

        assert stream_result(expected, split, target, [transliterate: true], "UTF-8") ==
                 {:ok, "�"}

        assert stream_result(
                 expected,
                 split,
                 target,
                 [unrepresentable: :discard],
                 "UTF-8"
               ) == {:ok, <<>>}

        assert stream_result(
                 expected,
                 split,
                 target,
                 [unicode_substitute: "<U+%04X>"],
                 "UTF-8"
               ) ==
                 {:ok, "<U+" <> String.upcase(Integer.to_string(codepoint, 16), :ascii) <> ">"}
      end
    end

    generic_expected = word32(0xFFFD, :big)
    assert Iconvex.convert(~S(\Uffffffff), "C99", "UCS-4") == {:ok, generic_expected}

    for split <- 0..10 do
      assert stream_result(~S(\Uffffffff), split, "C99", [], "UCS-4") ==
               {:ok, generic_expected}
    end

    generic_source = word32(0x110000, :big)
    assert Iconvex.convert(generic_source, "UCS-4", "UTF-8") == {:ok, "�"}

    for split <- 0..byte_size(generic_source) do
      assert stream_result(generic_source, split, "UCS-4", [], "UTF-8") == {:ok, "�"}
    end

    surrogate_source = word32(0xD800, :big)
    assert Iconvex.convert(surrogate_source, "UCS-4BE", "UTF-8") == {:ok, "�"}

    assert Iconvex.convert(surrogate_source, "UCS-4BE", "UTF-8", transliterate: true) ==
             {:ok, "�"}

    assert Iconvex.convert(surrogate_source, "UCS-4BE", "UTF-8", unrepresentable: :discard) ==
             {:ok, <<>>}

    assert Iconvex.convert(surrogate_source, "UCS-4BE", "UTF-8", unicode_substitute: "<U+%04X>") ==
             {:ok, "<U+D800>"}

    for split <- 0..byte_size(surrogate_source) do
      assert stream_result(surrogate_source, split, "UCS-4BE", [], "UTF-8") == {:ok, "�"}

      assert stream_result(
               surrogate_source,
               split,
               "UCS-4BE",
               [transliterate: true],
               "UTF-8"
             ) == {:ok, "�"}

      assert stream_result(
               surrogate_source,
               split,
               "UCS-4BE",
               [unrepresentable: :discard],
               "UTF-8"
             ) == {:ok, <<>>}

      assert stream_result(
               surrogate_source,
               split,
               "UCS-4BE",
               [unicode_substitute: "<U+%04X>"],
               "UTF-8"
             ) == {:ok, "<U+D800>"}
    end
  end

  test "GNU generic UCS-2 and UTF-16 replace their byte-order sentinel only by default" do
    input = ~S(\ufffe)

    for {target, expected} <- [
          {"UCS-2", <<0xFF, 0xFD>>},
          {"UTF-16", <<0xFE, 0xFF, 0xFF, 0xFD>>}
        ] do
      assert Iconvex.convert(input, "C99", target) == {:ok, expected}
      assert Iconvex.convert(input, "C99", target, transliterate: true) == {:ok, expected}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "C99", [], target) == {:ok, expected}

        assert stream_result(input, split, "C99", [transliterate: true], target) ==
                 {:ok, expected}
      end
    end

    assert Iconvex.convert(input, "C99", "UCS-2BE") == {:ok, <<0xFF, 0xFE>>}
    assert Iconvex.convert(input, "C99", "UTF-16BE") == {:ok, <<0xFF, 0xFE>>}
    assert Iconvex.convert(input, "C99", "UCS-2", unrepresentable: :discard) == {:ok, <<>>}

    substitute = "<U+FFFE>"
    substitute_ucs2 = for <<byte <- substitute>>, into: <<>>, do: <<0, byte>>

    assert Iconvex.convert(input, "C99", "UCS-2", unicode_substitute: "<U+%04X>") ==
             {:ok, substitute_ucs2}

    for split <- 0..byte_size(input) do
      assert stream_result(input, split, "C99", [], "UCS-2BE") == {:ok, <<0xFF, 0xFE>>}
      assert stream_result(input, split, "C99", [], "UTF-16BE") == {:ok, <<0xFF, 0xFE>>}

      assert stream_result(input, split, "C99", [unrepresentable: :discard], "UCS-2") ==
               {:ok, <<>>}

      assert stream_result(
               input,
               split,
               "C99",
               [unicode_substitute: "<U+%04X>"],
               "UCS-2"
             ) == {:ok, substitute_ucs2}
    end
  end

  test "GNU target fallback is source-independent and follows transliteration" do
    native = :erlang.system_info(:endian)
    swapped = if native == :big, do: :little, else: :big

    for {source, input} <- [
          {"UTF-8", "😀"},
          {"JAVA", ~S(\ud83d\ude00)},
          {"C99", ~S(\U0001f600)}
        ],
        {target, endian} <- [
          {"UCS-2", :big},
          {"UCS-2BE", :big},
          {"UCS-2LE", :little},
          {"UCS-2-INTERNAL", native},
          {"UCS-2-SWAPPED", swapped}
        ] do
      fallback = word16(0xFFFD, endian)
      transliterated = words16(":-D", endian)
      substituted = words16("<U+1F600>", endian)

      assert Iconvex.convert(input, source, target) == {:ok, fallback}

      assert Iconvex.convert(input, source, target, transliterate: true) ==
               {:ok, transliterated}

      assert Iconvex.convert(input, source, target, unrepresentable: :discard) == {:ok, <<>>}

      assert Iconvex.convert(input, source, target, unicode_substitute: "<U+%04X>") ==
               {:ok, substituted}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, source, [], target) == {:ok, fallback}

        assert stream_result(input, split, source, [transliterate: true], target) ==
                 {:ok, transliterated}

        assert stream_result(input, split, source, [unrepresentable: :discard], target) ==
                 {:ok, <<>>}

        assert stream_result(
                 input,
                 split,
                 source,
                 [unicode_substitute: "<U+%04X>"],
                 target
               ) == {:ok, substituted}
      end
    end

    untranslatable = ~S(\U00010000)
    fallback = word16(0xFFFD, :big)

    assert Iconvex.convert(untranslatable, "C99", "UCS-2BE", transliterate: true) ==
             {:ok, fallback}

    for split <- 0..byte_size(untranslatable) do
      assert stream_result(
               untranslatable,
               split,
               "C99",
               [transliterate: true],
               "UCS-2BE"
             ) == {:ok, fallback}
    end
  end

  test "GNU discard options precede byte fallback while callback decisions stay explicit" do
    for {input, source, invalid_byte, substituted} <- [
          {<<?A, 0xA0, ?B>>, "C99", 0xA0, "A<a0>B"},
          {<<?A, 0xFF, ?B>>, "UTF-8", 0xFF, "A<ff>B"}
        ] do
      assert Iconvex.convert(input, source, "UTF-8", byte_substitute: "<%02x>") ==
               {:ok, substituted}

      discard_options = [invalid: :discard, byte_substitute: "<%02x>"]
      assert Iconvex.convert(input, source, "UTF-8", discard_options) == {:ok, "AB"}

      assert_callback_frame(
        Iconvex.convert(
          input,
          source,
          "UTF-8",
          Keyword.put(discard_options, :on_invalid_byte, callback_default(self()))
        ),
        {:ok, "AB"},
        source,
        1,
        invalid_byte
      )

      assert_callback_frame(
        Iconvex.convert(
          input,
          source,
          "UTF-8",
          Keyword.put(discard_options, :on_invalid_byte, callback(self()))
        ),
        {:ok, "A?B"},
        source,
        1,
        invalid_byte
      )

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, source, discard_options) == {:ok, "AB"}

        assert_callback_frame(
          stream_result(
            input,
            split,
            source,
            Keyword.put(discard_options, :on_invalid_byte, callback_default(self()))
          ),
          {:ok, "AB"},
          source,
          1,
          invalid_byte
        )

        assert_callback_frame(
          stream_result(
            input,
            split,
            source,
            Keyword.put(discard_options, :on_invalid_byte, callback(self()))
          ),
          {:ok, "A?B"},
          source,
          1,
          invalid_byte
        )
      end
    end
  end

  test "GNU drops unencodable tag characters before fallback but preserves capable targets" do
    tag = 0xE0001
    cancel = 0xE007F
    input = "A" <> <<tag::utf8>> <> "B" <> <<cancel::utf8>> <> "C"

    options_matrix = [
      [],
      [transliterate: true],
      [unrepresentable: :discard],
      [unicode_substitute: "<U+%04X>"]
    ]

    ucs2_expected = words16("ABC", :big)

    for {target, expected} <- [
          {"ASCII", "ABC"},
          {"UCS-2BE", ucs2_expected},
          {"ISO-2022-JP-2", "ABC"}
        ],
        options <- options_matrix do
      assert Iconvex.convert(input, "UTF-8", target, options) == {:ok, expected}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "UTF-8", options, target) == {:ok, expected}
      end
    end

    ucs4_expected =
      for codepoint <- [?A, tag, ?B, cancel, ?C], into: <<>>, do: word32(codepoint, :big)

    for {target, expected} <- [
          {"UTF-8", input},
          {"C99", ~S(A\U000e0001B\U000e007fC)},
          {"JAVA", ~S(A\udb40\udc01B\udb40\udc7fC)},
          {"UCS-4BE", ucs4_expected}
        ],
        options <- options_matrix do
      assert Iconvex.convert(input, "UTF-8", target, options) == {:ok, expected}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "UTF-8", options, target) == {:ok, expected}
      end
    end
  end

  test "GNU JAVA and UTF-7 targets preserve isolated UCS-4 surrogate units" do
    policies = [
      [],
      [transliterate: true],
      [unrepresentable: :discard],
      [unicode_substitute: "<U+%04X>"]
    ]

    for codepoint <- 0xD800..0xDFFF,
        {target, expected} <- [
          {"JAVA", java_unit(codepoint)},
          {"UTF-7", utf7_unit(codepoint)}
        ],
        options <- policies do
      input = word32(codepoint, :big)
      assert Iconvex.convert(input, "UCS-4BE", target, options) == {:ok, expected}
    end

    for codepoint <- [0xD800, 0xDBFF, 0xDC00, 0xDFFF],
        {target, expected} <- [
          {"JAVA", java_unit(codepoint)},
          {"UTF-7", utf7_unit(codepoint)}
        ],
        options <- policies do
      input = word32(codepoint, :big)

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "UCS-4BE", options, target) == {:ok, expected}
      end
    end
  end

  test "GNU generic UTF-16 and UTF-32 emit BOM only for an emitted character" do
    discard = [unrepresentable: :discard]

    for {target, rejected} <- [
          {"UTF-16", [0xD800, 0xFFFE, 0x110000]},
          {"UTF-32", [0xD800, 0x110000]}
        ],
        codepoint <- rejected do
      input = word32(codepoint, :big)
      assert Iconvex.convert(input, "UCS-4BE", target, discard) == {:ok, <<>>}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "UCS-4BE", discard, target) == {:ok, <<>>}
      end
    end

    for {target, expected} <- [
          {"UTF-16", <<0xFE, 0xFF, 0, ?A>>},
          {"UTF-32", <<0, 0, 0xFE, 0xFF, 0, 0, 0, ?A>>}
        ] do
      input = word32(0xD800, :big) <> word32(?A, :big)
      assert Iconvex.convert(input, "UCS-4BE", target, discard) == {:ok, expected}

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, "UCS-4BE", discard, target) == {:ok, expected}
      end
    end

    fffe = word32(0xFFFE, :big)
    utf32_fffe = <<0, 0, 0xFE, 0xFF, 0, 0, 0xFF, 0xFE>>
    assert Iconvex.convert(fffe, "UCS-4BE", "UTF-32", discard) == {:ok, utf32_fffe}

    for split <- 0..byte_size(fffe) do
      assert stream_result(fffe, split, "UCS-4BE", discard, "UTF-32") ==
               {:ok, utf32_fffe}
    end

    assert Iconvex.convert(fffe, "UTF-32BE", "UTF-16", discard) == {:ok, <<>>}

    for split <- 0..byte_size(fffe) do
      assert stream_result(fffe, split, "UTF-32BE", discard, "UTF-16") == {:ok, <<>>}
    end
  end

  test "external codec ids cannot opt into GNU Core fallback by collision" do
    assert {:ok, %{kind: :external, id: :ucs2}} =
             Iconvex.ExternalRegistry.resolve(CollidingExternalCodec)

    assert_error(
      Iconvex.convert("😀", "UTF-8", CollidingExternalCodec),
      :unrepresentable_character,
      nil,
      nil
    )

    for split <- 0..byte_size("😀") do
      assert_error(
        stream_result("😀", split, "UTF-8", [], CollidingExternalCodec),
        :unrepresentable_character,
        nil,
        nil
      )
    end
  end

  defp callback(owner) do
    fn event ->
      send(owner, {:gnu_escape_event, event})
      {:replace, "?"}
    end
  end

  defp callback_default(owner) do
    fn event ->
      send(owner, {:gnu_escape_event, event})
      :default
    end
  end

  defp assert_callback_frame(result, expected, encoding, offset, byte) do
    assert result == expected
    assert [%InvalidByte{} = event] = receive_events()

    assert {event.encoding, event.kind, event.offset, event.byte} ==
             {encoding, :invalid_sequence, offset, byte}
  end

  defp assert_callback(result, expected, encoding, kind, offset, sequence) do
    assert result == expected
    assert [%InvalidByte{} = event] = receive_events()

    assert {event.encoding, event.kind, event.offset, event.byte, event.sequence} ==
             {encoding, kind, offset, ?\\, sequence}
  end

  defp receive_events(acc \\ []) do
    receive do
      {:gnu_escape_event, %InvalidByte{} = event} -> receive_events([event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp stream_result(input, split, encoding, options, target \\ "UTF-8") do
    <<left::binary-size(split), right::binary>> = input

    try do
      {:ok,
       [left, right]
       |> Iconvex.stream!(encoding, target, options)
       |> Enum.join()}
    rescue
      error in Error -> {:error, error}
    end
  end

  defp assert_error({:error, %Error{} = error}, kind, offset, sequence) do
    assert {error.kind, error.offset, error.sequence} == {kind, offset, sequence}
  end

  defp substitute_bytes(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.map_join(fn byte ->
      "<" <>
        (byte |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")) <>
        ">"
    end)
  end

  defp word32(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp word32(codepoint, :little), do: <<codepoint::unsigned-little-32>>
  defp word16(codepoint, :big), do: <<codepoint::unsigned-big-16>>
  defp word16(codepoint, :little), do: <<codepoint::unsigned-little-16>>

  defp words16(text, endian) do
    for codepoint <- String.to_charlist(text), into: <<>>, do: word16(codepoint, endian)
  end

  defp java_unit(codepoint) do
    "\\u" <>
      (codepoint
       |> Integer.to_string(16)
       |> String.downcase()
       |> String.pad_leading(4, "0"))
  end

  defp utf7_unit(codepoint),
    do: "+" <> Base.encode64(word16(codepoint, :big), padding: false) <> "-"

  defp canonical_c99(codepoint) do
    "\\U" <>
      (codepoint
       |> Integer.to_string(16)
       |> String.downcase()
       |> String.pad_leading(8, "0"))
  end
end
