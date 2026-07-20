defmodule Iconvex.Extras.TableConformanceTest do
  use ExUnit.Case, async: false

  alias Iconvex.Extras.TestFixture

  for path <- TestFixture.mapping_files() do
    name = Path.basename(path, ".TXT")

    test "GNU check-stateless extra #{name}" do
      path = unquote(path)
      encoding = TestFixture.encoding_for(path)
      mappings = TestFixture.mappings(path)

      {encoded, codepoints} = TestFixture.interspersed_decode_input(mappings)
      expected_utf8 = :unicode.characters_to_binary(codepoints)
      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, expected_utf8}

      inverse = TestFixture.inverse_mappings(path)
      {codepoints, expected_encoded} = TestFixture.interspersed_encode_input(inverse)
      utf8 = :unicode.characters_to_binary(codepoints)
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, expected_encoded}
    end
  end

  test "extra table discard handles long invalid runs in one pass" do
    input = ["A", :binary.copy(<<0x9B>>, 250_000), "B"] |> IO.iodata_to_binary()

    assert Iconvex.convert(input, "CP856", "UTF-8", invalid: :discard) == {:ok, "AB"}
  end
end
