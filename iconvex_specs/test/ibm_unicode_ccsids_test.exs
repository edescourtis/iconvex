defmodule Iconvex.Specs.IBMUnicodeCCSIDsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.IBMUnicodeCCSIDs, as: Codecs

  @corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @source Path.expand(
            "../priv/sources/ibm-unicode-ccsids/ccsid-values-defined-i.html",
            __DIR__
          )

  test "registers valid IBM UTF-16BE CCSIDs without claiming retired 61952" do
    for ccsid <- [
          1200,
          1201,
          13488,
          13489,
          17584,
          17585,
          21680,
          21681,
          25776,
          25777,
          29872,
          29873,
          61955,
          61956
        ],
        name <- ["IBM-#{ccsid}", "IBM#{ccsid}", "CCSID#{ccsid}"] do
      assert {:ok, %{canonical: "IBM-1200"}} = Iconvex.Registry.resolve(name)
    end

    assert :error = Iconvex.Registry.resolve("IBM-61952")
  end

  test "is byte-for-byte UTF-16BE over all 1,112,064 Unicode scalars" do
    corpus = File.read!(@corpus)
    assert {:ok, utf8} = Iconvex.convert(corpus, "UTF-32BE", "UTF-8")
    assert {:ok, expected} = Iconvex.convert(utf8, "UTF-8", "UTF-16BE")

    for name <- ["IBM-1200", "IBM-13488"] do
      assert Iconvex.convert(utf8, "UTF-8", name) == {:ok, expected}
      assert Iconvex.convert(expected, name, "UTF-8") == {:ok, utf8}
    end
  end

  test "implements direct callbacks and exact malformed UTF-16 errors" do
    codec = Codecs.Codec
    utf8 = <<?A, 0x1F4A9::utf8>>
    encoded = <<0, ?A, 0xD8, 0x3D, 0xDC, 0xA9>>

    assert codec.encode_from_utf8(utf8) == {:ok, encoded}
    assert codec.decode_to_utf8(encoded) == {:ok, utf8}
    assert codec.decode(<<0xD8, 0x3D>>) == {:error, :incomplete_sequence, 0, <<0xD8, 0x3D>>}

    assert codec.decode(<<0xDC, 0x00>>) ==
             {:error, :invalid_sequence, 0, <<0xDC, 0x00>>}
  end

  test "pins IBM's CCSID table and ICU's alias classification" do
    assert Codecs.ibm_source_sha256() ==
             "d0682e71d66de77bd518cda1e82377474bdb78cd6dd87b0c17cbccdc25c67dfb"

    assert sha256(File.read!(@source)) == Codecs.ibm_source_sha256()

    registry =
      Path.expand(
        "../priv/sources/icu-78.3-unicode-variants/convrtrs.txt",
        __DIR__
      )
      |> File.read!()

    assert registry =~ "ibm-1200 { IBM* } # UTF-16 BE with IBM PUA"
    assert registry =~ "ibm-13488 { IBM } # Unicode 2.0, UTF-16 BE with IBM PUA"
    assert registry =~ "# ibm-61952 is not a valid CCSID because it's Unicode 1.1"
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
