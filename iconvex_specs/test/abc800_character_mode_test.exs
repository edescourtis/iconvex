defmodule Iconvex.Specs.ABC800CharacterModeTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.ABC800CharacterMode1981, as: Codec

  @root Path.expand("..", __DIR__)
  @mapping Path.join(@root, "priv/sources/abc800-basic-ii/character_mode.csv")
  @metadata Path.join(@root, "priv/sources/abc800-basic-ii/SOURCE_METADATA.md")

  test "RED: the primary-manual character-mode profile is registered without claiming graphics mode" do
    assert Codec in Iconvex.Specs.additional_codecs()
    assert Codec.canonical_name() == "LUXOR-ABC800-BASIC-II-1981-CHARACTER-MODE"
    assert Codec.aliases() == ["ABC800-CHARACTER-MODE"]

    assert {:ok, entry} = Iconvex.ExternalRegistry.resolve("ABC800-CHARACTER-MODE")
    assert entry.codec == Codec
    assert :error = Iconvex.ExternalRegistry.resolve("ABC800")
  end

  test "RED: every normalized primary-manual byte vector is exact in both directions" do
    rows = rows()
    assert length(rows) == 128
    assert Enum.map(rows, &elem(&1, 0)) == Enum.to_list(0..127)

    for {byte, codepoint} <- rows do
      assert Codec.decode(<<byte>>) == {:ok, [codepoint]}
      assert Codec.encode([codepoint]) == {:ok, <<byte>>}
    end

    input = 0..127 |> Enum.to_list() |> :erlang.list_to_binary()
    expected = Enum.map(rows, &elem(&1, 1))
    assert Codec.decode(input) == {:ok, expected}
    assert Codec.encode(expected) == {:ok, input}
  end

  test "RED: high bytes are invalid and recovery makes one-byte progress" do
    for byte <- 128..255 do
      assert Codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
    end

    assert Codec.decode_discard(<<0x80, ?A, 0xFF>>) == {:ok, [?A]}
    assert Codec.encode_discard([?A, 0x20AC, ?B]) == {:ok, "AB"}

    assert Iconvex.convert(<<0x80, ?A, 0xFF>>, "ABC800-CHARACTER-MODE", "UTF-8",
             invalid: :discard
           ) == {:ok, "A"}
  end

  test "RED: mapping and reference metadata are digest-pinned" do
    metadata = File.read!(@metadata)
    mapping = File.read!(@mapping)

    assert metadata =~
             "https://www.abc80.net/archive/luxor/ABC80x/ABC800-manual-BASIC-II.pdf"

    assert metadata =~ "c5bc63ce12c37d47e2fbfbb9118e581b4738c9f8b9de8d4b0f421328c2f2e3b5"
    assert metadata =~ sha256(mapping)
    assert metadata =~ "character mode"
    assert metadata =~ "graphics mode is not implemented"
  end

  defp rows do
    @mapping
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.map(fn line ->
      [byte, codepoint, _name] = line |> String.trim() |> String.split(",", parts: 3)
      {String.to_integer(byte), codepoint |> String.trim_leading("U+") |> String.to_integer(16)}
    end)
  end

  defp sha256(binary),
    do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
