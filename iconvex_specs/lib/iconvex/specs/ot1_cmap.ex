defmodule Iconvex.Specs.OT1CMap.SourceAsset do
  @moduledoc false

  @range ~r/\A<([0-9A-F]{2})> <([0-9A-F]{2})> <([0-9A-F]{4})>\z/
  @character ~r/\A<([0-9A-F]{2})> <([0-9A-F]{4}(?:[0-9A-F]{4}){0,2})>\z/

  def validate!(source, metadata, options)
      when is_binary(source) and is_binary(metadata) and is_list(options) do
    expected_sha256 = Keyword.fetch!(options, :sha256)
    metadata_sha256 = Keyword.fetch!(options, :metadata_sha256)
    cmap_name = Keyword.fetch!(options, :cmap_name)
    expected_keys = Keyword.fetch!(options, :expected_keys)

    verify_sha!("CMap", source, expected_sha256)
    verify_sha!("metadata", metadata, metadata_sha256)
    validate_headers!(source, cmap_name)
    validate_metadata!(metadata)

    mappings =
      source
      |> String.split("\n", trim: true)
      |> Enum.reduce(%{}, &parse_line!/2)

    unless mappings |> Map.keys() |> Enum.sort() == expected_keys do
      raise ArgumentError,
            "#{cmap_name} source positions differ from the exact reviewed code space"
    end

    0..255
    |> Enum.map(&Map.get(mappings, &1, :undefined))
    |> List.to_tuple()
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError, "OT1 #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_headers!(source, cmap_name) do
    required = [
      "%!PS-Adobe-3.0 Resource-CMap",
      "%%Version: 1.000",
      "/CMapName /#{cmap_name} def",
      "<00> <7F>",
      "%%EOF\n"
    ]

    unless Enum.all?(required, &String.contains?(source, &1)) do
      raise ArgumentError, "#{cmap_name} omits an exact version or code-space header"
    end
  end

  defp validate_metadata!(metadata) do
    required = [
      "LGPL-2.1-or-later",
      "LPPL-1.3c-or-later",
      "OT1 normal and typewriter mappings are distinct",
      "GNU libiconv does not expose these source-qualified profiles"
    ]

    unless Enum.all?(required, &String.contains?(metadata, &1)) do
      raise ArgumentError, "OT1 metadata omits a required provenance or profile boundary"
    end
  end

  defp parse_line!(line, mappings) do
    case Regex.run(@range, line, capture: :all_but_first) do
      [first, last, destination] ->
        first = String.to_integer(first, 16)
        last = String.to_integer(last, 16)
        destination = String.to_integer(destination, 16)

        Enum.reduce(first..last, mappings, fn byte, acc ->
          put_unique!(acc, byte, [destination + byte - first])
        end)

      nil ->
        parse_character_line!(line, mappings)
    end
  end

  defp parse_character_line!(line, mappings) do
    case Regex.run(@character, line, capture: :all_but_first) do
      [source, destination] ->
        codepoints =
          for <<unit::binary-size(4) <- destination>> do
            String.to_integer(unit, 16)
          end

        unless Enum.all?(codepoints, &unicode_scalar?/1) do
          raise ArgumentError, "OT1 CMap contains a non-scalar Unicode destination"
        end

        put_unique!(mappings, String.to_integer(source, 16), codepoints)

      nil ->
        mappings
    end
  end

  defp put_unique!(mappings, byte, codepoints) do
    if Map.has_key?(mappings, byte) do
      raise ArgumentError, "OT1 CMap repeats source byte #{Base.encode16(<<byte>>)}"
    end

    unless byte in 0..127 and Enum.all?(codepoints, &unicode_scalar?/1) do
      raise ArgumentError, "OT1 CMap contains a value outside its seven-bit scalar contract"
    end

    Map.put(mappings, byte, codepoints)
  end

  defp unicode_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end

defmodule Iconvex.Specs.OT1CMap do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/ot1-cmap-1.0j", __DIR__)
  @ot1_path Path.join(@source_dir, "ot1.cmap")
  @ot1tt_path Path.join(@source_dir, "ot1tt.cmap")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @ot1_path
  @external_resource @ot1tt_path
  @external_resource @metadata_path

  @ot1_sha256 "2c7325ed9ad97da701f43737f0762c181878b8d770b5abf37df8728216f9e646"
  @ot1tt_sha256 "58b4f178ac815587ccf5165cd3cc13816000f1338b05706717bdbc8345d75af3"
  @metadata_sha256 "a6a5f2a62a4427348fb054fc0360406d6a24dea0ecc9943b019a2c681aeb3239"
  @archive_sha256 "b5fffa016ac4571f0405592ac40bf231f9ddb6b1ce3100d17a33833284bbeb84"
  @latex_sha256 "61cc867257831d2611e2d96ead2a1882f03e4da27c095b642cc866984aac0bc2"

  @metadata File.read!(@metadata_path)
  @tables %{
    ot1:
      Iconvex.Specs.OT1CMap.SourceAsset.validate!(File.read!(@ot1_path), @metadata,
        sha256: @ot1_sha256,
        metadata_sha256: @metadata_sha256,
        cmap_name: "TeX-OT1-0",
        expected_keys: Enum.to_list(0..127) -- [0x20]
      ),
    ot1tt:
      Iconvex.Specs.OT1CMap.SourceAsset.validate!(File.read!(@ot1tt_path), @metadata,
        sha256: @ot1tt_sha256,
        metadata_sha256: @metadata_sha256,
        cmap_name: "TeX-OT1TT-0",
        expected_keys: Enum.to_list(0..127)
      )
  }

  @utf8_tables Map.new(@tables, fn {profile, table} ->
                 utf8 =
                   table
                   |> Tuple.to_list()
                   |> Enum.map(fn
                     :undefined -> :undefined
                     codepoints -> List.to_string(codepoints)
                   end)
                   |> List.to_tuple()

                 {profile, utf8}
               end)

  @single_encoders Map.new(@tables, fn {profile, table} ->
                     encoder =
                       table
                       |> Tuple.to_list()
                       |> Enum.with_index()
                       |> Enum.reduce(%{}, fn
                         {[codepoint], byte}, acc -> Map.put_new(acc, codepoint, byte)
                         {_sequence_or_undefined, _byte}, acc -> acc
                       end)

                     {profile, encoder}
                   end)

  def ot1_sha256, do: @ot1_sha256
  def ot1tt_sha256, do: @ot1tt_sha256
  def metadata_sha256, do: @metadata_sha256
  def archive_sha256, do: @archive_sha256
  def latex_sha256, do: @latex_sha256
  def source_url, do: "https://tug.ctan.org/macros/latex/contrib/cmap.zip"

  def decode(input, profile) when is_binary(input),
    do: decode_all(input, table(profile), 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: decode_discard_all(input, table(profile), [])

  def decode_chunk(input, profile, _final?) when is_binary(input) do
    case decode(input, profile) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_all(input, utf8_table(profile), 0, [])

  def encode(codepoints, profile) when is_list(codepoints) do
    case encode_all(codepoints, profile, true, :error, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    case encode_all(codepoints, profile, true, :discard, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_all(codepoints, profile, true, {:replace, replacer}, []) do
      {:ok, output, []} -> {:ok, output}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, final?, policy)
      when is_list(codepoints) and is_boolean(final?),
      do: encode_all(codepoints, profile, final?, policy, [])

  def encode_from_utf8(input, profile) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, profile)

      {:incomplete, converted, rest} ->
        first_source_error(converted, profile, :incomplete_sequence, input, rest)

      {:error, converted, rest} ->
        first_source_error(converted, profile, :invalid_sequence, input, rest)
    end
  end

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp utf8_table(profile), do: Map.fetch!(@utf8_tables, profile)
  defp single_encoder(profile), do: Map.fetch!(@single_encoders, profile)

  defp decode_all(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<byte, rest::binary>>, table, offset, acc) do
    case elem(table, byte) do
      :undefined ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoints ->
        decode_all(rest, table, offset + 1, :lists.reverse(codepoints, acc))
    end
  end

  defp decode_discard_all(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<byte, rest::binary>>, table, acc) do
    case elem(table, byte) do
      :undefined -> decode_discard_all(rest, table, acc)
      codepoints -> decode_discard_all(rest, table, :lists.reverse(codepoints, acc))
    end
  end

  defp decode_utf8_all(<<>>, _table, _offset, acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary() |> then(&{:ok, &1})

  defp decode_utf8_all(<<byte, rest::binary>>, table, offset, acc) do
    case elem(table, byte) do
      :undefined -> {:error, :invalid_sequence, offset, <<byte>>}
      piece -> decode_utf8_all(rest, table, offset + 1, [piece | acc])
    end
  end

  defp encode_all(codepoints, profile, final?, policy, acc) do
    case next_token(codepoints, profile, final?) do
      :done ->
        {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), []}

      {:pending, pending} ->
        {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), pending}

      {:mapped, byte, rest} ->
        encode_all(rest, profile, final?, policy, [byte | acc])

      {:single, codepoint, rest} ->
        case single_encoder(profile) do
          %{^codepoint => byte} ->
            encode_all(rest, profile, final?, policy, [byte | acc])

          _ ->
            encode_unrepresentable(codepoint, rest, profile, final?, policy, acc)
        end
    end
  end

  defp next_token([], _profile, _final?), do: :done
  defp next_token([?f, ?f, ?i | rest], :ot1, _final?), do: {:mapped, 0x0E, rest}
  defp next_token([?f, ?f, ?l | rest], :ot1, _final?), do: {:mapped, 0x0F, rest}
  defp next_token([?f, ?f], :ot1, false), do: {:pending, ~c"ff"}
  defp next_token([?f, ?f | rest], :ot1, _final?), do: {:mapped, 0x0B, rest}
  defp next_token([?f, ?i | rest], :ot1, _final?), do: {:mapped, 0x0C, rest}
  defp next_token([?f, ?l | rest], :ot1, _final?), do: {:mapped, 0x0D, rest}
  defp next_token([?f], :ot1, false), do: {:pending, ~c"f"}
  defp next_token([codepoint | rest], _profile, _final?), do: {:single, codepoint, rest}

  defp encode_unrepresentable(
         codepoint,
         _rest,
         _profile,
         _final?,
         :error,
         _acc
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_unrepresentable(
         _codepoint,
         rest,
         profile,
         final?,
         :discard,
         acc
       ),
       do: encode_all(rest, profile, final?, :discard, acc)

  defp encode_unrepresentable(
         codepoint,
         rest,
         profile,
         final?,
         {:replace, replacer} = policy,
         acc
       )
       when is_function(replacer, 1) do
    case encode(replacer.(codepoint), profile) do
      {:ok, replacement} ->
        encode_all(rest, profile, final?, policy, [replacement | acc])

      error ->
        error
    end
  end

  defp first_source_error(converted, profile, kind, input, rest) do
    case encode(converted, profile) do
      {:ok, _prefix} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
      error -> error
    end
  end
end

defmodule Iconvex.Specs.OT1CMap.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    alias_name = Keyword.fetch!(options, :alias)
    codec_id = Keyword.fetch!(options, :codec_id)
    mapping_function = if(profile == :ot1, do: :ot1_sha256, else: :ot1tt_sha256)

    quote bind_quoted: [
            profile: profile,
            canonical: canonical,
            alias_name: alias_name,
            codec_id: codec_id,
            mapping_function: mapping_function
          ] do
      use Iconvex.Codec
      alias Iconvex.Specs.OT1CMap, as: Engine

      @profile profile
      @canonical canonical
      @alias_name alias_name
      @codec_id codec_id
      @mapping_function mapping_function

      @impl true
      def canonical_name, do: @canonical

      @impl true
      def aliases, do: [@alias_name]

      @impl true
      def codec_id, do: @codec_id

      def unit_bits, do: 8
      def mapping_sha256, do: apply(Engine, @mapping_function, [])
      def metadata_sha256, do: Engine.metadata_sha256()
      def archive_sha256, do: Engine.archive_sha256()
      def latex_sha256, do: Engine.latex_sha256()
      def source_url, do: Engine.source_url()

      @impl true
      def decode(input), do: Engine.decode(input, @profile)

      @impl true
      def decode_discard(input), do: Engine.decode_discard(input, @profile)

      @impl true
      def decode_chunk(input, final?), do: Engine.decode_chunk(input, @profile, final?)

      @impl true
      def decode_to_utf8(input), do: Engine.decode_to_utf8(input, @profile)

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, @profile)

      @impl true
      def encode_discard(codepoints), do: Engine.encode_discard(codepoints, @profile)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: Engine.encode_substitute(codepoints, @profile, replacer)

      @impl true
      def encode_chunk(codepoints, final?, policy),
        do: Engine.encode_chunk(codepoints, @profile, final?, policy)

      @impl true
      def encode_from_utf8(input), do: Engine.encode_from_utf8(input, @profile)
    end
  end
end

defmodule Iconvex.Specs.OT1CMap10J do
  @moduledoc """
  Source-qualified Unicode extraction profile from CTAN `cmap` 1.0j's
  `TeX-OT1-0` table. Byte `0x20` is undefined exactly as in that CMap.
  """

  use Iconvex.Specs.OT1CMap.Profile,
    profile: :ot1,
    canonical: "TEX-OT1-CMAP-1.0J",
    alias: "TEX-OT1-0-CMAP-1.0J",
    codec_id: :tex_ot1_cmap_1_0j
end

defmodule Iconvex.Specs.OT1TTCMap10J do
  @moduledoc """
  Source-qualified Unicode extraction profile from CTAN `cmap` 1.0j's
  distinct monospaced-font `TeX-OT1TT-0` table.
  """

  use Iconvex.Specs.OT1CMap.Profile,
    profile: :ot1tt,
    canonical: "TEX-OT1TT-CMAP-1.0J",
    alias: "TEX-OT1TT-0-CMAP-1.0J",
    codec_id: :tex_ot1tt_cmap_1_0j
end
