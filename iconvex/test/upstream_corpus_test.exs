defmodule Iconvex.UpstreamCorpusTest do
  use ExUnit.Case, async: false

  alias Iconvex.UpstreamFixture

  test "separates the exact GNU libiconv 1.19 tests from the derived Makefile" do
    assert length(UpstreamFixture.upstream_files()) == 267

    assert UpstreamFixture.upstream_digest() ==
             "b328fa4374b3b76df8acc47009a2b39b5ff5aaa1d7430cb12d9ae89a20202225"

    assert UpstreamFixture.derived_files()
           |> Enum.map(&Path.basename/1) == ["Makefile"]

    assert UpstreamFixture.derived_digest() ==
             "dd437384d8e116abb838757ec1d7809d17a5fae8b3fe48e08b3d6f31910ff09b"

    assert length(UpstreamFixture.corpus_files()) == 268

    assert UpstreamFixture.corpus_digest() ==
             "546c5b74a57687415f6bc67548dc1a190e9be54417b4df530addf7f9b96b095d"
  end
end
