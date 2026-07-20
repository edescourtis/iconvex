defmodule Iconvex.Telecom.Morse do
  @moduledoc """
  International Morse signals from ITU-R M.1677-1.

  The Recommendation standardizes dot/dash signals and their timing, not an
  octet stream. Iconvex therefore uses an explicit, lossless textual envelope:
  ASCII `.` and `-` form a signal, one ASCII space separates characters, and
  the standalone token `/` represents a text space. Procedural signals remain
  available through `procedural_signals/0` and are not invented as Unicode
  characters.
  """

  use Iconvex.Telecom.SubstitutionCodec

  @letters %{
    ?A => ".-",
    ?B => "-...",
    ?C => "-.-.",
    ?D => "-..",
    ?E => ".",
    0x00E9 => "..-..",
    ?F => "..-.",
    ?G => "--.",
    ?H => "....",
    ?I => "..",
    ?J => ".---",
    ?K => "-.-",
    ?L => ".-..",
    ?M => "--",
    ?N => "-.",
    ?O => "---",
    ?P => ".--.",
    ?Q => "--.-",
    ?R => ".-.",
    ?S => "...",
    ?T => "-",
    ?U => "..-",
    ?V => "...-",
    ?W => ".--",
    ?X => "-..-",
    ?Y => "-.--",
    ?Z => "--.."
  }

  @figures %{
    ?1 => ".----",
    ?2 => "..---",
    ?3 => "...--",
    ?4 => "....-",
    ?5 => ".....",
    ?6 => "-....",
    ?7 => "--...",
    ?8 => "---..",
    ?9 => "----.",
    ?0 => "-----"
  }

  @punctuation %{
    ?. => ".-.-.-",
    ?, => "--..--",
    ?: => "---...",
    ?? => "..--..",
    ?' => ".----.",
    ?- => "-....-",
    ?/ => "-..-.",
    ?( => "-.--.",
    ?) => "-.--.-",
    ?\" => ".-..-.",
    ?= => "-...-",
    ?+ => ".-.-.",
    0x00D7 => "-..-",
    ?@ => ".--.-."
  }

  @table Map.merge(@letters, Map.merge(@figures, @punctuation))
  @decode @table |> Map.delete(0x00D7) |> Map.new(fn {cp, signal} -> {signal, cp} end)
  @lowercase Map.new(?a..?z, &{&1, &1 - 32})

  @procedural %{
    understood: "...-.",
    error: "........",
    invitation_to_transmit: "-.-",
    wait: ".-...",
    end_of_work: "...-.-",
    starting_signal: "-.-.-"
  }

  @source_manifest %{
    recommendation: "ITU-R M.1677-1 (10/2009)",
    source_sha256: "a3eab8884c24200f229ef20615ee3ae14329ba0f0a29c7a85a1eaa3cac442b97",
    source_url: "https://www.itu.int/dms_pubrec/itu-r/rec/m/R-REC-M.1677-1-200910-I!!PDF-E.pdf"
  }

  @impl true
  def canonical_name, do: "MORSE-ITU-M1677"

  @impl true
  def aliases,
    do: [
      "INTERNATIONAL-MORSE",
      "INTERNATIONAL-MORSE-CODE",
      "ITU-R-M.1677-1",
      "ITU-R-M.1677",
      "MORSE-CODE"
    ]

  @impl true
  def stateful?, do: false

  @impl true
  def decode_error_consumption(:invalid_sequence, sequence)
      when is_binary(sequence) and byte_size(sequence) > 0,
      do: byte_size(sequence)

  def decode_error_consumption(_kind, _sequence), do: 1

  @doc "Returns all 51 written-character signal assignments in clause 1.1."
  def table, do: @table

  @doc "Returns the non-graphic operational signals in clause 1.1.3."
  def procedural_signals, do: @procedural

  @doc "Returns the explicit Iconvex octet serialization contract."
  def serialization,
    do: %{alphabet: :ascii_dot_hyphen, character_separator: " ", word_token: "/"}

  @doc "Returns the pinned in-force ITU-R source identity."
  def source_manifest, do: @source_manifest

  @impl true
  def decode(input) when is_binary(input) do
    case input do
      <<>> -> {:ok, []}
      _ -> decode_tokens(input, 0, [])
    end
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    decoded =
      input
      |> :binary.split(" ", [:global, :trim_all])
      |> Enum.reduce([], fn token, acc ->
        case decoded_token(token) do
          {:ok, codepoint} -> [codepoint | acc]
          :error -> acc
        end
      end)
      |> :lists.reverse()

    {:ok, decoded}
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_tokens(codepoints, [], false)

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_tokens(codepoints, [], true)

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        case encode(codepoints) do
          {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
          result -> result
        end

      {:incomplete, converted, rest} ->
        utf8_error(converted, :incomplete_sequence, input, rest)

      {:error, converted, rest} ->
        utf8_error(converted, :invalid_sequence, input, rest)
    end
  end

  defp decode_tokens(input, offset, acc) do
    case :binary.match(input, " ") do
      :nomatch ->
        decode_last(input, offset, acc)

      {0, 1} ->
        {:error, :invalid_sequence, offset, " "}

      {size, 1} ->
        token = binary_part(input, 0, size)
        rest_size = byte_size(input) - size - 1
        rest = binary_part(input, size + 1, rest_size)

        case decoded_token(token) do
          {:ok, _codepoint} when rest == <<>> ->
            {:error, :invalid_sequence, offset + size, " "}

          {:ok, codepoint} ->
            decode_tokens(rest, offset + size + 1, [codepoint | acc])

          :error ->
            {:error, :invalid_sequence, offset, token}
        end
    end
  end

  defp decode_last(token, offset, acc) do
    case decoded_token(token) do
      {:ok, codepoint} -> {:ok, :lists.reverse([codepoint | acc])}
      :error -> {:error, :invalid_sequence, offset, token}
    end
  end

  defp decoded_token("/"), do: {:ok, ?\s}

  defp decoded_token(token) do
    case @decode do
      %{^token => codepoint} -> {:ok, codepoint}
      _ -> :error
    end
  end

  defp encode_tokens([], acc, _discard?) do
    {:ok, acc |> :lists.reverse() |> Enum.intersperse(" ") |> IO.iodata_to_binary()}
  end

  defp encode_tokens([codepoint | rest], acc, discard?) do
    case encoded_token(codepoint) do
      {:ok, token} -> encode_tokens(rest, [token | acc], discard?)
      :error when discard? -> encode_tokens(rest, acc, true)
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encoded_token(?\s), do: {:ok, "/"}

  defp encoded_token(codepoint) do
    canonical = Map.get(@lowercase, codepoint, codepoint)

    case @table do
      %{^canonical => signal} -> {:ok, signal}
      _ -> :error
    end
  end

  defp utf8_error(converted, kind, input, rest) do
    case encode(converted) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _prefix} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
    end
  end
end
