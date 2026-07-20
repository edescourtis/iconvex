defmodule Iconvex.Specs.StanfordRFC698GraphicsTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.StanfordRFC698FormatEffector1975, as: FormatEffector
  alias Iconvex.Specs.StanfordRFC698HiddenGraphics1975, as: HiddenGraphics

  @root Path.expand("..", __DIR__)
  @mapping Path.join(@root, "priv/sources/rfc698-stanford/graphics.csv")
  @metadata Path.join(@root, "priv/sources/rfc698-stanford/SOURCE_METADATA.md")

  test "RED: RFC 698's two source-qualified graphic interpretations register without claiming the Telnet option" do
    assert FormatEffector in Iconvex.Specs.additional_codecs()
    assert HiddenGraphics in Iconvex.Specs.additional_codecs()

    assert FormatEffector.canonical_name() ==
             "RFC698-SU-AI-STANFORD-1975-FORMAT-EFFECTOR"

    assert HiddenGraphics.canonical_name() ==
             "RFC698-SU-AI-STANFORD-1975-HIDDEN-GRAPHICS"

    assert {:ok, %{codec: FormatEffector}} =
             Iconvex.ExternalRegistry.resolve("STANFORD-EXTENDED-ASCII-RFC698-FORMAT-EFFECTOR")

    assert {:ok, %{codec: HiddenGraphics}} =
             Iconvex.ExternalRegistry.resolve("STANFORD-EXTENDED-ASCII-RFC698-HIDDEN-GRAPHICS")

    for ambiguous <- ["STANFORD-EXTENDED-ASCII", "RFC698", "EXTEND-ASCII"] do
      assert :error = Iconvex.ExternalRegistry.resolve(ambiguous)
    end
  end

  test "RED: every normalized RFC table position is exact and invertible in both profiles" do
    rows = rows()
    assert length(rows) == 128
    assert Enum.map(rows, &elem(&1, 0)) == Enum.to_list(0..127)

    for {byte, format_effector, hidden_graphic} <- rows do
      assert FormatEffector.decode(<<byte>>) == {:ok, [format_effector]}
      assert FormatEffector.encode([format_effector]) == {:ok, <<byte>>}
      assert HiddenGraphics.decode(<<byte>>) == {:ok, [hidden_graphic]}
      assert HiddenGraphics.encode([hidden_graphic]) == {:ok, <<byte>>}
    end

    input = 0..127 |> Enum.to_list() |> :erlang.list_to_binary()
    format_codepoints = Enum.map(rows, &elem(&1, 1))
    hidden_codepoints = Enum.map(rows, &elem(&1, 2))

    assert FormatEffector.decode(input) == {:ok, format_codepoints}
    assert FormatEffector.encode(format_codepoints) == {:ok, input}
    assert HiddenGraphics.decode(input) == {:ok, hidden_codepoints}
    assert HiddenGraphics.encode(hidden_codepoints) == {:ok, input}

    format_utf8 = :unicode.characters_to_binary(format_codepoints)
    hidden_utf8 = :unicode.characters_to_binary(hidden_codepoints)

    assert FormatEffector.decode_to_utf8(input) == {:ok, format_utf8}
    assert FormatEffector.encode_from_utf8(format_utf8) == {:ok, input}
    assert HiddenGraphics.decode_to_utf8(input) == {:ok, hidden_utf8}
    assert HiddenGraphics.encode_from_utf8(hidden_utf8) == {:ok, input}

    assert Iconvex.convert(input, FormatEffector.canonical_name(), "UTF-8") ==
             {:ok, format_utf8}

    assert Iconvex.convert(format_utf8, "UTF-8", FormatEffector.canonical_name()) ==
             {:ok, input}

    assert Iconvex.convert(input, HiddenGraphics.canonical_name(), "UTF-8") ==
             {:ok, hidden_utf8}

    assert Iconvex.convert(hidden_utf8, "UTF-8", HiddenGraphics.canonical_name()) ==
             {:ok, input}
  end

  test "RED: hidden graphics differ only at the seven positions identified by RFC 698" do
    expected = %{
      0o000 => {0x0000, 0x00B7},
      0o011 => {0x0009, 0x03B3},
      0o012 => {0x000A, 0x03B4},
      0o013 => {0x000B, 0x222B},
      0o014 => {0x000C, 0x00B1},
      0o015 => {0x000D, 0x2295},
      0o177 => {0x007F, 0x005E}
    }

    actual =
      rows()
      |> Enum.filter(fn {_byte, main, hidden} -> main != hidden end)
      |> Map.new(fn {byte, main, hidden} -> {byte, {main, hidden}} end)

    assert actual == expected

    assert FormatEffector.decode(<<0o001, 0o017, 0o020, 0o027, 0o036, 0o175>>) ==
             {:ok, [0x2193, 0x2202, 0x2282, 0x2194, 0x2261, 0x25CA]}
  end

  test "RED: the seven-bit profiles reject high octets and recovery advances exactly one octet" do
    for codec <- [FormatEffector, HiddenGraphics], byte <- 128..255 do
      assert codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
    end

    assert FormatEffector.decode_discard(<<0x80, 0o001, 0xFF>>) == {:ok, [0x2193]}
    assert HiddenGraphics.encode_discard([0x03B3, 0x20AC, 0x03B4]) == {:ok, <<9, 10>>}

    assert Iconvex.convert(
             <<0x80, 0o001, 0xFF>>,
             FormatEffector.canonical_name(),
             "UTF-8",
             invalid: :discard
           ) == {:ok, <<0x2193::utf8>>}
  end

  test "RED: provenance pins the RFC artifact, normalized map, and profile boundary" do
    metadata = File.read!(@metadata)
    mapping = File.read!(@mapping)

    assert metadata =~ "https://www.rfc-editor.org/rfc/rfc698.txt"
    assert metadata =~ "a67d173ac8a5807983f9396ad1f67d0e65f082b08e74b849299c5feb2945c85f"
    assert metadata =~ sha256(mapping)
    assert metadata =~ "not required as part of the extended ASCII Telnet option"
    assert metadata =~ "9-bit modifier transport is not implemented as a text codec"
  end

  defp rows do
    @mapping
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.map(fn line ->
      [byte, format_effector, hidden_graphic, _description] =
        line |> String.trim() |> String.split(",", parts: 4)

      {
        String.to_integer(byte, 8),
        parse_codepoint(format_effector),
        parse_codepoint(hidden_graphic)
      }
    end)
  end

  defp parse_codepoint("U+" <> hexadecimal), do: String.to_integer(hexadecimal, 16)

  defp sha256(binary),
    do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
