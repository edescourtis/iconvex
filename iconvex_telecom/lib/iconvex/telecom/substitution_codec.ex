defmodule Iconvex.Telecom.SubstitutionCodec do
  @moduledoc false

  defmacro __using__(_options) do
    quote do
      use Iconvex.Codec

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Iconvex.Telecom.Substitution.encode(__MODULE__, codepoints, replacer)

      defoverridable encode_substitute: 2
    end
  end
end
