defmodule Iconvex.Specs.ISCII.Data do
  @moduledoc false
  @path Path.expand("../../../../priv/iscii.etf", __DIR__)
  @external_resource @path

  def fetch, do: Iconvex.Specs.RuntimeAsset.fetch(__MODULE__, @path)
end
