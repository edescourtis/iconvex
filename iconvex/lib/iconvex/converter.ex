defmodule Iconvex.Converter do
  @moduledoc """
  Immutable state returned by the buffered chunked-conversion API.

  Treat fields as opaque. Use `Iconvex.feed/2`, `Iconvex.finish/1`, and
  `Iconvex.finish_with_state/1` to operate on a converter.
  """

  @enforce_keys [
    :from,
    :to,
    :from_entry,
    :to_entry,
    :options,
    :stateful_source?,
    :provider_snapshot
  ]
  defstruct [
    :from,
    :to,
    :from_entry,
    :to_entry,
    :options,
    :stateful_source?,
    :provider_snapshot,
    pending: <<>>,
    chunks: [],
    input_bytes: 0,
    finished?: false
  ]

  @type t :: %__MODULE__{
          from: String.t() | atom(),
          to: String.t() | atom(),
          from_entry: map(),
          to_entry: map(),
          options: keyword(),
          stateful_source?: boolean(),
          provider_snapshot: %{optional(atom()) => atom()},
          pending: binary(),
          chunks: [binary()],
          input_bytes: non_neg_integer(),
          finished?: boolean()
        }
end
