defmodule Iconvex.Specs.VietUnicodeVNI.Engine do
  @moduledoc false

  def decode(input, profile) when is_binary(input),
    do: decode_loop(input, profile, true, 0, [])

  def decode_chunk(input, profile, final?) when is_binary(input) and is_boolean(final?),
    do: decode_loop(input, profile, final?, 0, [])

  def decode_discard(input, profile) when is_binary(input),
    do: {:ok, input |> decode_discard_loop(profile, []) |> :lists.reverse()}

  def decode_to_utf8(input, profile) when is_binary(input),
    do: decode_utf8_loop(input, profile, 0, [])

  def encode(codepoints, profile) when is_list(codepoints),
    do: encode_loop(codepoints, profile.encode, [])

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    {:ok,
     codepoints
     |> encode_discard_loop(profile.encode, [])
     |> :lists.reverse()
     |> IO.iodata_to_binary()}
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_loop(codepoints, profile.encode, replacer, [])

  def encode_from_utf8(input, profile) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, profile)

      {:incomplete, converted, rest} ->
        utf8_error_after_prefix(
          converted,
          profile,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        utf8_error_after_prefix(
          converted,
          profile,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  def encode_chunk(codepoints, profile, :error) when is_list(codepoints),
    do: stream_encode_result(encode(codepoints, profile))

  def encode_chunk(codepoints, profile, :discard) when is_list(codepoints),
    do: stream_encode_result(encode_discard(codepoints, profile))

  def encode_chunk(codepoints, profile, {:replace, replacer})
      when is_list(codepoints) and is_function(replacer, 1),
      do: stream_encode_result(encode_substitute(codepoints, profile, replacer))

  defp decode_loop(<<>>, _profile, _final?, _offset, result),
    do: {:ok, :lists.reverse(result), <<>>}

  defp decode_loop(input, profile, final?, offset, result) do
    case decode_one(input, profile, final?) do
      {:ok, token, codepoint, rest} ->
        decode_loop(rest, profile, final?, offset + byte_size(token), [codepoint | result])

      {:pending, pending} ->
        {:ok, :lists.reverse(result), pending}

      {:error, reason, sequence} ->
        {:error, reason, offset, sequence}
    end
  end

  defp decode_discard_loop(<<>>, _profile, result), do: result

  defp decode_discard_loop(input, profile, result) do
    case decode_one(input, profile, true) do
      {:ok, _token, codepoint, rest} ->
        decode_discard_loop(rest, profile, [codepoint | result])

      {:error, _reason, _sequence} ->
        <<_invalid, rest::binary>> = input
        decode_discard_loop(rest, profile, result)
    end
  end

  defp decode_utf8_loop(<<>>, _profile, _offset, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_utf8_loop(input, profile, offset, result) do
    case decode_one(input, profile, true) do
      {:ok, token, _codepoint, rest} ->
        decode_utf8_loop(
          rest,
          profile,
          offset + byte_size(token),
          [Map.fetch!(profile.decode_utf8, token) | result]
        )

      {:error, reason, sequence} ->
        {:error, reason, offset, sequence}
    end
  end

  defp decode_one(input, profile, false) do
    if byte_size(input) < profile.max_token_bytes and Map.has_key?(profile.prefixes, input) do
      {:pending, input}
    else
      decode_complete_one(input, profile)
    end
  end

  defp decode_one(input, profile, true), do: decode_complete_one(input, profile)

  defp decode_complete_one(input, profile) do
    case longest_token(input, profile.decode, profile.max_token_bytes) do
      nil ->
        if Map.has_key?(profile.prefixes, input) do
          {:error, :incomplete_sequence, input}
        else
          <<invalid, _::binary>> = input
          {:error, :invalid_sequence, <<invalid>>}
        end

      token ->
        size = byte_size(token)
        <<_token::binary-size(size), rest::binary>> = input
        {:ok, token, Map.fetch!(profile.decode, token), rest}
    end
  end

  defp longest_token(input, decode, max_token_bytes),
    do: longest_token(input, decode, min(byte_size(input), max_token_bytes), nil)

  defp longest_token(_input, _decode, 0, result), do: result

  defp longest_token(input, decode, size, nil) do
    token = binary_part(input, 0, size)

    if Map.has_key?(decode, token),
      do: token,
      else: longest_token(input, decode, size - 1, nil)
  end

  defp encode_loop([], _encode, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop([codepoint | rest], encode, result) do
    case Map.fetch(encode, codepoint) do
      {:ok, token} -> encode_loop(rest, encode, [token | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_loop([], _encode, result), do: result

  defp encode_discard_loop([codepoint | rest], encode, result) do
    case Map.fetch(encode, codepoint) do
      {:ok, token} -> encode_discard_loop(rest, encode, [token | result])
      :error -> encode_discard_loop(rest, encode, result)
    end
  end

  defp encode_substitute_loop([], _encode, _replacer, result),
    do: {:ok, result |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop([codepoint | rest], encode, replacer, result) do
    case Map.fetch(encode, codepoint) do
      {:ok, token} ->
        encode_substitute_loop(rest, encode, replacer, [token | result])

      :error ->
        case encode_replacement(replacer.(codepoint), encode, result) do
          {:ok, next_result} -> encode_substitute_loop(rest, encode, replacer, next_result)
          error -> error
        end
    end
  end

  defp encode_replacement([], _encode, result), do: {:ok, result}

  defp encode_replacement([codepoint | rest], encode, result) do
    case Map.fetch(encode, codepoint) do
      {:ok, token} -> encode_replacement(rest, encode, [token | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp utf8_error_after_prefix(converted, profile, reason, offset, rest) do
    case encode(converted, profile) do
      {:ok, _encoded_prefix} -> {:decode_error, reason, offset, rest}
      error -> error
    end
  end

  defp stream_encode_result({:ok, output}), do: {:ok, output, []}
  defp stream_encode_result(error), do: error
end

defmodule Iconvex.Specs.VietUnicodeVNI do
  @moduledoc """
  Source-qualified VNI profiles from the VietUnicode 2002 table snapshot.

  The source distinguishes ASCII/DOS, ANSI Win/Unix, Mac, and Internet Mail.
  No unqualified VNI name is assigned because the four serializations are not
  interchangeable. Internet Mail is decoded by longest token and is explicitly
  non-injective across some adjacent literal-ASCII token boundaries.
  """

  @mapping_path Path.expand(
                  "../../../priv/sources/vietunicode-vni-2002/vni_profiles.csv",
                  __DIR__
                )
  @metadata_path Path.expand(
                   "../../../priv/sources/vietunicode-vni-2002/SOURCE_METADATA.md",
                   __DIR__
                 )
  @source_path Path.expand("../../../priv/sources/vietunicode-vni-2002/vni.html", __DIR__)
  @source_wire_path Path.expand(
                      "../../../priv/sources/vietunicode-vni-2002/vni.html.base64",
                      __DIR__
                    )

  defmacro defcodec(module_ast, options_ast) do
    module = Macro.expand(module_ast, __CALLER__)
    {options, []} = Code.eval_quoted(options_ast, [], __CALLER__)
    definition = build_definition!(module, options)

    quote bind_quoted: [module: module, definition: Macro.escape(definition)] do
      defmodule module do
        use Iconvex.Codec

        alias Iconvex.Specs.VietUnicodeVNI.Engine

        @external_resource definition.mapping_path
        @external_resource definition.metadata_path
        @external_resource definition.source_path
        @external_resource definition.source_wire_path
        @profile definition.profile
        @canonical definition.canonical
        @aliases definition.aliases
        @codec_id definition.codec_id
        @mapping_sha256 definition.mapping_sha256
        @mapping_count definition.mapping_count
        @token_bytes definition.token_bytes
        @unit_model definition.unit_model
        @sequence_round_trip definition.sequence_round_trip
        @source_reference definition.source_reference

        @impl true
        def canonical_name, do: @canonical

        @impl true
        def aliases, do: @aliases

        @impl true
        def codec_id, do: @codec_id

        @impl true
        def decode(input) when is_binary(input) do
          case Engine.decode(input, @profile) do
            {:ok, codepoints, <<>>} -> {:ok, codepoints}
            error -> error
          end
        end

        @impl true
        def decode_discard(input) when is_binary(input),
          do: Engine.decode_discard(input, @profile)

        @impl true
        def decode_to_utf8(input) when is_binary(input),
          do: Engine.decode_to_utf8(input, @profile)

        @impl true
        def encode(codepoints) when is_list(codepoints), do: Engine.encode(codepoints, @profile)

        @impl true
        def encode_discard(codepoints) when is_list(codepoints),
          do: Engine.encode_discard(codepoints, @profile)

        @impl true
        def encode_substitute(codepoints, replacer)
            when is_list(codepoints) and is_function(replacer, 1),
            do: Engine.encode_substitute(codepoints, @profile, replacer)

        @impl true
        def encode_from_utf8(input) when is_binary(input),
          do: Engine.encode_from_utf8(input, @profile)

        @impl true
        def decode_chunk(input, final?) when is_binary(input) and is_boolean(final?),
          do: Engine.decode_chunk(input, @profile, final?)

        @impl true
        def encode_chunk(codepoints, _final?, policy) when is_list(codepoints),
          do: Engine.encode_chunk(codepoints, @profile, policy)

        def mappings, do: @profile.rows
        def mapping_count, do: @mapping_count
        def mapping_sha256, do: @mapping_sha256
        def unit_bits, do: 8
        def token_bytes, do: @token_bytes
        def unit_model, do: @unit_model
        def decode_policy, do: :longest_token
        def sequence_round_trip, do: @sequence_round_trip
        def source_reference, do: @source_reference
        def source_url, do: "https://vietunicode.sourceforge.net/charset/vni.html"
        def source_last_modified, do: "2002-03-20T01:55:54Z"

        def source_sha256,
          do: "104cfaf796d37c64cff0f35dfb3dd557cd6ca0e54b01cc517d29966fe83e10b7"

        def normalized_source_sha256,
          do: "676bc2b9220c74b1f4019fc0b096614cbf903eeedd64cadc0a8144db85004549"

        def provenance_qualification, do: :source_only_no_endorsement
      end
    end
  end

  defp build_definition!(module, options) do
    profile_name = Keyword.fetch!(options, :profile)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    mapping_count = Keyword.fetch!(options, :mapping_count)
    max_token_bytes = Keyword.fetch!(options, :max_token_bytes)
    unit_model = Keyword.fetch!(options, :unit_model)
    sequence_round_trip = Keyword.fetch!(options, :sequence_round_trip)

    unless profile_name in [:ascii, :ansi, :mac, :email],
      do: raise(ArgumentError, "unknown VNI profile #{inspect(profile_name)}")

    unless is_binary(canonical) and String.starts_with?(canonical, "VIETUNICODE-2002-VNI-"),
      do: raise(ArgumentError, "VNI canonical must be VietUnicode/date/profile qualified")

    unless is_list(aliases) and aliases != [] and
             Enum.all?(aliases, &String.starts_with?(&1, "ENCODE-VN-0.06-X-VIET-VNI")),
           do: raise(ArgumentError, "VNI aliases must be Encode::VN release qualified")

    if canonical in ["VNI", "VNI-ANSI"] or Enum.any?(aliases, &(&1 in ["VNI", "VNI-ANSI"])),
      do: raise(ArgumentError, "unqualified VNI names are forbidden")

    rows = parse_mapping!(@mapping_path, profile_name)

    unless length(rows) == mapping_count,
      do: raise(ArgumentError, "mapping count mismatch for #{inspect(module)}")

    decode = Map.new(rows, &{&1.token, &1.codepoint})
    encode = Map.new(rows, &{&1.codepoint, &1.token})

    unless map_size(decode) == mapping_count and map_size(encode) == mapping_count,
      do: raise(ArgumentError, "VNI profile mapping is not scalar/token unique")

    actual_max = rows |> Enum.map(&byte_size(&1.token)) |> Enum.max()

    unless actual_max == max_token_bytes,
      do: raise(ArgumentError, "maximum token length mismatch for #{inspect(module)}")

    prefixes =
      Enum.reduce(rows, %{}, fn %{token: token}, result ->
        Enum.reduce(1..(byte_size(token) - 1)//1, result, fn size, prefixes ->
          Map.put(prefixes, binary_part(token, 0, size), true)
        end)
      end)

    profile = %{
      rows: rows,
      decode: decode,
      decode_utf8: Map.new(decode, fn {token, codepoint} -> {token, <<codepoint::utf8>>} end),
      encode: encode,
      prefixes: prefixes,
      max_token_bytes: max_token_bytes
    }

    %{
      profile: profile,
      canonical: canonical,
      aliases: aliases,
      codec_id: codec_id,
      mapping_path: @mapping_path,
      metadata_path: @metadata_path,
      source_path: @source_path,
      source_wire_path: @source_wire_path,
      mapping_sha256: @mapping_path |> File.read!() |> sha256(),
      mapping_count: mapping_count,
      token_bytes: 1..max_token_bytes,
      unit_model: unit_model,
      sequence_round_trip: sequence_round_trip,
      source_reference: {:encode_vn, "0.06", hd(aliases)}
    }
  end

  defp parse_mapping!(path, profile_name) do
    ["profile,token,unicode,origin" | rows] =
      path |> File.read!() |> String.split("\n", trim: true)

    rows
    |> Enum.flat_map(fn row ->
      [profile, token, codepoint, origin] = String.split(row, ",", parts: 4)

      if profile == Atom.to_string(profile_name) do
        [
          %{
            token: Base.decode16!(token, case: :mixed),
            codepoint: String.to_integer(codepoint, 16),
            origin: parse_origin!(origin)
          }
        ]
      else
        []
      end
    end)
  end

  defp parse_origin!("ascii_identity"), do: :ascii_identity
  defp parse_origin!("source_vietnamese"), do: :source_vietnamese

  defp parse_origin!(origin),
    do: raise(ArgumentError, "unknown VNI mapping origin #{inspect(origin)}")

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
