defmodule Iconvex.Specs.ICULMBCSVariant do
  @moduledoc false

  defmacro __using__(options) do
    optimization_group = Keyword.fetch!(options, :optimization_group)
    canonical_name = "LMBCS-#{optimization_group}"
    codec_id = String.to_atom("icu_lmbcs#{optimization_group}")

    quote bind_quoted: [
            optimization_group: optimization_group,
            canonical_name: canonical_name,
            codec_id: codec_id
          ] do
      @moduledoc """
      Pure native Elixir port of ICU 78.3's #{canonical_name} optimization profile.

      LMBCS's optimization group changes which national subconverter may omit
      its group marker. The remaining grammar, thirteen exact subconverters,
      control and exception groups, and UTF-16 compatibility behavior are
      shared with the pinned ICU release-78.3 implementation.
      """

      use Iconvex.Codec

      @optimization_group optimization_group
      @canonical_name canonical_name
      @codec_id codec_id

      @impl true
      def canonical_name, do: @canonical_name

      @impl true
      def codec_id, do: @codec_id

      def optimization_group, do: @optimization_group
      def aggregate_sha256, do: Iconvex.Specs.ICULMBCS1.aggregate_sha256()
      def release, do: Iconvex.Specs.ICULMBCS1.release()
      def revision, do: Iconvex.Specs.ICULMBCS1.revision()
      def source_url, do: Iconvex.Specs.ICULMBCS1.source_url()
      def sources, do: Iconvex.Specs.ICULMBCS1.sources()

      @impl true
      def encode(codepoints),
        do: Iconvex.Specs.ICULMBCS1.encode(codepoints, @optimization_group)

      @impl true
      def encode_discard(codepoints),
        do: Iconvex.Specs.ICULMBCS1.encode_discard(codepoints, @optimization_group)

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Iconvex.Specs.ICULMBCS1.encode_substitute(
            codepoints,
            replacer,
            @optimization_group
          )

      @impl true
      def decode(input),
        do: Iconvex.Specs.ICULMBCS1.decode(input, @optimization_group)

      @impl true
      def decode_discard(input),
        do: Iconvex.Specs.ICULMBCS1.decode_discard(input, @optimization_group)

      @impl true
      def decode_to_utf8(input),
        do: Iconvex.Specs.ICULMBCS1.decode_to_utf8(input, @optimization_group)

      @impl true
      def encode_from_utf8(input),
        do: Iconvex.Specs.ICULMBCS1.encode_from_utf8(input, @optimization_group)

      @impl true
      def decode_chunk(input, final?),
        do:
          Iconvex.Specs.ICULMBCS1.decode_chunk_for_group(
            input,
            final?,
            @optimization_group
          )

      @impl true
      def decode_error_consumption(kind, sequence),
        do: Iconvex.Specs.ICULMBCS1.decode_error_consumption(kind, sequence)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do:
          Iconvex.Specs.ICULMBCS1.encode_chunk_for_group(
            codepoints,
            final?,
            policy,
            @optimization_group
          )
    end
  end
end

defmodule Iconvex.Specs.ICULMBCS2 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 2
end

defmodule Iconvex.Specs.ICULMBCS3 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 3
end

defmodule Iconvex.Specs.ICULMBCS4 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 4
end

defmodule Iconvex.Specs.ICULMBCS5 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 5
end

defmodule Iconvex.Specs.ICULMBCS6 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 6
end

defmodule Iconvex.Specs.ICULMBCS8 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 8
end

defmodule Iconvex.Specs.ICULMBCS11 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 11
end

defmodule Iconvex.Specs.ICULMBCS16 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 16
end

defmodule Iconvex.Specs.ICULMBCS17 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 17
end

defmodule Iconvex.Specs.ICULMBCS18 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 18
end

defmodule Iconvex.Specs.ICULMBCS19 do
  use Iconvex.Specs.ICULMBCSVariant, optimization_group: 19
end
