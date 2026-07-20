defmodule Iconvex.Specs.Tools.ICUMultibyteDifferential do
  @moduledoc false

  def run do
    root = Path.expand("..", __DIR__)

    oracle =
      System.get_env("ICU_UCM_ORACLE") || Path.join(System.tmp_dir!(), "iconvex_icu_ucm_oracle")

    unless File.exists?(oracle) do
      raise "compile tools/icu_ucm_oracle.c and set ICU_UCM_ORACLE to its path"
    end

    {cases, digest} =
      Iconvex.Specs.ICUMultibyte.encodings()
      |> Enum.zip(Iconvex.Specs.ICUMultibyte.codecs())
      |> Enum.reduce({0, :crypto.hash_init(:sha256)}, fn {entry, codec}, {count, digest} ->
        table =
          root
          |> Path.join("priv/tables/#{entry.id}.etf")
          |> File.read!()
          |> :erlang.binary_to_term()

        requests = requests(table)
        path = Path.join(System.tmp_dir!(), "iconvex-icu-multibyte-#{entry.index}.requests")
        File.write!(path, Enum.map_join(requests, "\n", &request_line/1) <> "\n")

        {output, status} = System.cmd(oracle, [entry.name, path], stderr_to_stdout: true)
        File.rm!(path)

        if status == 3 do
          IO.puts("#{entry.name}: source-only mapping (not built into this ICU runtime)")
          {count, :crypto.hash_update(digest, entry.name <> <<0, 0>>)}
        else
          unless status == 0, do: raise("#{entry.name}: ICU oracle failed: #{output}")
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
        end
      end)

    digest = digest |> :crypto.hash_final() |> Base.encode16(case: :lower)
    IO.puts("ICU 78.3 multibyte differential: #{cases} cases, SHA-256 #{digest}")
  end

  defp requests(table) do
    one =
      table.one
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.reject(fn {mapping, _byte} -> is_nil(mapping) end)
      |> Enum.map(fn {_mapping, byte} -> {:decode, <<byte>>} end)

    many = table.many |> Map.keys() |> Enum.sort() |> Enum.map(&{:decode, &1})
    encodes = table.encode |> Map.keys() |> Enum.sort() |> Enum.map(&{:encode, &1})
    one ++ many ++ encodes
  end

  defp request_line({:decode, bytes}), do: "D " <> Base.encode16(bytes)

  defp request_line({:encode, codepoints}),
    do: "E " <> (codepoints |> Tuple.to_list() |> Enum.map_join(",", &hex/1))

  defp compare!(codec, name, {:decode, bytes}, "OK " <> codepoints) do
    expected = codepoints |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))

    unless codec.decode(bytes) == {:ok, expected},
      do: raise("#{name}: decode #{Base.encode16(bytes)} differs from ICU")
  end

  defp compare!(codec, name, {:encode, codepoints}, "OK " <> bytes) do
    expected = Base.decode16!(bytes, case: :mixed)

    unless codec.encode(Tuple.to_list(codepoints)) == {:ok, expected},
      do: raise("#{name}: encode #{inspect(codepoints)} differs from ICU")
  end

  defp compare!(_codec, name, request, result),
    do: raise("#{name}: unexpected ICU result #{inspect(result)} for #{inspect(request)}")

  defp hex(integer), do: integer |> Integer.to_string(16) |> String.upcase()
end

Iconvex.Specs.Tools.ICUMultibyteDifferential.run()
