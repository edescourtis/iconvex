defmodule Iconvex.Specs.UTF8SigTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UTF8Sig

  test "registers Python's UTF-8-SIG wire convention" do
    for name <- ["UTF-8-SIG", "UTF8-SIG", "PYTHON-UTF-8-SIG"] do
      assert Iconvex.canonical_name(name) == {:ok, "UTF-8-SIG"}
    end
  end

  test "emits one signature and consumes only an initial signature" do
    assert UTF8Sig.encode([]) == {:ok, <<0xEF, 0xBB, 0xBF>>}
    assert UTF8Sig.encode(~c"A€") == {:ok, <<0xEF, 0xBB, 0xBF, 0x41, 0xE2, 0x82, 0xAC>>}
    assert UTF8Sig.decode(<<0xEF, 0xBB, 0xBF>>) == {:ok, []}
    assert UTF8Sig.decode(<<0xEF, 0xBB, 0xBF, 0x41>>) == {:ok, [?A]}
    assert UTF8Sig.decode(<<0x41>>) == {:ok, [?A]}
    assert UTF8Sig.decode(<<0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF>>) == {:ok, [0xFEFF]}
  end

  @tag timeout: 120_000
  test "round-trips every Unicode scalar with the exact UTF-8 payload" do
    scalars = Enum.to_list(0..0xD7FF) ++ Enum.to_list(0xE000..0x10FFFF)
    utf8 = :unicode.characters_to_binary(scalars, :unicode, :utf8)
    signed = <<0xEF, 0xBB, 0xBF>> <> utf8

    assert UTF8Sig.encode(scalars) == {:ok, signed}
    assert UTF8Sig.decode(signed) == {:ok, scalars}
  end

  test "preserves strict UTF-8 error boundaries after the signature" do
    assert UTF8Sig.decode(<<0xEF, 0xBB, 0xBF, 0xC0>>) ==
             {:error, :invalid_sequence, 3, <<0xC0>>}

    assert UTF8Sig.decode(<<0xEF, 0xBB>>) ==
             {:error, :incomplete_sequence, 0, <<0xEF, 0xBB>>}
  end
end
