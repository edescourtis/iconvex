defmodule Iconvex.UpstreamStatefulTest do
  use ExUnit.Case, async: false

  alias Iconvex.UpstreamFixture

  @fixtures UpstreamFixture.root()

  @snippet_names Enum.filter(UpstreamFixture.snippet_names(), fn name ->
                   name
                   |> UpstreamFixture.snippet_encoding()
                   |> Iconvex.Registry.builtin_resolve()
                   |> then(&match?({:ok, _entry}, &1))
                 end)

  for name <- @snippet_names do
    test "GNU check-stateful #{name}" do
      name = unquote(name)
      encoding = UpstreamFixture.snippet_encoding(name)
      encoded = File.read!(Path.join(@fixtures, "#{name}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{name}-snippet.UTF-8"))

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}

      alternative = Path.join(@fixtures, "#{name}-snippet.alt")

      if File.regular?(alternative) do
        assert Iconvex.convert(File.read!(alternative), encoding, "UTF-8") == {:ok, utf8}
      end
    end
  end
end
