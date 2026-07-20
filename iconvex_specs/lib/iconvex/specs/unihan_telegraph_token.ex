defmodule Iconvex.Specs.UnihanTelegraphToken.SourceAsset do
  @moduledoc false

  @mapping_header "decimal_token,unicode_scalar"
  @policy_header "decimal_token,source_unicode_scalar,readable_reverse_role," <>
                   "lossless_output_scalar,lossless_reason"
  @scalar_pattern ~r/\AU\+[0-9A-F]{4,6}\z/
  @metadata_markers [
    "Unicode 17.0.0",
    "kMainlandTelegraph",
    "kTaiwanTelegraph",
    "Provisional Other Mappings",
    "does not define concatenated message framing",
    "LICENSE.UNICODE"
  ]
  @lossless_exceptions %{
    "0066" => {0x2F81B, :canonical, 0xF8B00, :normalization},
    "2210" => {0x2F8BA, :canonical, 0xF8B01, :normalization},
    "7775" => {0x5875, :decode_only, 0xF8B02, :duplicate},
    "9795" => {0x843C, :decode_only, 0xF8B03, :duplicate}
  }

  @spec validate!(map(), map()) :: %{
          mainland_rows: [map()],
          taiwan_rows: [map()],
          policy_rows: [map()]
        }
  def validate!(assets, hashes) when is_map(assets) and is_map(hashes) do
    for key <- [:mainland, :taiwan, :policy, :metadata] do
      bytes = fetch_binary!(assets, key)
      expected = fetch_hash!(hashes, key)
      verify_sha!(key, bytes, expected)
    end

    mainland_rows = parse_mapping!(Map.fetch!(assets, :mainland), :mainland, 7_078)
    taiwan_rows = parse_mapping!(Map.fetch!(assets, :taiwan), :taiwan, 9_026)
    validate_mapping_domains!(mainland_rows, taiwan_rows)

    policy_rows =
      Map.fetch!(assets, :policy)
      |> parse_policy!(taiwan_rows)

    validate_metadata!(Map.fetch!(assets, :metadata))

    %{
      mainland_rows: mainland_rows,
      taiwan_rows: taiwan_rows,
      policy_rows: policy_rows
    }
  end

  def validate!(_assets, _hashes) do
    raise ArgumentError, "Unihan telegraph assets and hashes must be maps"
  end

  defp fetch_binary!(assets, key) do
    case Map.fetch(assets, key) do
      {:ok, bytes} when is_binary(bytes) -> bytes
      _ -> raise ArgumentError, "missing binary Unihan telegraph #{key} asset"
    end
  end

  defp fetch_hash!(hashes, key) do
    case Map.fetch(hashes, key) do
      {:ok, <<_::binary-size(64)>> = hash} -> hash
      _ -> raise ArgumentError, "missing lowercase SHA-256 for Unihan telegraph #{key} asset"
    end
  end

  defp verify_sha!(label, bytes, expected) do
    actual = bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "Unihan telegraph #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp parse_mapping!(bytes, label, expected_count) do
    [header | lines] = source_lines!(bytes, label)

    unless header == @mapping_header do
      raise ArgumentError,
            "unexpected Unihan telegraph #{label} header: #{inspect(header)}"
    end

    unless length(lines) == expected_count do
      raise ArgumentError,
            "Unihan telegraph #{label} table must contain exactly #{expected_count} rows"
    end

    rows = Enum.map(lines, &parse_mapping_row!(&1, label))
    validate_strict_token_order!(rows, label)
    rows
  end

  defp source_lines!(bytes, label) do
    if String.contains?(bytes, "\r") do
      raise ArgumentError, "Unihan telegraph #{label} table must use LF line endings"
    end

    unless String.ends_with?(bytes, "\n") and not String.ends_with?(bytes, "\n\n") do
      raise ArgumentError,
            "Unihan telegraph #{label} table must end with exactly one LF"
    end

    lines = bytes |> String.split("\n", trim: false) |> Enum.drop(-1)

    if Enum.any?(lines, &(&1 == "")) do
      raise ArgumentError, "Unihan telegraph #{label} table must not contain blank rows"
    end

    lines
  end

  defp parse_mapping_row!(line, label) do
    case String.split(line, ",") do
      [token, scalar_token] ->
        %{
          token: token,
          value: parse_token!(token, label),
          scalar: parse_scalar!(scalar_token, label)
        }

      _ ->
        raise ArgumentError,
              "Unihan telegraph #{label} row must contain exactly two fields: #{inspect(line)}"
    end
  end

  defp parse_policy!(bytes, taiwan_rows) do
    [header | lines] = source_lines!(bytes, :policy)

    unless header == @policy_header do
      raise ArgumentError,
            "unexpected Unihan telegraph policy header: #{inspect(header)}"
    end

    unless length(lines) == 9_026 do
      raise ArgumentError, "Unihan telegraph policy table must contain exactly 9026 rows"
    end

    rows = Enum.map(lines, &parse_policy_row!/1)
    validate_strict_token_order!(rows, :policy)
    validate_policy_sources!(rows, taiwan_rows)
    validate_readable_roles!(rows, taiwan_rows)
    validate_lossless_policy!(rows)
    rows
  end

  defp parse_policy_row!(line) do
    case String.split(line, ",") do
      [token, source, role, output, reason] ->
        %{
          token: token,
          value: parse_token!(token, :policy),
          source: parse_scalar!(source, :policy),
          role: parse_role!(role),
          output: parse_scalar!(output, :policy),
          reason: parse_reason!(reason)
        }

      _ ->
        raise ArgumentError,
              "Unihan telegraph policy row must contain exactly five fields: #{inspect(line)}"
    end
  end

  defp parse_token!(<<a, b, c, d>>, _label)
       when a in ?0..?9 and b in ?0..?9 and c in ?0..?9 and d in ?0..?9 do
    (a - ?0) * 1_000 + (b - ?0) * 100 + (c - ?0) * 10 + d - ?0
  end

  defp parse_token!(token, label) do
    raise ArgumentError,
          "Unihan telegraph #{label} token must be exactly four ASCII decimal digits: #{inspect(token)}"
  end

  defp parse_scalar!(token, label) do
    if Regex.match?(@scalar_pattern, token) do
      "U+" <> digits = token
      scalar = String.to_integer(digits, 16)

      if valid_scalar?(scalar) do
        scalar
      else
        raise ArgumentError,
              "Unihan telegraph #{label} row contains an invalid Unicode scalar: #{inspect(token)}"
      end
    else
      raise ArgumentError,
            "Unihan telegraph #{label} row contains an invalid Unicode scalar: #{inspect(token)}"
    end
  end

  defp parse_role!("canonical-minimum"), do: :canonical
  defp parse_role!("decode-alias"), do: :decode_only

  defp parse_role!(role) do
    raise ArgumentError, "invalid Unihan telegraph readable reverse role: #{inspect(role)}"
  end

  defp parse_reason!("source-scalar"), do: :source
  defp parse_reason!("canonical-normalization-collision"), do: :normalization
  defp parse_reason!("duplicate-readable-reverse"), do: :duplicate

  defp parse_reason!(reason) do
    raise ArgumentError, "invalid Unihan telegraph lossless reason: #{inspect(reason)}"
  end

  defp validate_strict_token_order!(rows, label) do
    values = Enum.map(rows, & &1.value)

    unless strictly_increasing?(values) do
      raise ArgumentError,
            "Unihan telegraph #{label} tokens must be unique and strictly increasing"
    end
  end

  defp strictly_increasing?([]), do: true
  defp strictly_increasing?([_]), do: true

  defp strictly_increasing?([first, second | rest]) when first < second,
    do: strictly_increasing?([second | rest])

  defp strictly_increasing?(_values), do: false

  defp validate_mapping_domains!(mainland_rows, taiwan_rows) do
    mainland_scalars = Enum.map(mainland_rows, & &1.scalar)
    taiwan_scalars = Enum.map(taiwan_rows, & &1.scalar)

    unless length(Enum.uniq(mainland_scalars)) == 7_078 do
      raise ArgumentError, "Unihan telegraph mainland Unicode scalars must be unique"
    end

    duplicate_groups =
      taiwan_rows
      |> Enum.group_by(& &1.scalar, & &1.token)
      |> Enum.filter(fn {_scalar, tokens} -> length(tokens) > 1 end)
      |> Map.new(fn {scalar, tokens} -> {scalar, tokens} end)

    unless length(Enum.uniq(taiwan_scalars)) == 9_024 and
             duplicate_groups == %{0x5875 => ["1057", "7775"], 0x843C => ["5501", "9795"]} do
      raise ArgumentError,
            "Unihan telegraph Taiwan table must have exactly the documented duplicate tokens"
    end
  end

  defp validate_policy_sources!(policy_rows, taiwan_rows) do
    source_by_token = Map.new(taiwan_rows, &{&1.token, &1.scalar})

    unless Enum.all?(policy_rows, fn row -> Map.get(source_by_token, row.token) == row.source end) do
      raise ArgumentError,
            "Unihan telegraph policy source scalar must match the Taiwan mapping for its token"
    end
  end

  defp validate_readable_roles!(policy_rows, taiwan_rows) do
    minimum_token_by_scalar =
      Enum.reduce(taiwan_rows, %{}, fn row, acc ->
        Map.put_new(acc, row.scalar, row.token)
      end)

    unless Enum.all?(policy_rows, fn row ->
             expected =
               if minimum_token_by_scalar[row.source] == row.token,
                 do: :canonical,
                 else: :decode_only

             row.role == expected
           end) do
      raise ArgumentError,
            "Unihan telegraph policy readable roles must select the minimum decimal token"
    end
  end

  defp validate_lossless_policy!(rows) do
    outputs = Enum.map(rows, & &1.output)

    unless length(Enum.uniq(outputs)) == 9_026 do
      raise ArgumentError, "Unihan telegraph lossless output scalars must be unique"
    end

    unless Enum.all?(rows, &valid_lossless_row?/1) do
      raise ArgumentError,
            "Unihan telegraph lossless policy does not match its documented VPUA rewrites"
    end
  end

  defp valid_lossless_row?(row) do
    case Map.fetch(@lossless_exceptions, row.token) do
      {:ok, {source, role, output, reason}} ->
        {row.source, row.role, row.output, row.reason} == {source, role, output, reason}

      :error ->
        row.output == row.source and row.reason == :source
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@metadata_markers, &String.contains?(metadata, &1)) do
      raise ArgumentError,
            "Unihan telegraph metadata omits required source, grammar, transport, or license claims"
    end
  end

  defp valid_scalar?(scalar),
    do: scalar in 0..0x10FFFF and scalar not in 0xD800..0xDFFF
end

defmodule Iconvex.Specs.UnihanTelegraphToken.Engine do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/unihan-17.0.0-telegraph", __DIR__)
  @mainland_path Path.join(@source_dir, "mainland_tokens.csv")
  @taiwan_path Path.join(@source_dir, "taiwan_tokens.csv")
  @policy_path Path.join(@source_dir, "taiwan_policy.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")

  @external_resource @mainland_path
  @external_resource @taiwan_path
  @external_resource @policy_path
  @external_resource @metadata_path

  @hashes %{
    mainland: "685b057cc0690c19718966aa02121887071398227c6b48605cf9347db70e16f0",
    taiwan: "15dc21eacf695ce038500e68fa40c125d0762b5e265c9683f82f17d2eac878a6",
    policy: "79890c693597f1f25b4e68abe5627883c8299d7d382ed8865c42a3d361971696",
    metadata: "59a38784c2ec0e931d6f6edeb287ed6cff4077014dba1263f0d76f3339a07ddd"
  }

  validated =
    Iconvex.Specs.UnihanTelegraphToken.SourceAsset.validate!(
      %{
        mainland: File.read!(@mainland_path),
        taiwan: File.read!(@taiwan_path),
        policy: File.read!(@policy_path),
        metadata: File.read!(@metadata_path)
      },
      @hashes
    )

  build_table = fn rows, field ->
    assigned = Map.new(rows, &{&1.value, Map.fetch!(&1, field)})

    0..9_999
    |> Enum.map(&Map.get(assigned, &1, :unassigned))
    |> List.to_tuple()
  end

  @tables %{
    mainland: build_table.(validated.mainland_rows, :scalar),
    taiwan_readable: build_table.(validated.taiwan_rows, :scalar),
    taiwan_lossless: build_table.(validated.policy_rows, :output)
  }

  @reverse %{
    mainland: Map.new(validated.mainland_rows, &{&1.scalar, &1.value}),
    taiwan_readable:
      Enum.reduce(validated.taiwan_rows, %{}, fn row, acc ->
        Map.put_new(acc, row.scalar, row.value)
      end),
    taiwan_lossless: Map.new(validated.policy_rows, &{&1.output, &1.value})
  }

  @metadata %{
    mainland: %{
      mapping_name: "UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN",
      unicode_version: "17.0.0",
      unihan_property: :kMainlandTelegraph,
      property_status: :provisional,
      grammar: "[0-9]{4}",
      transport: :single_property_token,
      stream_transport: :undefined,
      aliases: [],
      assigned_tokens: 7_078,
      reverse_scalars: 7_078,
      reverse_policy: :unique,
      source_sha256: @hashes.mainland
    },
    taiwan_readable: %{
      mapping_name: "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE",
      unicode_version: "17.0.0",
      unihan_property: :kTaiwanTelegraph,
      property_status: :provisional,
      grammar: "[0-9]{4}",
      transport: :single_property_token,
      stream_transport: :undefined,
      aliases: [],
      assigned_tokens: 9_026,
      reverse_scalars: 9_024,
      reverse_policy: :minimum_decimal_token,
      source_sha256: @hashes.taiwan
    },
    taiwan_lossless: %{
      mapping_name: "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1",
      unicode_version: "17.0.0",
      unihan_property: :kTaiwanTelegraph,
      property_status: :provisional,
      grammar: "[0-9]{4}",
      transport: :single_property_token,
      stream_transport: :undefined,
      aliases: [],
      assigned_tokens: 9_026,
      reverse_scalars: 9_026,
      reverse_policy: :lossless_vpua_1,
      vpua_range: 0xF8B00..0xF8B03,
      source_sha256: @hashes.policy
    }
  }

  @spec mapping_name(:mainland | :taiwan_readable | :taiwan_lossless) :: String.t()
  def mapping_name(profile), do: @metadata |> Map.fetch!(profile) |> Map.fetch!(:mapping_name)

  @spec metadata(:mainland | :taiwan_readable | :taiwan_lossless) :: map()
  def metadata(profile), do: Map.fetch!(@metadata, profile)

  def decode_token(token, profile) when is_binary(token) do
    with {:ok, value} <- token_value(token) do
      case elem(Map.fetch!(@tables, profile), value) do
        :unassigned -> {:error, {:unassigned_token, token}}
        scalar -> {:ok, scalar}
      end
    end
  end

  def decode_token(_token, _profile), do: {:error, {:invalid_argument, :token}}

  def decode_token_to_utf8(token, profile) do
    case decode_token(token, profile) do
      {:ok, scalar} -> {:ok, <<scalar::utf8>>}
      {:error, _reason} = error -> error
    end
  end

  def encode_scalar(scalar, profile) when is_integer(scalar) do
    cond do
      not valid_scalar?(scalar) ->
        {:error, {:invalid_unicode_scalar, scalar}}

      true ->
        case Map.fetch(Map.fetch!(@reverse, profile), scalar) do
          {:ok, value} -> {:ok, decimal_token(value)}
          :error -> {:error, {:unrepresentable_scalar, scalar}}
        end
    end
  end

  def encode_scalar(_scalar, _profile), do: {:error, {:invalid_argument, :scalar}}

  def encode_utf8_to_token(<<scalar::utf8>>, profile), do: encode_scalar(scalar, profile)

  def encode_utf8_to_token(utf8, profile) when is_binary(utf8) do
    case :unicode.characters_to_binary(utf8, :utf8, :utf8) do
      valid when is_binary(valid) ->
        case count_utf8_scalars(valid, 0, nil) do
          {1, scalar} ->
            encode_scalar(scalar, profile)

          {count, _first} ->
            {:error, {:invalid_scalar_count, count}}
        end

      {:error, _converted, <<byte, _rest::binary>> = rest} ->
        {:error, {:invalid_utf8, :invalid_sequence, byte_size(utf8) - byte_size(rest), <<byte>>}}

      {:incomplete, _converted, rest} ->
        {:error, {:invalid_utf8, :incomplete_sequence, byte_size(utf8) - byte_size(rest), rest}}
    end
  end

  def encode_utf8_to_token(_utf8, _profile), do: {:error, {:invalid_argument, :utf8}}

  defp count_utf8_scalars(<<>>, count, first), do: {count, first}

  defp count_utf8_scalars(<<scalar::utf8, rest::binary>>, 0, nil),
    do: count_utf8_scalars(rest, 1, scalar)

  defp count_utf8_scalars(<<_scalar::utf8, rest::binary>>, count, first),
    do: count_utf8_scalars(rest, count + 1, first)

  defp token_value(token) when byte_size(token) != 4,
    do: {:error, {:invalid_token_length, byte_size(token)}}

  defp token_value(<<a, b, c, d>>) do
    cond do
      a not in ?0..?9 -> {:error, {:invalid_token_digit, 0, <<a>>}}
      b not in ?0..?9 -> {:error, {:invalid_token_digit, 1, <<b>>}}
      c not in ?0..?9 -> {:error, {:invalid_token_digit, 2, <<c>>}}
      d not in ?0..?9 -> {:error, {:invalid_token_digit, 3, <<d>>}}
      true -> {:ok, (a - ?0) * 1_000 + (b - ?0) * 100 + (c - ?0) * 10 + d - ?0}
    end
  end

  defp decimal_token(value) do
    <<div(value, 1_000) + ?0, div(rem(value, 1_000), 100) + ?0, div(rem(value, 100), 10) + ?0,
      rem(value, 10) + ?0>>
  end

  defp valid_scalar?(scalar),
    do: scalar in 0..0x10FFFF and scalar not in 0xD800..0xDFFF
end

defmodule Iconvex.Specs.Unihan17MainlandTelegraphDecimalToken do
  @moduledoc "Unicode 17 kMainlandTelegraph single-decimal-token mapping."
  @behaviour Iconvex.Specs.PropertyTokenMapping
  @profile :mainland

  def mapping_name, do: Iconvex.Specs.UnihanTelegraphToken.Engine.mapping_name(@profile)
  def metadata, do: Iconvex.Specs.UnihanTelegraphToken.Engine.metadata(@profile)

  def decode_token(token),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.decode_token(token, @profile)

  def decode_token_to_utf8(token),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.decode_token_to_utf8(token, @profile)

  def encode_scalar(scalar),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.encode_scalar(scalar, @profile)

  def encode_utf8_to_token(utf8),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.encode_utf8_to_token(utf8, @profile)
end

defmodule Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenReadable do
  @moduledoc "Unicode 17 kTaiwanTelegraph readable single-decimal-token mapping."
  @behaviour Iconvex.Specs.PropertyTokenMapping
  @profile :taiwan_readable

  def mapping_name, do: Iconvex.Specs.UnihanTelegraphToken.Engine.mapping_name(@profile)
  def metadata, do: Iconvex.Specs.UnihanTelegraphToken.Engine.metadata(@profile)

  def decode_token(token),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.decode_token(token, @profile)

  def decode_token_to_utf8(token),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.decode_token_to_utf8(token, @profile)

  def encode_scalar(scalar),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.encode_scalar(scalar, @profile)

  def encode_utf8_to_token(utf8),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.encode_utf8_to_token(utf8, @profile)
end

defmodule Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenLosslessVPUA1 do
  @moduledoc "Unicode 17 kTaiwanTelegraph bijective VPUA single-token mapping."
  @behaviour Iconvex.Specs.PropertyTokenMapping
  @profile :taiwan_lossless

  def mapping_name, do: Iconvex.Specs.UnihanTelegraphToken.Engine.mapping_name(@profile)
  def metadata, do: Iconvex.Specs.UnihanTelegraphToken.Engine.metadata(@profile)

  def decode_token(token),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.decode_token(token, @profile)

  def decode_token_to_utf8(token),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.decode_token_to_utf8(token, @profile)

  def encode_scalar(scalar),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.encode_scalar(scalar, @profile)

  def encode_utf8_to_token(utf8),
    do: Iconvex.Specs.UnihanTelegraphToken.Engine.encode_utf8_to_token(utf8, @profile)
end
