defmodule Iconvex.InternalSurfaceContractTest do
  use ExUnit.Case, async: true

  test "superseded recovery helpers are not exported" do
    Code.ensure_loaded!(Iconvex)
    Code.ensure_loaded!(Iconvex.UTF7Codec)

    refute function_exported?(Iconvex, :__stream_invalid_byte__, 6)
    refute function_exported?(Iconvex.UTF7Codec, :decode_discard_gnu, 1)
  end

  test "stateful direct-table warming is not a production export" do
    for module <- [
          Iconvex.StatefulCodec,
          Iconvex.ISO2022JPCodec,
          Iconvex.ISO2022CNCodec
        ] do
      Code.ensure_loaded!(module)
      refute function_exported?(module, :warm_direct_tables, 0)
      refute function_exported?(module, :warm_direct_tables, 1)
    end
  end
end
