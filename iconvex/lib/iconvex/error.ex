defmodule Iconvex.Error do
  @moduledoc """
  Typed conversion failure.

  Decode failures carry `offset`, `offset_unit`, and `sequence`; encode
  failures carry the first unrepresentable Unicode `codepoint`. Ordinary
  conversion errors use byte offsets. Packed conversion helpers use bit
  offsets and retain the exact packed fragment.
  """

  defexception kind: nil,
               encoding: nil,
               offset: nil,
               offset_unit: :byte,
               sequence: nil,
               codepoint: nil,
               message: nil

  @type kind :: :invalid_sequence | :incomplete_sequence | :unrepresentable_character
  @type t :: %__MODULE__{
          kind: kind(),
          encoding: String.t(),
          offset: non_neg_integer() | nil,
          offset_unit: :byte | :bit,
          sequence: bitstring() | Iconvex.Packed.LSB.t() | nil,
          codepoint: non_neg_integer() | nil,
          message: String.t()
        }

  @impl true
  def exception(fields) do
    fields = fields |> Map.new() |> Map.put_new(:offset_unit, :byte)
    struct!(__MODULE__, Map.put_new(fields, :message, build_message(fields)))
  end

  @impl true
  def message(%__MODULE__{message: message}), do: message

  defp build_message(%{
         kind: kind,
         encoding: encoding,
         offset: offset,
         offset_unit: offset_unit
       })
       when kind in [:invalid_sequence, :incomplete_sequence],
       do: "#{kind} in #{encoding} at #{offset_unit} offset #{offset}"

  defp build_message(%{
         kind: :unrepresentable_character,
         encoding: encoding,
         codepoint: codepoint
       }),
       do: "#{encoding} cannot represent U+#{Integer.to_string(codepoint, 16)}"

  defp build_message(fields), do: "conversion failed: #{inspect(fields)}"
end
