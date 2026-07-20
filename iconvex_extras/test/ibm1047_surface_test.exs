defmodule Iconvex.Extras.IBM1047SurfaceTest do
  use ExUnit.Case, async: false

  test "GNU check-ebcdic default and ZOS_UNIX surface" do
    assert Iconvex.convert("hello\u0085", "UTF-8", "IBM-1047") ==
             {:ok, <<0x88, 0x85, 0x93, 0x93, 0x96, 0x15>>}

    assert Iconvex.convert("hello\n", "ASCII", "IBM-1047") ==
             {:ok, <<0x88, 0x85, 0x93, 0x93, 0x96, 0x25>>}

    assert Iconvex.convert("hello\n", "ASCII", "IBM-1047/ZOS_UNIX") ==
             {:ok, <<0x88, 0x85, 0x93, 0x93, 0x96, 0x15>>}

    assert Iconvex.convert(<<0x88, 0x85, 0x93, 0x93, 0x96, 0x15>>, "IBM-1047/ZOS_UNIX", "ASCII") ==
             {:ok, "hello\n"}

    assert Iconvex.convert("hello\u0085", "UTF-8", "IBM-1047/ZOS_UNIX") ==
             {:ok, <<0x88, 0x85, 0x93, 0x93, 0x96, 0x25>>}

    assert Iconvex.convert(
             <<0x88, 0x85, 0x93, 0x93, 0x96, 0x25>>,
             "IBM-1047/ZOS_UNIX",
             "UTF-8"
           ) == {:ok, "hello\u0085"}

    assert Iconvex.convert("ｈℯ𝚕𝚕•\n", "UTF-8", "IBM-1047/ZOS_UNIX/TRANSLIT") ==
             {:ok, <<0x88, 0x85, 0x93, 0x93, 0x96, 0x15>>}

    assert Iconvex.convert("hello€\n", "UTF-8", "IBM-1047/ZOS_UNIX/IGNORE") ==
             {:ok, <<0x88, 0x85, 0x93, 0x93, 0x96, 0x15>>}
  end
end
