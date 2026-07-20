defmodule Iconvex.Specs.TeXMathEncodings do
  @moduledoc false

  @source_dir Path.expand(
                "../../../priv/sources/tex-live-oml-oms-2026",
                __DIR__
              )
  @oml_path Path.join(@source_dir, "oml_tounicode.csv")
  @oms_path Path.join(@source_dir, "oms_tounicode.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @oml_path
  @external_resource @oms_path
  @external_resource @metadata_path

  @source_commit "7c8574ae28a5b257f7b92cc1e5e317255644e40d"
  @source_artifact_sha256 "e49bef156ccaf6f6e3616103a5ff6b0363aedb33ad06623fe63f6ccc41e2b72e"
  @table_sha256 %{
    oml_cmmi10: "dba7cd27dcc30d1d2a6f455bc0a0e9ddb6f75bed6b6ff67e16486a728d6c1852",
    oms_cmsy10: "45659590cd5bdda7b353979362601bfb70e8980522e78a3e13eb0e3476c477ef"
  }
  @chunk_units 4_096

  source_paths = %{oml_cmmi10: @oml_path, oms_cmsy10: @oms_path}

  parsed_tables =
    Map.new(source_paths, fn {profile, path} ->
      actual_digest =
        path
        |> File.read!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      unless actual_digest == Map.fetch!(@table_sha256, profile) do
        raise "TeX math source table digest does not match its reviewed transcription: #{path}"
      end

      ["byte_hex,unicode_hex" | rows] =
        path
        |> File.read!()
        |> String.split("\n", trim: true)

      parsed =
        Enum.map(rows, fn row ->
          [byte, codepoint] = String.split(row, ",")
          {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
        end)

      bytes = Enum.map(parsed, &elem(&1, 0))
      codepoints = Enum.map(parsed, &elem(&1, 1))

      unless bytes == Enum.to_list(0x00..0x7F) and
               length(Enum.uniq(codepoints)) == 128 and
               Enum.all?(codepoints, &(&1 in 0..0x10FFFF)) do
        raise "TeX math source table is not a complete bijective seven-bit mapping: #{path}"
      end

      {profile, codepoints}
    end)

  @decode_tables Map.new(parsed_tables, fn {profile, codepoints} ->
                   table = (codepoints ++ List.duplicate(:invalid, 128)) |> List.to_tuple()
                   {profile, table}
                 end)

  @decode_utf8_tables Map.new(parsed_tables, fn {profile, codepoints} ->
                        fragments =
                          Enum.map(codepoints, fn
                            codepoint when codepoint < 0x80 -> codepoint
                            codepoint -> <<codepoint::utf8>>
                          end)

                        table = (fragments ++ List.duplicate(:invalid, 128)) |> List.to_tuple()
                        {profile, table}
                      end)

  @encoders Map.new(parsed_tables, fn {profile, codepoints} ->
              encoder =
                codepoints
                |> Enum.with_index()
                |> Map.new(fn {codepoint, byte} -> {codepoint, byte} end)

              {profile, encoder}
            end)

  def source_commit, do: @source_commit
  def source_artifact_sha256, do: @source_artifact_sha256
  def table_sha256(profile), do: Map.fetch!(@table_sha256, profile)

  def source_artifact_url do
    "https://raw.githubusercontent.com/latex3/latex2e/#{@source_commit}/required/latex-lab/testfiles-math/mathcapture-tag-001.tpf"
  end

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, table(profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, table(profile), [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_all(codepoints, encoder(profile), [])

  def encode_discard(codepoints, profile) when is_list(codepoints),
    do: encode_discard_all(codepoints, encoder(profile), [])

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, encoder(profile), replacer, [])

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, _final?, policy) when is_list(codepoints) do
    result =
      case policy do
        :error -> encode(codepoints, profile)
        :discard -> encode_discard(codepoints, profile)
        {:replace, replacer} -> encode_substitute(codepoints, profile, replacer)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, utf8_table(profile), 0, [], 0, [])

  def encode_from_utf8(input, profile) when is_binary(input) do
    encoder = encoder(profile)

    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_all(codepoints, encoder, [])

      {kind, converted, rest} when kind in [:error, :incomplete] ->
        case encode_all(converted, encoder, []) do
          {:ok, _prefix} ->
            reason = if kind == :error, do: :invalid_sequence, else: :incomplete_sequence
            {:decode_error, reason, byte_size(input) - byte_size(rest), rest}

          encode_error ->
            encode_error
        end
    end
  end

  defp table(profile), do: Map.fetch!(@decode_tables, profile)
  defp utf8_table(profile), do: Map.fetch!(@decode_utf8_tables, profile)
  defp encoder(profile), do: Map.fetch!(@encoders, profile)

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<unit, rest::binary>>, table, offset, acc) do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_all(rest, table, offset + 1, [codepoint | acc])

      :invalid ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, acc) do
    case elem(table, unit) do
      codepoint when is_integer(codepoint) ->
        decode_discard_all(rest, table, [codepoint | acc])

      :invalid ->
        decode_discard_all(rest, table, acc)
    end
  end

  defp encode_all([], _encoder, acc), do: {:ok, reverse_binary(acc)}

  defp encode_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_all(rest, encoder, [unit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _encoder, acc), do: {:ok, reverse_binary(acc)}

  defp encode_discard_all([codepoint | rest], encoder, acc) do
    case encoder do
      %{^codepoint => unit} -> encode_discard_all(rest, encoder, [unit | acc])
      _ -> encode_discard_all(rest, encoder, acc)
    end
  end

  defp encode_substitute_all([], _encoder, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([codepoint | rest], encoder, replacer, acc) do
    case encoder do
      %{^codepoint => unit} ->
        encode_substitute_all(rest, encoder, replacer, [unit | acc])

      _ ->
        case encode_all(replacer.(codepoint), encoder, []) do
          {:ok, replacement} ->
            encode_substitute_all(rest, encoder, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp decode_utf8_all(<<>>, _utf8_table, _offset, acc, _count, chunks),
    do: {:ok, finish_iodata(acc, chunks)}

  defp decode_utf8_all(<<unit, rest::binary>>, utf8_table, offset, acc, count, chunks) do
    case elem(utf8_table, unit) do
      fragment when is_integer(fragment) or is_binary(fragment) ->
        {next_acc, next_count, next_chunks} = push_fragment(fragment, acc, count, chunks)
        decode_utf8_all(rest, utf8_table, offset + 1, next_acc, next_count, next_chunks)

      :invalid ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp push_fragment(fragment, acc, count, chunks) when count == @chunk_units - 1 do
    chunk = [fragment | acc] |> :lists.reverse() |> IO.iodata_to_binary()
    {[], 0, [chunk | chunks]}
  end

  defp push_fragment(fragment, acc, count, chunks),
    do: {[fragment | acc], count + 1, chunks}

  defp reverse_binary(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()

  defp finish_iodata([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_iodata(acc, chunks) do
    chunk = acc |> :lists.reverse() |> IO.iodata_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end
end

defmodule Iconvex.Specs.TeXMathEncoding.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.TeXMathEncodings, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      def profile, do: unquote(profile)
      def unit_bits, do: 7
      def source_commit, do: Engine.source_commit()
      def source_artifact_sha256, do: Engine.source_artifact_sha256()
      def source_artifact_url, do: Engine.source_artifact_url()
      def table_sha256, do: Engine.table_sha256(unquote(profile))

      @impl true
      def decode(input), do: Engine.decode(input, unquote(profile))

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, unquote(profile))

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, unquote(profile))

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, unquote(profile))

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Engine.encode_substitute(codepoints, unquote(profile), replacer)

      @impl true
      def decode_chunk(input, final?), do: Engine.decode_chunk(input, unquote(profile), final?)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: Engine.encode_chunk(codepoints, unquote(profile), final?, policy)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, unquote(profile))

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, unquote(profile))
    end
  end
end

defmodule Iconvex.Specs.TeXLiveOMLCMMI10ToUnicode2026 do
  @moduledoc """
  Semantic seven-bit OML mapping for the Computer Modern `cmmi10` exemplar.

  Each code position is transported in one octet. Only `0x00..0x7F` is valid;
  use the separate packed transport API when contiguous septets are required.
  The mapping is byte-roundtrip lossless but does not preserve font styling.
  """

  use Iconvex.Specs.TeXMathEncoding.Profile,
    profile: :oml_cmmi10,
    canonical: "TEX-LIVE-OML-CMMI10-TOUNICODE-2026",
    aliases: ["OML", "OML-ENCODING", "TEX-MATH-ITALIC"],
    codec_id: :tex_live_oml_cmmi10_tounicode_2026
end

defmodule Iconvex.Specs.TeXLiveOMSCMSY10ToUnicode2026 do
  @moduledoc """
  Semantic seven-bit OMS mapping for the Computer Modern `cmsy10` exemplar.

  Each code position is transported in one octet. Only `0x00..0x7F` is valid;
  use the separate packed transport API when contiguous septets are required.
  The mapping is byte-roundtrip lossless but does not preserve font styling.
  """

  use Iconvex.Specs.TeXMathEncoding.Profile,
    profile: :oms_cmsy10,
    canonical: "TEX-LIVE-OMS-CMSY10-TOUNICODE-2026",
    aliases: ["OMS", "OMS-ENCODING", "TEX-MATH-SYMBOLS"],
    codec_id: :tex_live_oms_cmsy10_tounicode_2026
end
