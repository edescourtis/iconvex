defmodule Iconvex.Telecom.Substitution do
  @moduledoc false

  def encode(codec, codepoints, replacer)
      when is_atom(codec) and is_list(codepoints) and is_function(replacer, 1) do
    with {:ok, chunks} <- substitute_codepoints(codec, codepoints, replacer, []) do
      chunks
      |> :lists.reverse()
      |> :lists.flatten()
      |> codec.encode()
    end
  end

  defp substitute_codepoints(_codec, [], _replacer, acc), do: {:ok, acc}

  defp substitute_codepoints(codec, [codepoint | rest], replacer, acc) do
    case codec.encode([codepoint]) do
      {:ok, _bytes} ->
        substitute_codepoints(codec, rest, replacer, [[codepoint] | acc])

      {:error, :unrepresentable_character, _reported} ->
        replacement = replacer.(codepoint)

        case codec.encode(replacement) do
          {:ok, _bytes} ->
            substitute_codepoints(codec, rest, replacer, [replacement | acc])

          {:error, :unrepresentable_character, replacement_codepoint} ->
            {:error, :unrepresentable_character, replacement_codepoint}
        end
    end
  end
end
