defmodule Iconvex.ExternalCallbacks do
  @moduledoc false

  @type result :: {:called, term()} | :missing

  @spec call(module(), atom(), [term()]) :: result()
  def call(module, function, arguments)
      when is_atom(module) and is_atom(function) and is_list(arguments) do
    arity = length(arguments)

    if function_exported?(module, function, arity) do
      try do
        {:called, invoke(module, function, arguments)}
      rescue
        error in UndefinedFunctionError ->
          if exact_missing_callback?(error, module, function, arity) do
            :missing
          else
            reraise(error, __STACKTRACE__)
          end
      end
    else
      :missing
    end
  end

  # Kept separate from the export check so every optional dispatch has one
  # narrow place to handle a module purge between checking and invocation.
  defp invoke(module, function, arguments), do: apply(module, function, arguments)

  defp exact_missing_callback?(error, module, function, arity) do
    error.module == module and error.function == function and error.arity == arity
  end
end
