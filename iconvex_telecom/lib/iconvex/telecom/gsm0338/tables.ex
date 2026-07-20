defmodule Iconvex.Telecom.GSM0338.Tables do
  @moduledoc false

  @table_path Path.expand("../../../../priv/gsm0338_tables.etf", __DIR__)
  @external_resource @table_path
  @data @table_path |> File.read!() |> :erlang.binary_to_term()

  @languages {
    :default,
    :turkish,
    :spanish,
    :portuguese,
    :bengali,
    :gujarati,
    :hindi,
    :kannada,
    :malayalam,
    :oriya,
    :punjabi,
    :tamil,
    :telugu,
    :urdu
  }

  @locking @data.locking
  @single_shift @data.single_shift

  @locking_encode @locking
                  |> Tuple.to_list()
                  |> Enum.map(fn
                    nil ->
                      nil

                    table ->
                      table
                      |> Tuple.to_list()
                      |> Enum.with_index()
                      |> Enum.reduce(%{}, fn
                        {_codepoint, 0x1B}, acc -> acc
                        {codepoint, byte}, acc -> Map.put_new(acc, codepoint, byte)
                      end)
                      |> Map.put(0x20, 0x20)
                  end)
                  |> List.to_tuple()

  @single_encode @single_shift
                 |> Tuple.to_list()
                 |> Enum.map(fn table ->
                   table
                   |> Tuple.to_list()
                   |> Enum.with_index()
                   |> Enum.reduce(%{}, fn
                     {nil, _byte}, acc -> acc
                     {codepoint, byte}, acc -> Map.put_new(acc, codepoint, <<0x1B, byte>>)
                   end)
                 end)
                 |> List.to_tuple()

  @locking_ids for id <- 0..13, elem(@locking, id) != nil, do: id
  @name_to_id @languages
              |> Tuple.to_list()
              |> Enum.with_index()
              |> Map.new(fn {name, id} -> {Atom.to_string(name), id} end)

  def source, do: @data.source

  def locking_tables do
    Enum.map(@locking_ids, &%{id: &1, name: elem(@languages, &1)})
  end

  def single_shift_tables do
    Enum.map(0..13, &%{id: &1, name: elem(@languages, &1)})
  end

  def resolve_locking(value) do
    with {:ok, id} <- resolve_id(value),
         true <- id in @locking_ids do
      {:ok, id}
    else
      _ -> :error
    end
  end

  def resolve_single_shift(value) do
    with {:ok, id} <- resolve_id(value),
         true <- id in 0..13 do
      {:ok, id}
    else
      _ -> :error
    end
  end

  def locking(id), do: elem(@locking, id)
  def single_shift(id), do: elem(@single_shift, id)
  def locking_encode(id), do: elem(@locking_encode, id)
  def single_encode(id), do: elem(@single_encode, id)
  defp resolve_id(id) when is_integer(id), do: {:ok, id}
  defp resolve_id(name) when is_atom(name), do: resolve_id(Atom.to_string(name))

  defp resolve_id(name) when is_binary(name) do
    key = name |> String.downcase(:ascii) |> String.replace(["-", " "], "_")

    case Map.fetch(@name_to_id, key) do
      {:ok, id} -> {:ok, id}
      :error -> :error
    end
  end

  defp resolve_id(_value), do: :error
end
