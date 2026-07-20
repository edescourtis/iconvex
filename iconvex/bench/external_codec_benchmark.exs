Mix.Task.run("app.start")

defmodule Iconvex.ExternalBenchmark.ASCII do
  def decode(input), do: decode(input, 0, [])
  def decode_discard(input), do: {:ok, for(<<byte <- input>>, byte < 0x80, do: byte)}
  def encode(codepoints), do: encode(codepoints, [])

  def encode_discard(codepoints) do
    output = codepoints |> Enum.filter(&(&1 < 0x80)) |> :erlang.list_to_binary()
    {:ok, output}
  end

  def encode_substitute(codepoints, replacer), do: encode_substitute(codepoints, replacer, [])

  defp decode(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode(<<byte, rest::binary>>, offset, acc) when byte < 0x80,
    do: decode(rest, offset + 1, [byte | acc])

  defp decode(<<byte, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp encode([], acc), do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}
  defp encode([codepoint | rest], acc) when codepoint < 0x80, do: encode(rest, [codepoint | acc])

  defp encode([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute([codepoint | rest], replacer, acc) when codepoint < 0x80,
    do: encode_substitute(rest, replacer, [<<codepoint>> | acc])

  defp encode_substitute([codepoint | rest], replacer, acc) do
    case encode(replacer.(codepoint)) do
      {:ok, replacement} -> encode_substitute(rest, replacer, [replacement | acc])
      error -> error
    end
  end
end

defmodule Iconvex.ExternalBenchmark.GenericASCII do
  use Iconvex.Codec
  alias Iconvex.ExternalBenchmark.ASCII

  @impl true
  def canonical_name, do: "X-BENCH-ASCII-GENERIC"

  @impl true
  def decode(input), do: ASCII.decode(input)

  @impl true
  def decode_discard(input), do: ASCII.decode_discard(input)

  @impl true
  def encode(codepoints), do: ASCII.encode(codepoints)

  @impl true
  def encode_discard(codepoints), do: ASCII.encode_discard(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer), do: ASCII.encode_substitute(codepoints, replacer)
end

defmodule Iconvex.ExternalBenchmark.FastASCII do
  use Iconvex.Codec
  alias Iconvex.ExternalBenchmark.ASCII

  @non_ascii Enum.map(0x80..0xFF, &<<&1>>)

  @impl true
  def canonical_name, do: "X-BENCH-ASCII-FAST"

  @impl true
  def decode(input), do: ASCII.decode(input)

  @impl true
  def decode_discard(input), do: ASCII.decode_discard(input)

  @impl true
  def encode(codepoints), do: ASCII.encode(codepoints)

  @impl true
  def encode_discard(codepoints), do: ASCII.encode_discard(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer), do: ASCII.encode_substitute(codepoints, replacer)

  @impl true
  def decode_to_utf8(input) do
    case :binary.match(input, @non_ascii) do
      :nomatch -> {:ok, input}
      {offset, 1} -> {:error, :invalid_sequence, offset, binary_part(input, offset, 1)}
    end
  end

  @impl true
  def encode_from_utf8(input) do
    case :binary.match(input, @non_ascii) do
      :nomatch ->
        {:ok, input}

      {_offset, 1} ->
        case :unicode.characters_to_list(input, :utf8) do
          codepoints when is_list(codepoints) ->
            {:error, :unrepresentable_character, Enum.find(codepoints, &(&1 > 0x7F))}

          {:error, _converted, rest} ->
            {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}

          {:incomplete, _converted, rest} ->
            {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}
        end
    end
  end
end

defmodule Iconvex.ExternalBenchmark do
  @iterations 12
  @warmups 3
  @lookups 1_000_000

  alias Iconvex.ExternalBenchmark.{FastASCII, GenericASCII}

  def run do
    :ok = Iconvex.register_codec(GenericASCII)
    :ok = Iconvex.register_codec(FastASCII, aliases: ["X-BENCH-ASCII"])
    input = :binary.copy("The quick brown fox jumps over the lazy dog. ", 24_000)

    IO.puts("External codec benchmark (#{@iterations} measured iterations, #{@warmups} warmups)")
    IO.puts("OTP #{System.otp_release()} / Elixir #{System.version()}")

    conversion("generic external -> UTF-8", input, fn ->
      Iconvex.convert!(input, GenericASCII, "UTF-8")
    end)

    conversion("fast external -> UTF-8", input, fn ->
      Iconvex.convert!(input, "X-BENCH-ASCII", "UTF-8")
    end)

    conversion("UTF-8 -> generic external", input, fn ->
      Iconvex.convert!(input, "UTF-8", GenericASCII)
    end)

    conversion("UTF-8 -> fast external", input, fn ->
      Iconvex.convert!(input, "UTF-8", FastASCII)
    end)

    lookup("built-in string lookup", fn -> Iconvex.canonical_name("UTF-8") end)
    lookup("external string lookup", fn -> Iconvex.canonical_name("X-BENCH-ASCII") end)
    lookup("external module lookup", fn -> Iconvex.canonical_name(FastASCII) end)
  end

  defp conversion(name, input, function) do
    Enum.each(1..@warmups, fn _ -> function.() end)

    samples =
      Enum.map(1..@iterations, fn _ ->
        {microseconds, result} = :timer.tc(function)
        true = is_binary(result)
        microseconds
      end)

    median = samples |> Enum.sort() |> Enum.at(div(@iterations, 2))
    mib_per_second = byte_size(input) / 1_048_576 / (median / 1_000_000)

    IO.puts(:io_lib.format("~-30s ~8.2f MiB/s  ~8.2f ms", [name, mib_per_second, median / 1000]))
  end

  defp lookup(name, function) do
    repeat(10_000, function)
    {microseconds, _result} = :timer.tc(fn -> repeat(@lookups, function) end)
    nanoseconds = microseconds * 1000 / @lookups
    IO.puts(:io_lib.format("~-30s ~8.1f ns/op", [name, nanoseconds]))
  end

  defp repeat(0, _function), do: :ok

  defp repeat(count, function) do
    function.()
    repeat(count - 1, function)
  end
end

Iconvex.ExternalBenchmark.run()
