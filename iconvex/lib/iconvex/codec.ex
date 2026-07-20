defmodule Iconvex.Codec do
  @moduledoc """
  Behaviour implemented by codecs supplied by external libraries.

  A codec converts between its byte representation and a list of Unicode code
  points. `decode_discard/1`, `encode_discard/1`, and `encode_substitute/2` are
  separate required callbacks so codecs with shift state or multi-code-point
  mappings can provide correct linear implementations of conversion policies.

  `encode_substitute/2` must retain state and longest-match semantics while
  applying replacements in one pass.
  `decode_error_recovery/0` lets a whole-string transform declare that its
  byte stream cannot be restarted after a malformed unit.
  `decode_to_utf8/1` and `encode_from_utf8/1` are optional strict fast paths.
  `decode_to_ucs4_discard/2` and `encode_from_ucs4_discard/2` are optional
  policy-preserving fast paths for explicit UCS-4 transports. An external
  library can implement them directly or pass `:direct_adapter` to
  `use Iconvex.Codec` when a shared engine exposes the same callbacks.

  One-shot conversions with `on_invalid_byte` arbitrate each valid source
  prefix against the target before invoking the next invalid-byte handler.
  Iconvex uses incremental encoder callbacks when available. Without them it
  may invoke the required encoder on cumulative prefixes and again for the
  final result, so external encoder callbacks must be deterministic and
  side-effect-safe. Implementing `encode_chunk/3`, or
  `stream_encoder_init/0` plus `encode_chunk/4` for a stateful codec, keeps
  this arbitration linear.
  """

  @type decode_error ::
          {:error, :invalid_sequence | :incomplete_sequence, non_neg_integer(), binary()}
  @type decode_result :: {:ok, [non_neg_integer()]} | decode_error()
  @type encode_error :: {:error, :unrepresentable_character, non_neg_integer()}
  @type legacy_direct_encode_error ::
          {:encode_error, :unrepresentable_character, non_neg_integer()}
  @type encode_result :: {:ok, binary()} | encode_error()
  @type stream_encode_policy ::
          :error
          | :discard
          | {:replace, (non_neg_integer() -> [non_neg_integer()])}

  @doc "Canonical, case-insensitive encoding name."
  @callback canonical_name() :: String.t()

  @doc "Additional case-insensitive names. Defaults to an empty list."
  @callback aliases() :: [String.t()]

  @doc "Strictly decodes a complete encoded binary into Unicode code points."
  @callback decode(binary()) :: decode_result()

  @doc "Decodes while discarding malformed input using codec-native state handling."
  @callback decode_discard(binary()) :: {:ok, [non_neg_integer()]} | decode_error()

  @doc "Strictly encodes Unicode code points."
  @callback encode([non_neg_integer()]) :: encode_result()

  @doc "Encodes while discarding unrepresentable code points in one linear pass."
  @callback encode_discard([non_neg_integer()]) :: encode_result()

  @doc "Encodes in one pass, replacing each unrepresentable code point with `replacer.(codepoint)`."
  @callback encode_substitute(
              [non_neg_integer()],
              (non_neg_integer() -> [non_neg_integer()])
            ) :: encode_result()

  @doc "Declares that the codec carries designation or shift state."
  @callback stateful?() :: boolean()

  @doc "Stable codec identifier used by shared codec engines. Defaults to the module."
  @callback codec_id() :: atom()

  @doc "Optional direct strict decoder to UTF-8."
  @callback decode_to_utf8(binary()) :: {:ok, binary()} | decode_error()

  @doc """
  Optional direct strict encoder from UTF-8.

  New codecs should return the ordinary `encode_error()` form for an
  unrepresentable character. The destination-tagged
  `{:encode_error, :unrepresentable_character, codepoint}` form remains
  accepted for backward compatibility with existing direct fast paths; Iconvex
  normalizes it without invoking `encode/1` as a fallback.
  """
  @callback encode_from_utf8(binary()) ::
              encode_result()
              | legacy_direct_encode_error()
              | {:decode_error, :invalid_sequence | :incomplete_sequence, non_neg_integer(),
                 binary()}

  @doc "Optional direct discard decoder to explicit UCS-4 byte order."
  @callback decode_to_ucs4_discard(binary(), :big | :little) :: {:ok, binary()} | :miss

  @doc "Optional direct discard encoder from aligned explicit UCS-4 byte order."
  @callback encode_from_ucs4_discard(binary(), :big | :little) :: {:ok, binary()} | :miss

  @doc """
  Number of source bytes consumed when one-shot or streaming policy recovers
  from one decode error. The default is one byte.

  Fixed-width external codecs should return their complete invalid unit width
  so discard/replacement recovery cannot lose framing. `sequence` is the exact
  sequence reported by the codec at the failing offset.
  """
  @callback decode_error_consumption(
              :invalid_sequence | :incomplete_sequence,
              sequence :: binary()
            ) :: pos_integer()

  @doc """
  Declares whether decode-policy recovery may restart after an invalid unit.

  The default, `:resynchronize`, decodes the valid prefix, consumes the
  codec-declared invalid unit, and continues. Whole-string transforms whose
  suffix loses meaning after an error return `:stop`. For `:stop`, Iconvex
  obtains the retained output from `decode_discard/1`, invokes one invalid-byte
  event, appends any requested replacement, and does not reinterpret the tail.
  """
  @callback decode_error_recovery() :: :resynchronize | :stop

  @doc """
  Incrementally decodes a stateless codec.

  When `final?` is false, a valid source prefix that may be extended by a
  later chunk must be returned as `pending` instead of decoded prematurely.
  """
  @callback decode_chunk(binary(), final? :: boolean()) ::
              {:ok, [non_neg_integer()], pending :: binary()} | decode_error()

  @doc """
  Incrementally encodes a stateless codec.

  When `final?` is false, a Unicode suffix that may participate in a longer
  destination mapping must be returned as `pending`.
  """
  @callback encode_chunk(
              [non_neg_integer()],
              final? :: boolean(),
              stream_encode_policy()
            ) :: {:ok, binary(), pending :: [non_neg_integer()]} | encode_error()

  @doc "Initial decoder state for a stateful external codec's Stream implementation."
  @callback stream_decoder_init() :: term()

  @doc "Incrementally decodes a stateful external codec. Error offsets are relative to `input`."
  @callback decode_chunk(binary(), state :: term(), final? :: boolean()) ::
              {:ok, [non_neg_integer()], next_state :: term(), pending :: binary()}
              | decode_error()

  @doc """
  Advances codec-owned decoder state after policy recovery consumes an invalid
  source unit.

  The default is to retain the state returned by decoding the valid prefix.
  Stateful codecs whose framing includes counters or bounded payloads should
  update those values for `consumed` without decoding it as ordinary input.
  """
  @callback decode_recovery_state(
              state :: term(),
              :invalid_sequence | :incomplete_sequence,
              sequence :: binary(),
              consumed :: binary()
            ) :: term()

  @doc "Initial encoder state for a stateful external codec's Stream implementation."
  @callback stream_encoder_init() :: term()

  @doc "Incrementally encodes a stateful external codec without finalizing before `final?`."
  @callback encode_chunk(
              [non_neg_integer()],
              state :: term(),
              final? :: boolean(),
              stream_encode_policy()
            ) ::
              {:ok, binary(), next_state :: term(), pending :: [non_neg_integer()]}
              | encode_error()

  @optional_callbacks aliases: 0,
                      stateful?: 0,
                      codec_id: 0,
                      decode_to_utf8: 1,
                      encode_from_utf8: 1,
                      decode_to_ucs4_discard: 2,
                      encode_from_ucs4_discard: 2,
                      decode_error_consumption: 2,
                      decode_error_recovery: 0,
                      decode_chunk: 2,
                      encode_chunk: 3,
                      stream_decoder_init: 0,
                      decode_chunk: 3,
                      decode_recovery_state: 4,
                      stream_encoder_init: 0,
                      encode_chunk: 4

  defmacro __using__(options) do
    direct_adapter = Keyword.get(options, :direct_adapter)

    quote bind_quoted: [direct_adapter: direct_adapter] do
      @behaviour Iconvex.Codec
      @iconvex_direct_adapter direct_adapter

      @impl true
      def aliases, do: []

      @impl true
      def stateful?, do: false

      if direct_adapter do
        @impl true
        def decode_to_ucs4_discard(input, endian),
          do: @iconvex_direct_adapter.decode_to_ucs4_discard(codec_id(), input, endian)

        @impl true
        def encode_from_ucs4_discard(input, endian),
          do: @iconvex_direct_adapter.encode_from_ucs4_discard(codec_id(), input, endian)

        defoverridable decode_to_ucs4_discard: 2, encode_from_ucs4_discard: 2
      end

      defoverridable aliases: 0, stateful?: 0
    end
  end
end
