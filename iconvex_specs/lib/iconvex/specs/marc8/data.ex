defmodule Iconvex.Specs.MARC8.Data do
  @moduledoc false

  @path Path.expand("../../../../priv/marc8.etf", __DIR__)
  @external_resource @path

  def fetch, do: Iconvex.Specs.RuntimeAsset.fetch(__MODULE__, @path)
end
