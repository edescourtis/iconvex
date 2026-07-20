defmodule Iconvex.UpstreamStatelessTest do
  use ExUnit.Case, async: false
  import Bitwise

  alias Iconvex.UpstreamFixture

  @mapping_files Enum.filter(UpstreamFixture.mapping_files(), fn path ->
                   path
                   |> UpstreamFixture.encoding_for()
                   |> Iconvex.Registry.builtin_resolve()
                   |> then(&match?({:ok, _entry}, &1))
                 end)

  for path <- @mapping_files do
    name = Path.basename(path, ".TXT")

    test "GNU check-stateless #{name}" do
      path = unquote(path)
      encoding = UpstreamFixture.encoding_for(path)
      mappings = UpstreamFixture.mappings(path)

      {encoded, codepoints} = UpstreamFixture.interspersed_decode_input(mappings)
      expected_utf8 = :unicode.characters_to_binary(codepoints)
      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, expected_utf8}

      inverse = UpstreamFixture.inverse_mappings(path)
      {codepoints, expected_encoded} = UpstreamFixture.interspersed_encode_input(inverse)
      utf8 = :unicode.characters_to_binary(codepoints)
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, expected_encoded}
    end
  end

  test "GNU genutf8/check-stateless covers every Unicode BMP scalar" do
    utf8 =
      0..0xFFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Enum.to_list()
      |> :unicode.characters_to_binary()

    assert Iconvex.convert(utf8, "UTF-8", "UTF-8") == {:ok, utf8}
  end

  for encoding <- ["GB18030:2005", "GB18030:2022"] do
    test "GNU gengb18030z/check-stateless supplementary range for #{encoding}" do
      encoding = unquote(encoding)

      for first <- 0x01..0x10 do
        utf8 =
          (first <<< 16)..bor(first <<< 16, 0xFFFF)
          |> Enum.to_list()
          |> :unicode.characters_to_binary()

        assert {:ok, encoded} = Iconvex.convert(utf8, "UTF-8", encoding)
        assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      end
    end
  end
end
