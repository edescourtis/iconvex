defmodule Iconvex.Telecom.MorseTest do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.Morse

  @source_sha256 "a3eab8884c24200f229ef20615ee3ae14329ba0f0a29c7a85a1eaa3cac442b97"

  @letters %{
    ?A => ".-",
    ?B => "-...",
    ?C => "-.-.",
    ?D => "-..",
    ?E => ".",
    0x00E9 => "..-..",
    ?F => "..-.",
    ?G => "--.",
    ?H => "....",
    ?I => "..",
    ?J => ".---",
    ?K => "-.-",
    ?L => ".-..",
    ?M => "--",
    ?N => "-.",
    ?O => "---",
    ?P => ".--.",
    ?Q => "--.-",
    ?R => ".-.",
    ?S => "...",
    ?T => "-",
    ?U => "..-",
    ?V => "...-",
    ?W => ".--",
    ?X => "-..-",
    ?Y => "-.--",
    ?Z => "--.."
  }

  @figures %{
    ?1 => ".----",
    ?2 => "..---",
    ?3 => "...--",
    ?4 => "....-",
    ?5 => ".....",
    ?6 => "-....",
    ?7 => "--...",
    ?8 => "---..",
    ?9 => "----.",
    ?0 => "-----"
  }

  @punctuation %{
    ?. => ".-.-.-",
    ?, => "--..--",
    ?: => "---...",
    ?? => "..--..",
    ?' => ".----.",
    ?- => "-....-",
    ?/ => "-..-.",
    ?( => "-.--.",
    ?) => "-.--.-",
    ?\" => ".-..-.",
    ?= => "-...-",
    ?+ => ".-.-.",
    0x00D7 => "-..-",
    ?@ => ".--.-."
  }

  @graphics Map.merge(@letters, Map.merge(@figures, @punctuation))

  test "registers the exact ITU-R recommendation and common names" do
    for name <- [
          "MORSE-ITU-M1677",
          "INTERNATIONAL-MORSE",
          "ITU-R-M.1677-1",
          "ITU-R-M.1677",
          "MORSE-CODE"
        ] do
      assert Iconvex.canonical_name(name) == {:ok, "MORSE-ITU-M1677"}
    end
  end

  test "pins the in-force official source and exposes the serialization contract" do
    assert Morse.source_manifest() == %{
             recommendation: "ITU-R M.1677-1 (10/2009)",
             source_sha256: @source_sha256,
             source_url:
               "https://www.itu.int/dms_pubrec/itu-r/rec/m/R-REC-M.1677-1-200910-I!!PDF-E.pdf"
           }

    assert Morse.serialization() == %{
             alphabet: :ascii_dot_hyphen,
             character_separator: " ",
             word_token: "/"
           }
  end

  test "ports every graphic signal from clauses 1.1.1 through 1.1.3" do
    assert Morse.table() == @graphics
    assert map_size(@graphics) == 51

    for {codepoint, signal} <- @graphics do
      assert Morse.encode([codepoint]) == {:ok, signal}

      expected = if codepoint == 0x00D7, do: [?X], else: [codepoint]
      assert Morse.decode(signal) == {:ok, expected}
    end

    for letter <- ?a..?z do
      assert Morse.encode([letter]) == Morse.encode([letter - 32])
    end
  end

  test "keeps all non-graphic procedural signals auditable and outside Unicode text" do
    assert Morse.procedural_signals() == %{
             understood: "...-.",
             error: "........",
             invitation_to_transmit: "-.-",
             wait: ".-...",
             end_of_work: "...-.-",
             starting_signal: "-.-.-"
           }

    for signal <- ["...-.", "........", ".-...", "...-.-", "-.-.-"] do
      assert Morse.decode(signal) == {:error, :invalid_sequence, 0, signal}
    end

    # Invitation to transmit is deliberately the same signal as graphic K.
    assert Morse.decode("-.-") == {:ok, [?K]}
  end

  test "round-trips words using the explicit octet serialization" do
    text = ~c"HELLO WORLD 123"

    encoded =
      ".... . .-.. .-.. --- / .-- --- .-. .-.. -.. / .---- ..--- ...--"

    assert Morse.encode(text) == {:ok, encoded}
    assert Morse.decode(encoded) == {:ok, text}
    assert Morse.decode_to_utf8(encoded) == {:ok, "HELLO WORLD 123"}
  end

  test "reports exact token offsets and has deterministic discard semantics" do
    assert Morse.decode(".- bogus -...") ==
             {:error, :invalid_sequence, 3, "bogus"}

    assert Morse.decode(" .-") == {:error, :invalid_sequence, 0, " "}
    assert Morse.decode(".-  -...") == {:error, :invalid_sequence, 3, " "}
    assert Morse.decode(".- ") == {:error, :invalid_sequence, 2, " "}

    assert Morse.decode_discard(".- bogus / -...") == {:ok, [?A, ?\s, ?B]}
    assert Morse.encode_discard([?A, 0x2603, ?\s, ?B]) == {:ok, ".- / -..."}
  end

  test "public recovery consumes one malformed Morse signal as one token" do
    input = "......"
    parent = self()

    assert Morse.decode(input) == {:error, :invalid_sequence, 0, input}
    assert Morse.decode_discard(input) == {:ok, []}

    assert Iconvex.convert(
             input,
             Morse,
             "UTF-8",
             on_invalid_byte: fn event ->
               send(parent, {:discard, event})
               :discard
             end
           ) == {:ok, ""}

    assert_receive {:discard,
                    %Iconvex.InvalidByte{
                      encoding: "MORSE-ITU-M1677",
                      kind: :invalid_sequence,
                      offset: 0,
                      byte: ?.,
                      sequence: ^input
                    }}

    refute_receive {:discard, %Iconvex.InvalidByte{}}

    assert Iconvex.convert(
             input,
             Morse,
             "UTF-8",
             on_invalid_byte: fn event ->
               send(parent, {:replace, event})
               {:replace, "?"}
             end
           ) == {:ok, "?"}

    assert_receive {:replace,
                    %Iconvex.InvalidByte{
                      encoding: "MORSE-ITU-M1677",
                      kind: :invalid_sequence,
                      offset: 0,
                      byte: ?.,
                      sequence: ^input
                    }}

    refute_receive {:replace, %Iconvex.InvalidByte{}}

    assert Iconvex.convert(input, Morse, "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, String.duplicate("<2e>", 6)}
  end

  test "preserves UTF-8 callback errors and noninjective multiplication semantics" do
    assert Morse.encode_from_utf8("sos") == {:ok, "... --- ..."}

    assert Morse.encode_from_utf8(<<"A", 0xC2>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xC2>>}

    assert Morse.encode_from_utf8("A☃") ==
             {:encode_error, :unrepresentable_character, 0x2603}

    assert Morse.encode([0x00D7]) == {:ok, "-..-"}
    assert Morse.decode("-..-") == {:ok, [?X]}
  end
end
