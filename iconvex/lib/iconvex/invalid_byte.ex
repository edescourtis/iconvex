defmodule Iconvex.InvalidByte do
  @moduledoc """
  Unmapped or malformed source byte passed to `:on_invalid_byte`.

  `offset` is absolute from the beginning of the complete input stream.
  `sequence` is the source codec's complete original error sequence. A codec
  may declare that one recovery event consumes a multi-byte source unit (for
  example, an invalid zero-padded 16-bit punched-card word).

  `byte` is always the first byte of `sequence`. It is retained for legacy
  `%02x` substitution templates and callback compatibility; it does not imply
  that the event consumes exactly one byte.
  """

  @enforce_keys [:encoding, :kind, :offset, :byte, :sequence]
  defstruct [:encoding, :kind, :offset, :byte, :sequence]

  @type t :: %__MODULE__{
          encoding: String.t(),
          kind: :invalid_sequence | :incomplete_sequence,
          offset: non_neg_integer(),
          byte: 0..255,
          sequence: binary()
        }
end
