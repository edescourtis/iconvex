defmodule Iconvex.Specs.PDP1CharacterCodes do
  @moduledoc false

  @source_1960_path Path.expand(
                      "../../../priv/sources/pdp1-character-codes/pdp1_1960.csv",
                      __DIR__
                    )
  @source_1963_path Path.expand(
                      "../../../priv/sources/pdp1-character-codes/pdp1_fiodec_1963.csv",
                      __DIR__
                    )
  @metadata_path Path.expand(
                   "../../../priv/sources/pdp1-character-codes/SOURCE_METADATA.md",
                   __DIR__
                 )
  @external_resource @source_1960_path
  @external_resource @source_1963_path
  @external_resource @metadata_path

  @source_1960_sha256 "7495a32bca4897aa54fb0b073149303b66a17bf2f96371e930aa300594c38ab6"
  @source_1963_sha256 "8490b72962584f30c9dc7f3a9684ba3eeb79c7d5530b78ee371a6efe098a8f21"
  @corroborating_1961_sha256 "492aa312130ee1c8fb6c504e780ca1ce8487fde7921197d79c4dabf3984224d4"
  @table_1960_sha256 "d18fb402d10bbd83f793d4082bf90ecc7b8d8716b12274499f6ac55ab93bba3a"
  @table_1963_sha256 "ddac091dcd9f3f7926f476333c1d59cbb8a9e607650094620376ae043c2eec2a"

  for {path, expected} <- [
        {@source_1960_path, @table_1960_sha256},
        {@source_1963_path, @table_1963_sha256}
      ] do
    actual =
      path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    if actual != expected do
      raise "PDP-1 reviewed source table digest mismatch for #{path}"
    end
  end

  parse_octal = fn
    "" -> nil
    value -> String.to_integer(value, 8)
  end

  parse_unicode = fn
    "" -> nil
    "U+" <> value -> String.to_integer(value, 16)
  end

  kinds = %{
    "control" => :control,
    "delete" => :delete,
    "graphic" => :graphic,
    "ribbon_black" => :ribbon_black,
    "ribbon_red" => :ribbon_red,
    "shift_lower" => :shift_lower,
    "shift_upper" => :shift_upper,
    "stop" => :stop,
    "tape_feed" => :tape_feed
  }

  parse_rows = fn path ->
    [_header | lines] = path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(lines, fn line ->
      [concise, physical, lower, upper, kind, source_label] = String.split(line, ",")

      %{
        concise: parse_octal.(concise),
        physical: parse_octal.(physical),
        lower: parse_unicode.(lower),
        upper: parse_unicode.(upper),
        kind: Map.fetch!(kinds, kind),
        source_label: source_label
      }
    end)
  end

  @rows_1960 parse_rows.(@source_1960_path)
  @rows_1963 parse_rows.(@source_1963_path)

  if !(length(@rows_1960) == 48 and length(@rows_1963) == 55) do
    raise "PDP-1 source transcription row count changed"
  end

  odd_parity? = fn unit ->
    unit |> Integer.digits(2) |> Enum.sum() |> rem(2) == 1
  end

  if !(Enum.all?(@rows_1960, fn row -> odd_parity?.(row.physical) end) and
         Enum.all?(@rows_1963, fn
           %{physical: nil} -> true
           %{kind: :tape_feed, physical: 0} -> true
           %{physical: physical} -> odd_parity?.(physical)
         end)) do
    raise "PDP-1 physical source table violates its documented parity rule"
  end

  cell = fn
    %{kind: kind, lower: lower, upper: upper} when kind in [:graphic, :control] ->
      {:character, lower, upper}

    %{kind: :shift_lower} ->
      {:shift, :lower}

    %{kind: :shift_upper} ->
      {:shift, :upper}

    _action ->
      :ignored
  end

  build_table = fn rows, field ->
    rows
    |> Enum.reduce(List.duplicate(:invalid, 256), fn row, table ->
      case Map.fetch!(row, field) do
        nil -> table
        unit -> List.replace_at(table, unit, cell.(row))
      end
    end)
    |> List.to_tuple()
  end

  @tables %{
    concise_1960: build_table.(@rows_1960, :concise),
    friden_1960: build_table.(@rows_1960, :physical),
    concise_1963: build_table.(@rows_1963, :concise),
    fiodec_1963: build_table.(@rows_1963, :physical)
  }

  build_encoder = fn table ->
    Enum.reduce(0..255, %{lower: %{}, upper: %{}}, fn unit, encoders ->
      case elem(table, unit) do
        {:character, lower, upper} ->
          %{
            lower: Map.put_new(encoders.lower, lower, unit),
            upper: Map.put_new(encoders.upper, upper, unit)
          }

        _action ->
          encoders
      end
    end)
  end

  @encoders Map.new(@tables, fn {profile, table} -> {profile, build_encoder.(table)} end)

  @shifts Map.new(@tables, fn {profile, table} ->
            shifts =
              Enum.reduce(0..255, %{}, fn unit, result ->
                case elem(table, unit) do
                  {:shift, state} -> Map.put(result, state, unit)
                  _ -> result
                end
              end)

            if Map.keys(shifts) |> Enum.sort() != [:lower, :upper] do
              raise "PDP-1 profile #{profile} lacks an exact case shift pair"
            end

            {profile, shifts}
          end)

  def source_sha256(:revision_1960), do: @source_1960_sha256
  def source_sha256(:revision_1963), do: @source_1963_sha256
  def corroborating_1961_sha256, do: @corroborating_1961_sha256
  def table_sha256(:revision_1960), do: @table_1960_sha256
  def table_sha256(:revision_1963), do: @table_1963_sha256
  def source_pages(:revision_1960), do: [12, 17]
  def source_pages(:revision_1963), do: [24, 69, 70]
  def printed_source_pages(:revision_1960), do: ["20-21", "30-31"]
  def printed_source_pages(:revision_1963), do: ["23", "68-69"]

  def source_url(:revision_1960),
    do: "https://bitsavers.org/pdf/dec/pdp1/F15_PDP1_Handbook_Apr60.pdf"

  def source_url(:revision_1963),
    do: "https://bitsavers.org/pdf/dec/pdp1/F15D_PDP1_Handbook_Oct63.pdf"

  def decode(input, profile, initial_state) when is_binary(input) do
    case decode_all(input, table(profile), initial_state, 0, []) do
      {:ok, codepoints, _next_state} -> {:ok, codepoints}
      error -> error
    end
  end

  def decode_discard(input, profile, initial_state) when is_binary(input),
    do: decode_discard_all(input, table(profile), initial_state, [])

  def encode(codepoints, profile, initial_state) when is_list(codepoints),
    do: encode_all(codepoints, profile, initial_state, [])

  def encode_discard(codepoints, profile, initial_state) when is_list(codepoints),
    do: encode_discard_all(codepoints, profile, initial_state, [])

  def encode_substitute(codepoints, profile, initial_state, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, profile, initial_state, replacer, [])

  def decode_to_utf8(input, profile, initial_state) when is_binary(input) do
    with {:ok, codepoints} <- decode(input, profile, initial_state) do
      {:ok, List.to_string(codepoints)}
    end
  end

  def encode_from_utf8(input, profile, initial_state) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints, profile, initial_state)

      {kind, codepoints, tail} when kind in [:error, :incomplete] ->
        case encode(codepoints, profile, initial_state) do
          {:ok, _prefix} ->
            offset = byte_size(input) - byte_size(tail)
            Iconvex.Specs.CodecSupport.malformed_utf8(tail, offset)

          error ->
            error
        end
    end
  end

  def decode_chunk(input, profile, state, _final?) when is_binary(input) do
    case decode_all(input, table(profile), state, 0, []) do
      {:ok, codepoints, next_state} -> {:ok, codepoints, next_state, <<>>}
      error -> error
    end
  end

  def encode_chunk(codepoints, profile, state, _final?, policy) when is_list(codepoints) do
    result =
      case policy do
        :error -> encode_all_with_state(codepoints, profile, state)
        :discard -> encode_discard_with_state(codepoints, profile, state)
        {:replace, replacer} -> encode_substitute_with_state(codepoints, profile, state, replacer)
      end

    case result do
      {:ok, output, next_state} -> {:ok, output, next_state, []}
      error -> error
    end
  end

  defp table(profile), do: Map.fetch!(@tables, profile)
  defp encoders(profile), do: Map.fetch!(@encoders, profile)
  defp shifts(profile), do: Map.fetch!(@shifts, profile)

  defp decode_all(<<>>, _table, state, _offset, acc),
    do: {:ok, :lists.reverse(acc), state}

  defp decode_all(<<unit, rest::binary>>, table, state, offset, acc) do
    case elem(table, unit) do
      {:character, lower, upper} ->
        codepoint = if state == :lower, do: lower, else: upper
        decode_all(rest, table, state, offset + 1, [codepoint | acc])

      {:shift, next_state} ->
        decode_all(rest, table, next_state, offset + 1, acc)

      :ignored ->
        decode_all(rest, table, state, offset + 1, acc)

      :invalid ->
        {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp decode_discard_all(<<>>, _table, _state, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<unit, rest::binary>>, table, state, acc) do
    case elem(table, unit) do
      {:character, lower, upper} ->
        codepoint = if state == :lower, do: lower, else: upper
        decode_discard_all(rest, table, state, [codepoint | acc])

      {:shift, next_state} ->
        decode_discard_all(rest, table, next_state, acc)

      _ignored_or_invalid ->
        decode_discard_all(rest, table, state, acc)
    end
  end

  defp encode_all(codepoints, profile, state, acc) do
    case encode_loop(codepoints, profile, state, :error, nil, acc) do
      {:ok, output, _next_state} -> {:ok, output}
      error -> error
    end
  end

  defp encode_discard_all(codepoints, profile, state, acc) do
    {:ok, output, _next_state} = encode_loop(codepoints, profile, state, :discard, nil, acc)
    {:ok, output}
  end

  defp encode_substitute_all(codepoints, profile, state, replacer, acc) do
    case encode_loop(codepoints, profile, state, :replace, replacer, acc) do
      {:ok, output, _next_state} -> {:ok, output}
      error -> error
    end
  end

  defp encode_all_with_state(codepoints, profile, state),
    do: encode_loop(codepoints, profile, state, :error, nil, [])

  defp encode_discard_with_state(codepoints, profile, state),
    do: encode_loop(codepoints, profile, state, :discard, nil, [])

  defp encode_substitute_with_state(codepoints, profile, state, replacer),
    do: encode_loop(codepoints, profile, state, :replace, replacer, [])

  defp encode_loop([], _profile, state, _policy, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), state}

  defp encode_loop([codepoint | rest], profile, state, policy, replacer, acc) do
    case encode_one(codepoint, profile, state) do
      {:ok, bytes, next_state} ->
        encode_loop(rest, profile, next_state, policy, replacer, [bytes | acc])

      :error when policy == :discard ->
        encode_loop(rest, profile, state, policy, replacer, acc)

      :error when policy == :replace ->
        case encode_loop(replacer.(codepoint), profile, state, :error, nil, []) do
          {:ok, replacement, next_state} ->
            encode_loop(rest, profile, next_state, policy, replacer, [replacement | acc])

          error ->
            error
        end

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_one(codepoint, profile, state) do
    profile_encoders = encoders(profile)
    current = Map.fetch!(profile_encoders, state)

    case current do
      %{^codepoint => unit} ->
        {:ok, <<unit>>, state}

      _ ->
        other_state = if state == :lower, do: :upper, else: :lower
        other = Map.fetch!(profile_encoders, other_state)

        case other do
          %{^codepoint => unit} ->
            shift = Map.fetch!(shifts(profile), other_state)
            {:ok, <<shift, unit>>, other_state}

          _ ->
            :error
        end
    end
  end
end

defmodule Iconvex.Specs.PDP1CharacterCodes.Profile do
  @moduledoc false

  defmacro __using__(options) do
    profile = Keyword.fetch!(options, :profile)
    revision = Keyword.fetch!(options, :revision)
    initial = Keyword.fetch!(options, :initial)
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    codec_id = Keyword.fetch!(options, :codec_id)
    unit_bits = Keyword.fetch!(options, :unit_bits)

    quote do
      use Iconvex.Codec
      alias Iconvex.Specs.PDP1CharacterCodes, as: Engine

      @impl true
      def canonical_name, do: unquote(canonical)

      @impl true
      def aliases, do: unquote(aliases)

      @impl true
      def codec_id, do: unquote(codec_id)

      @impl true
      def stateful?, do: true

      def unit_bits, do: unquote(unit_bits)
      def initial_state, do: unquote(initial)
      def source_sha256, do: Engine.source_sha256(unquote(revision))
      def table_sha256, do: Engine.table_sha256(unquote(revision))
      def corroborating_1961_sha256, do: Engine.corroborating_1961_sha256()
      def source_pages, do: Engine.source_pages(unquote(revision))
      def printed_source_pages, do: Engine.printed_source_pages(unquote(revision))
      def source_url, do: Engine.source_url(unquote(revision))

      @impl true
      def decode(input), do: Engine.decode(input, unquote(profile), unquote(initial))

      @impl true
      def decode_discard(input),
        do: Engine.decode_discard(input, unquote(profile), unquote(initial))

      @impl true
      def encode(codepoints), do: Engine.encode(codepoints, unquote(profile), unquote(initial))

      @impl true
      def encode_discard(codepoints),
        do: Engine.encode_discard(codepoints, unquote(profile), unquote(initial))

      @impl true
      def encode_substitute(codepoints, replacer),
        do:
          Engine.encode_substitute(
            codepoints,
            unquote(profile),
            unquote(initial),
            replacer
          )

      @impl true
      def decode_to_utf8(input),
        do: Engine.decode_to_utf8(input, unquote(profile), unquote(initial))

      @impl true
      def encode_from_utf8(input),
        do: Engine.encode_from_utf8(input, unquote(profile), unquote(initial))

      @impl true
      def stream_decoder_init, do: unquote(initial)

      @impl true
      def decode_chunk(input, state, final?),
        do: Engine.decode_chunk(input, unquote(profile), state, final?)

      @impl true
      def stream_encoder_init, do: unquote(initial)

      @impl true
      def encode_chunk(codepoints, state, final?, policy),
        do: Engine.encode_chunk(codepoints, unquote(profile), state, final?, policy)
    end
  end
end

defmodule Iconvex.Specs.PDP1Concise1960InitialLower do
  @moduledoc "DEC PDP-1 April-1960 Concise six-bit code with explicit initial lower case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :concise_1960,
    revision: :revision_1960,
    initial: :lower,
    canonical: "PDP-1-CONCISE-1960-INITIAL-LOWER",
    aliases: ["PDP1-CONCISE-1960-LOWER", "PDP-1-CONCISE-FPC8-1960-INITIAL-LOWER"],
    codec_id: :pdp1_concise_1960_initial_lower,
    unit_bits: 6
end

defmodule Iconvex.Specs.PDP1Concise1960InitialUpper do
  @moduledoc "DEC PDP-1 April-1960 Concise six-bit code with explicit initial upper case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :concise_1960,
    revision: :revision_1960,
    initial: :upper,
    canonical: "PDP-1-CONCISE-1960-INITIAL-UPPER",
    aliases: ["PDP1-CONCISE-1960-UPPER", "PDP-1-CONCISE-FPC8-1960-INITIAL-UPPER"],
    codec_id: :pdp1_concise_1960_initial_upper,
    unit_bits: 6
end

defmodule Iconvex.Specs.PDP1FridenFPC81960InitialLower do
  @moduledoc "DEC PDP-1 April-1960 Friden FPC-8 odd-parity rows with initial lower case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :friden_1960,
    revision: :revision_1960,
    initial: :lower,
    canonical: "PDP-1-FRIDEN-FPC-8-1960-INITIAL-LOWER",
    aliases: ["FRIDEN-FPC-8-PDP1-1960-LOWER", "PDP1-FPC8-1960-LOWER"],
    codec_id: :pdp1_friden_fpc8_1960_initial_lower,
    unit_bits: 8
end

defmodule Iconvex.Specs.PDP1FridenFPC81960InitialUpper do
  @moduledoc "DEC PDP-1 April-1960 Friden FPC-8 odd-parity rows with initial upper case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :friden_1960,
    revision: :revision_1960,
    initial: :upper,
    canonical: "PDP-1-FRIDEN-FPC-8-1960-INITIAL-UPPER",
    aliases: ["FRIDEN-FPC-8-PDP1-1960-UPPER", "PDP1-FPC8-1960-UPPER"],
    codec_id: :pdp1_friden_fpc8_1960_initial_upper,
    unit_bits: 8
end

defmodule Iconvex.Specs.PDP1ConciseFIODEC1963InitialLower do
  @moduledoc "DEC PDP-1 FIO-DEC-era Concise six-bit code with explicit initial lower case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :concise_1963,
    revision: :revision_1963,
    initial: :lower,
    canonical: "PDP-1-CONCISE-FIODEC-1963-INITIAL-LOWER",
    aliases: ["PDP1-CONCISE-FIODEC-1963-LOWER", "PDP-1-CONCISE-1963-LOWER"],
    codec_id: :pdp1_concise_fiodec_1963_initial_lower,
    unit_bits: 6
end

defmodule Iconvex.Specs.PDP1ConciseFIODEC1963InitialUpper do
  @moduledoc "DEC PDP-1 FIO-DEC-era Concise six-bit code with explicit initial upper case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :concise_1963,
    revision: :revision_1963,
    initial: :upper,
    canonical: "PDP-1-CONCISE-FIODEC-1963-INITIAL-UPPER",
    aliases: ["PDP1-CONCISE-FIODEC-1963-UPPER", "PDP-1-CONCISE-1963-UPPER"],
    codec_id: :pdp1_concise_fiodec_1963_initial_upper,
    unit_bits: 6
end

defmodule Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialLower do
  @moduledoc "DEC PDP-1 FIO-DEC odd-parity eight-channel rows with initial lower case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :fiodec_1963,
    revision: :revision_1963,
    initial: :lower,
    canonical: "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-LOWER",
    aliases: ["FIO-DEC-PDP1-1963-LOWER", "PDP1-FIODEC-8BIT-1963-LOWER"],
    codec_id: :pdp1_fiodec_odd_parity_8bit_1963_initial_lower,
    unit_bits: 8
end

defmodule Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialUpper do
  @moduledoc "DEC PDP-1 FIO-DEC odd-parity eight-channel rows with initial upper case."

  use Iconvex.Specs.PDP1CharacterCodes.Profile,
    profile: :fiodec_1963,
    revision: :revision_1963,
    initial: :upper,
    canonical: "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-UPPER",
    aliases: ["FIO-DEC-PDP1-1963-UPPER", "PDP1-FIODEC-8BIT-1963-UPPER"],
    codec_id: :pdp1_fiodec_odd_parity_8bit_1963_initial_upper,
    unit_bits: 8
end
