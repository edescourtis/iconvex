defmodule Iconvex.Specs.PropertyTokenMapping do
  @moduledoc """
  Behaviour for a source-qualified mapping of one property token to one scalar.

  Property-token mappings are deliberately separate from `Iconvex.Codec`.
  They do not imply a byte-stream grammar, concatenation, framing, or aliases.
  """

  @type token :: binary()
  @type scalar :: non_neg_integer()
  @type mapping_error ::
          {:invalid_token_length, non_neg_integer()}
          | {:invalid_token_digit, non_neg_integer(), binary()}
          | {:unassigned_token, token()}
          | {:invalid_argument, :token | :scalar | :utf8}
          | {:invalid_unicode_scalar, integer()}
          | {:unrepresentable_scalar, scalar()}
          | {:invalid_scalar_count, non_neg_integer()}
          | {:invalid_utf8, :invalid_sequence | :incomplete_sequence, non_neg_integer(), binary()}

  @callback mapping_name() :: String.t()
  @callback metadata() :: map()
  @callback decode_token(token()) :: {:ok, scalar()} | {:error, mapping_error()}
  @callback decode_token_to_utf8(token()) :: {:ok, binary()} | {:error, mapping_error()}
  @callback encode_scalar(term()) :: {:ok, token()} | {:error, mapping_error()}
  @callback encode_utf8_to_token(term()) :: {:ok, token()} | {:error, mapping_error()}
end
