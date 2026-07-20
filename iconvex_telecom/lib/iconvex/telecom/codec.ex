defmodule Iconvex.Telecom.Codec do
  @moduledoc false

  defmacro __using__(options) do
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.get(options, :aliases, [])
    locking = Keyword.fetch!(options, :locking)
    single_shift = Keyword.fetch!(options, :single_shift)

    quote bind_quoted: [
            canonical: canonical,
            aliases: aliases,
            locking: locking,
            single_shift: single_shift
          ] do
      use Iconvex.Codec
      alias Iconvex.Telecom.GSM0338.Engine

      @canonical canonical
      @codec_aliases aliases
      @locking locking
      @single_shift single_shift

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: @codec_aliases

      @impl true
      def stateful?, do: true

      @impl true
      def decode(input), do: Engine.decode(input, @locking, @single_shift)

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, @locking, @single_shift)

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, @locking, @single_shift)

      @impl true
      def encode_discard(codepoints),
        do: Engine.encode_discard(codepoints, @locking, @single_shift)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Engine.encode_substitute(codepoints, @locking, @single_shift, replacer)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, @locking, @single_shift)

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, @locking, @single_shift)
    end
  end
end
