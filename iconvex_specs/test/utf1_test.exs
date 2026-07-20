defmodule Iconvex.Specs.UTF1Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UTF1

  @boundary_vectors [
    {0x0000, <<0x00>>},
    {0x009F, <<0x9F>>},
    {0x00A0, <<0xA0, 0xA0>>},
    {0x00FF, <<0xA0, 0xFF>>},
    {0x0100, <<0xA1, 0x21>>},
    {0x4015, <<0xF5, 0xFF>>},
    {0x4016, <<0xF6, 0x21, 0x21>>},
    {0x38E2D, <<0xFB, 0xFF, 0xFF>>},
    {0x38E2E, <<0xFC, 0x21, 0x21, 0x21, 0x21>>},
    {0x10FFFF, <<0xFC, 0x21, 0x39, 0x6E, 0x6C>>}
  ]

  test "implements every ISO-IR-178 length boundary" do
    for {codepoint, bytes} <- @boundary_vectors do
      assert UTF1.encode([codepoint]) == {:ok, bytes}
      assert UTF1.decode(bytes) == {:ok, [codepoint]}
    end
  end

  test "rejects incomplete, forbidden-continuation, surrogate, and out-of-Unicode sequences" do
    assert UTF1.decode(<<0xF6, 0x21>>) == {:error, :incomplete_sequence, 0, <<0xF6, 0x21>>}
    assert match?({:error, :invalid_sequence, 0, _}, UTF1.decode(<<0xA1, 0x7F>>))
    assert UTF1.encode([0xD800]) == {:error, :unrepresentable_character, 0xD800}
  end
end
