defmodule Iconvex.Specs.Tools.ICUSBCSDifferential do
  @moduledoc false

  def run do
    root = Path.expand("..", __DIR__)

    oracle =
      System.get_env("ICU_UCM_ORACLE") || Path.join(System.tmp_dir!(), "iconvex_icu_ucm_oracle")

    unless File.exists?(oracle) do
      raise "compile tools/icu_ucm_oracle.c and set ICU_UCM_ORACLE to its path"
    end

    {cases, digest} =
      Iconvex.Specs.ICUUCM.encodings()
      |> Enum.zip(Iconvex.Specs.ICUUCM.codecs())
      |> Enum.reduce({0, :crypto.hash_init(:sha256)}, fn {entry, codec}, {count, digest} ->
        table =
          root
          |> Path.join("priv/tables/#{entry.id}.etf")
          |> File.read!()
          |> :erlang.binary_to_term()

        requests = requests(table)
        path = Path.join(System.tmp_dir!(), "iconvex-icu-#{entry.index}.requests")
        File.write!(path, Enum.map_join(requests, "\n", &request_line/1) <> "\n")

        {output, 0} = System.cmd(oracle, [entry.name, path], stderr_to_stdout: true)
        File.rm!(path)
        results = String.split(output, "\n", trim: true)

        unless length(results) == length(requests),
          do: raise("#{entry.name}: oracle returned the wrong result count")

        Enum.zip(requests, results)
        |> Enum.each(fn {request, result} -> compare!(codec, entry.name, request, result) end)

        digest =
          digest
          |> :crypto.hash_update(entry.name)
          |> :crypto.hash_update(<<0>>)
          |> :crypto.hash_update(output)

        IO.puts("#{entry.name}: #{length(requests)} ICU cases")
        {count + length(requests), digest}
      end)

    digest = digest |> :crypto.hash_final() |> Base.encode16(case: :lower)
    IO.puts("ICU 78.3 SBCS differential: #{cases} cases, SHA-256 #{digest}")
  end

  defp requests(table) do
    decodes = Enum.map(0..255, &{:decode, &1})
    encodes = table.encode |> Map.keys() |> Enum.sort() |> Enum.map(&{:encode, &1})
    decodes ++ encodes
  end

  defp request_line({:decode, byte}), do: "D #{hex(byte, 2)}"

  defp request_line({:encode, codepoints}),
    do: "E " <> (codepoints |> Tuple.to_list() |> Enum.map_join(",", &hex(&1, 1)))

  defp compare!(codec, name, {:decode, byte}, "ERR") do
    unless match?({:error, :invalid_sequence, 0, _}, codec.decode(<<byte>>)),
      do: raise("#{name}: decode #{hex(byte, 2)} differs from ICU")
  end

  defp compare!(codec, name, {:decode, byte}, "OK " <> codepoints) do
    expected =
      if codepoints == "" do
        []
      else
        codepoints |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))
      end

    unless codec.decode(<<byte>>) == {:ok, expected},
      do: raise("#{name}: decode #{hex(byte, 2)} differs from ICU")
  end

  defp compare!(codec, name, {:encode, codepoints}, "OK " <> bytes) do
    expected = bytes |> Base.decode16!(case: :mixed)

    unless codec.encode(Tuple.to_list(codepoints)) == {:ok, expected},
      do: raise("#{name}: encode #{inspect(codepoints)} differs from ICU")
  end

  defp compare!(_codec, name, request, result),
    do: raise("#{name}: unexpected ICU result #{inspect(result)} for #{inspect(request)}")

  defp hex(integer, width),
    do: integer |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(width, "0")
end

Iconvex.Specs.Tools.ICUSBCSDifferential.run()
