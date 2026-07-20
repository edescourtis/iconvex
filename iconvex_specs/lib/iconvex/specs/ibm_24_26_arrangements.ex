defmodule Iconvex.Specs.IBM2426Arrangements.SourceAsset do
  @moduledoc false

  import Bitwise

  @mapping_path Path.expand(
                  "../../../priv/sources/ibm-24-26-arrangements/figure_23_arrangements.csv",
                  __DIR__
                )
  @metadata_path Path.expand(
                   "../../../priv/sources/ibm-24-26-arrangements/SOURCE_METADATA.md",
                   __DIR__
                 )

  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "edb7190244bbf1bca034453bc7de16ccc78d5a3d86c5f5957ec82a2f93d25733"
  @metadata_sha256 "eb261f34e7d19f2308608e14dc0597b4e4949252586b7a28cd5aaf962f78111c"
  @manual_sha256 "8d1f8e0b937989fa720d434b636bc829899414b7f11396b436ccd68b2265c91b"
  @manual_size 6_161_673
  @source_url "https://bitsavers.org/pdf/ibm/punchedCard/Keypunch/024-026/A24-0520-3_24_26_Card_Punch_Reference_Manual_Oct1965.pdf"
  @letters ~w(A B C D E F G H J K)
  @header "arrangement,column_index,column_label,punch_rows,mask_hex,unicode_hex,canonical_encode,decode_accepted"

  @mapping_bytes File.read!(@mapping_path)
  @metadata_bytes File.read!(@metadata_path)

  for {bytes, expected, label} <- [
        {@mapping_bytes, @mapping_sha256, "mapping"},
        {@metadata_bytes, @metadata_sha256, "metadata"}
      ] do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    if actual != expected do
      raise ArgumentError,
            "IBM 24/26 #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  @rows @mapping_bytes
        |> String.split("\n", trim: true)
        |> then(fn [header | lines] ->
          if header != @header,
            do: raise(ArgumentError, "unexpected IBM 24/26 mapping header: #{header}")

          Enum.map(lines, fn line ->
            case String.split(line, ",") do
              [
                arrangement,
                index,
                label,
                punches,
                "0x" <> mask,
                "U+" <> codepoint,
                canonical,
                accepted
              ]
              when canonical in ["yes", "no"] and accepted == "yes" ->
                %{
                  arrangement: arrangement,
                  column_index: String.to_integer(index),
                  column_label: label,
                  punch_rows: punches,
                  mask: String.to_integer(mask, 16),
                  codepoint: String.to_integer(codepoint, 16),
                  canonical_encode: canonical == "yes"
                }

              fields ->
                raise ArgumentError,
                      "invalid IBM 24/26 mapping row #{inspect(fields)}"
            end
          end)
        end)

  if length(@rows) != 110 do
    raise ArgumentError, "IBM 24/26 mapping must contain exactly 110 rows"
  end

  @expected_row_keys for arrangement <- @letters, index <- 1..11, do: {arrangement, index}
  @actual_row_keys Enum.map(@rows, &{&1.arrangement, &1.column_index})

  if @actual_row_keys != @expected_row_keys do
    raise ArgumentError, "IBM 24/26 rows are not in exact Figure 23 order"
  end

  @base_rows [{0x20, 0x000}, {0x30, 0x200}] ++
               for(number <- 1..9, do: {0x30 + number, 1 <<< (9 - number)}) ++
               for(
                 number <- 1..9,
                 do: {0x41 + number - 1, 0x800 ||| 1 <<< (9 - number)}
               ) ++
               for(
                 number <- 1..9,
                 do: {0x4A + number - 1, 0x400 ||| 1 <<< (9 - number)}
               ) ++
               for(
                 number <- 2..9,
                 do: {0x53 + number - 2, 0x200 ||| 1 <<< (9 - number)}
               )

  @profiles Map.new(@letters, fn letter ->
              special =
                @rows
                |> Enum.filter(&(&1.arrangement == letter))
                |> Enum.map(&{&1.codepoint, &1.mask, &1.canonical_encode})

              {seen, mappings, decode_aliases} =
                Enum.reduce(
                  Enum.map(@base_rows, fn {codepoint, mask} -> {codepoint, mask, true} end) ++
                    special,
                  {%{}, [], []},
                  fn {codepoint, mask, declared_canonical?}, {seen, mappings, aliases} ->
                    case Map.fetch(seen, codepoint) do
                      :error when declared_canonical? ->
                        {Map.put(seen, codepoint, mask), [{codepoint, mask} | mappings], aliases}

                      {:ok, _canonical_mask} when not declared_canonical? ->
                        {seen, mappings, [{codepoint, mask} | aliases]}

                      :error ->
                        raise ArgumentError,
                              "IBM 24/26 arrangement #{letter} marks first #{codepoint} alias-only"

                      {:ok, canonical_mask} ->
                        raise ArgumentError,
                              "IBM 24/26 arrangement #{letter} marks duplicate #{codepoint} canonical at #{mask}; first is #{canonical_mask}"
                    end
                  end
                )

              mappings = Enum.reverse(mappings)
              decode_aliases = Enum.reverse(decode_aliases)

              accepted_masks =
                MapSet.new(
                  Enum.map(mappings ++ decode_aliases, fn {_codepoint, mask} -> mask end)
                )

              if MapSet.size(accepted_masks) != 48 do
                raise ArgumentError,
                      "IBM 24/26 arrangement #{letter} must accept exactly 48 masks"
              end

              {letter,
               %{
                 mappings: mappings,
                 decode_aliases: decode_aliases,
                 canonical_count: map_size(seen),
                 accepted_count: MapSet.size(accepted_masks)
               }}
            end)

  def letters, do: @letters
  def rows, do: @rows
  def rows(letter) when letter in @letters, do: Enum.filter(@rows, &(&1.arrangement == letter))
  def profile!(letter), do: Map.fetch!(@profiles, letter)
  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def manual_sha256, do: @manual_sha256
  def manual_size, do: @manual_size
  def source_url, do: @source_url
  def source_pages, do: [28, 37]
  def printed_source_pages, do: ["27", "36"]
  def reverse_policy, do: :base_then_figure_23_left_to_right
end

defmodule Iconvex.Specs.IBM2426Arrangements.Definition do
  @moduledoc false

  defmacro defarrangement(letter, logical_module, be_module, le_module, aliases) do
    profile = Iconvex.Specs.IBM2426Arrangements.SourceAsset.profile!(letter)
    canonical = "IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-#{letter}"
    transport_aliases = Enum.reject(aliases, &String.contains?(&1, " "))
    be_aliases = Enum.map(transport_aliases, &"#{&1}-16BE")
    le_aliases = Enum.map(transport_aliases, &"#{&1}-16LE")
    be_id = String.to_atom("ibm_24_26_arrangement_#{String.downcase(letter)}_16be")
    le_id = String.to_atom("ibm_24_26_arrangement_#{String.downcase(letter)}_16le")
    logical_doc = "IBM 24/26 Figure 23 arrangement #{letter} logical 12-bit profile."
    be_doc = "IBM 24/26 arrangement #{letter} in zero-padded 16-bit big-endian words."
    le_doc = "IBM 24/26 arrangement #{letter} in zero-padded 16-bit little-endian words."

    quote do
      defmodule unquote(logical_module) do
        @moduledoc unquote(logical_doc)

        use Iconvex.Specs.PunchedCard.Profile,
          canonical: unquote(canonical),
          aliases: unquote(aliases),
          mappings: unquote(Macro.escape(profile.mappings)),
          decode_aliases: unquote(Macro.escape(profile.decode_aliases)),
          transports: [unquote(be_module), unquote(le_module)],
          source_sha256: Iconvex.Specs.IBM2426Arrangements.SourceAsset.manual_sha256(),
          source_url: Iconvex.Specs.IBM2426Arrangements.SourceAsset.source_url(),
          source_pages: Iconvex.Specs.IBM2426Arrangements.SourceAsset.source_pages(),
          printed_source_pages:
            Iconvex.Specs.IBM2426Arrangements.SourceAsset.printed_source_pages()

        alias Iconvex.Specs.IBM2426Arrangements.SourceAsset

        def arrangement, do: unquote(letter)
        def mapping_sha256, do: SourceAsset.mapping_sha256()
        def metadata_sha256, do: SourceAsset.metadata_sha256()
        def manual_size, do: SourceAsset.manual_size()
        def reverse_policy, do: SourceAsset.reverse_policy()
        def extraction_rows, do: SourceAsset.rows(unquote(letter))
        def gnu_libiconv_support, do: :unsupported
      end

      defmodule unquote(be_module) do
        @moduledoc unquote(be_doc)

        use Iconvex.Specs.PunchedCard.Transport,
          profile: unquote(logical_module),
          endian: :big,
          canonical: unquote(canonical <> "-16BE"),
          aliases: unquote(be_aliases),
          codec_id: unquote(be_id)
      end

      defmodule unquote(le_module) do
        @moduledoc unquote(le_doc)

        use Iconvex.Specs.PunchedCard.Transport,
          profile: unquote(logical_module),
          endian: :little,
          canonical: unquote(canonical <> "-16LE"),
          aliases: unquote(le_aliases),
          codec_id: unquote(le_id)
      end
    end
  end
end
