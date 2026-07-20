defmodule Iconvex.Telecom.GSM0338 do
  @moduledoc """
  GSM 03.38 / 3GPP TS 23.038 in the unpacked form used by SMPP.

  Each GSM septet occupies one byte whose most-significant bit is zero. National
  locking and single-shift tables can be selected independently.
  """

  alias Iconvex.Telecom.GSM0338.{Engine, Tables}

  @option_keys [:locking, :single_shift]

  def locking_tables, do: Tables.locking_tables()
  def single_shift_tables, do: Tables.single_shift_tables()
  def source, do: Tables.source()

  def valid_pairs do
    for locking <- locking_tables(), single <- single_shift_tables() do
      %{locking: locking.name, single_shift: single.name}
    end
  end

  def locking_table?(table), do: match?({:ok, _id}, Tables.resolve_locking(table))
  def single_shift_table?(table), do: match?({:ok, _id}, Tables.resolve_single_shift(table))

  def decode(input, options \\ []) when is_binary(input) do
    with {:ok, locking, single} <- resolve(options) do
      Engine.decode(input, locking, single)
    end
  end

  def decode_discard(input, options \\ []) when is_binary(input) do
    with {:ok, locking, single} <- resolve(options) do
      Engine.decode_discard(input, locking, single)
    end
  end

  def decode_utf8(input, options \\ []) when is_binary(input) do
    with {:ok, locking, single} <- resolve(options) do
      Engine.decode_to_utf8(input, locking, single)
    end
  end

  def encode(codepoints, options \\ []) when is_list(codepoints) do
    with {:ok, locking, single} <- resolve(options) do
      Engine.encode(codepoints, locking, single)
    end
  end

  def encode_discard(codepoints, options \\ []) when is_list(codepoints) do
    with {:ok, locking, single} <- resolve(options) do
      Engine.encode_discard(codepoints, locking, single)
    end
  end

  def encode_utf8(input, options \\ []) when is_binary(input) do
    with {:ok, locking, single} <- resolve(options) do
      case Engine.encode_from_utf8(input, locking, single) do
        {:encode_error, kind, codepoint} -> {:error, kind, codepoint}
        {:decode_error, kind, offset, bytes} -> {:error, kind, offset, bytes}
        result -> result
      end
    end
  end

  defp resolve(options) when is_list(options) do
    cond do
      not Keyword.keyword?(options) ->
        {:error, :options_must_be_a_keyword_list}

      key = Enum.find(Keyword.keys(options), &(&1 not in @option_keys)) ->
        {:error, {:unknown_option, key}}

      key = duplicate_key(options) ->
        {:error, {:duplicate_option, key}}

      true ->
        locking = Keyword.get(options, :locking, :default)
        single = Keyword.get(options, :single_shift, :default)

        with {:ok, locking_id} <- resolve_locking(locking),
             {:ok, single_id} <- resolve_single(single) do
          {:ok, locking_id, single_id}
        end
    end
  end

  defp resolve(_options), do: {:error, :options_must_be_a_keyword_list}

  defp resolve_locking(value) do
    case Tables.resolve_locking(value) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, {:unknown_locking_table, value}}
    end
  end

  defp resolve_single(value) do
    case Tables.resolve_single_shift(value) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, {:unknown_single_shift_table, value}}
    end
  end

  defp duplicate_key(options) do
    keys = Keyword.keys(options)
    Enum.find(keys, fn key -> Enum.count(keys, &(&1 == key)) > 1 end)
  end
end
