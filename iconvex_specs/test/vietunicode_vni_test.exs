defmodule Iconvex.Specs.VietUnicodeVNITest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @source_dir Path.expand("../priv/sources/vietunicode-vni-2002", __DIR__)
  @source_path Path.join(@source_dir, "vni.html")
  @source_wire_path Path.join(@source_dir, "vni.html.base64")
  @mapping_path Path.join(@source_dir, "vni_profiles.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @source_sha256 "104cfaf796d37c64cff0f35dfb3dd557cd6ca0e54b01cc517d29966fe83e10b7"
  @normalized_source_sha256 "676bc2b9220c74b1f4019fc0b096614cbf903eeedd64cadc0a8144db85004549"

  @profiles [
    {:ascii, Iconvex.Specs.VietUnicodeVNI.ASCII2002, "VIETUNICODE-2002-VNI-ASCII-DOS",
     "ENCODE-VN-0.06-X-VIET-VNI-ASCII", 255, 1},
    {:ansi, Iconvex.Specs.VietUnicodeVNI.ANSI2002, "VIETUNICODE-2002-VNI-ANSI-WIN-UNIX",
     "ENCODE-VN-0.06-X-VIET-VNI", 262, 2},
    {:mac, Iconvex.Specs.VietUnicodeVNI.Mac2002, "VIETUNICODE-2002-VNI-MAC",
     "ENCODE-VN-0.06-X-VIET-VNI-MAC", 262, 2},
    {:email, Iconvex.Specs.VietUnicodeVNI.InternetMail2002, "VIETUNICODE-2002-VNI-INTERNET-MAIL",
     "ENCODE-VN-0.06-X-VIET-VNI-EMAIL", 262, 3}
  ]

  @unicode_corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @unicode_corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  test "RED: the 2002 VietUnicode snapshot and normalized profile table are exact" do
    normalized_source = File.read!(@source_path)

    wire_source =
      @source_wire_path |> File.read!() |> String.replace(~r/\s+/, "") |> Base.decode64!()

    assert sha256(wire_source) == @source_sha256
    assert sha256(normalized_source) == @normalized_source_sha256
    assert String.replace(wire_source, "\r\n", "\n") <> "\n" == normalized_source
    assert File.read!(@metadata_path) =~ @source_sha256

    source_rows = parse_source_rows(normalized_source)
    normalized = normalized_rows()

    assert length(source_rows) == 134
    assert length(normalized) == 1_041

    for {profile, codec, _canonical, _alias, expected_count, _max_bytes} <- @profiles do
      expected = expected_profile(source_rows, profile)
      actual = normalized |> Enum.filter(&(&1.profile == profile)) |> token_map()

      assert map_size(actual) == expected_count
      assert actual == expected
      assert apply(codec, :mapping_sha256, []) == sha256(File.read!(@mapping_path))
      assert apply(codec, :source_sha256, []) == @source_sha256
      assert apply(codec, :normalized_source_sha256, []) == @normalized_source_sha256

      assert apply(codec, :source_url, []) ==
               "https://vietunicode.sourceforge.net/charset/vni.html"

      assert apply(codec, :source_last_modified, []) == "2002-03-20T01:55:54Z"
    end
  end

  test "RED: every public name remains profile, source, and date qualified" do
    for {_profile, codec, canonical, reference_alias, _count, max_bytes} <- @profiles do
      assert Code.ensure_loaded?(codec)
      assert apply(codec, :canonical_name, []) == canonical
      assert apply(codec, :aliases, []) == [reference_alias]
      assert apply(codec, :unit_bits, []) == 8
      assert apply(codec, :token_bytes, []) == 1..max_bytes
      assert apply(codec, :decode_policy, []) == :longest_token
      assert apply(codec, :source_reference, []) == {:encode_vn, "0.06", reference_alias}

      refute canonical in ["VNI", "VNI-ANSI", "VNI-ASCII", "VNI-MAC", "VNI-EMAIL"]
      refute Enum.any?(apply(codec, :aliases, []), &(&1 in ["VNI", "VNI-ANSI"]))
    end

    assert apply(Iconvex.Specs.VietUnicodeVNI.ASCII2002, :unit_model, []) ==
             :single_byte_font_glyph_profile

    for codec <- [
          Iconvex.Specs.VietUnicodeVNI.ANSI2002,
          Iconvex.Specs.VietUnicodeVNI.Mac2002
        ] do
      assert apply(codec, :unit_model, []) == :one_or_two_byte_token_encoding
      assert apply(codec, :sequence_round_trip, []) == :all_mapped_scalar_sequences
    end

    email = Iconvex.Specs.VietUnicodeVNI.InternetMail2002
    assert apply(email, :unit_model, []) == :one_to_three_byte_font_token_profile
    assert apply(email, :sequence_round_trip, []) == :not_injective_across_token_boundaries
  end

  test "RED: all four source-qualified profiles are selected and centrally registered" do
    modules = Enum.map(@profiles, &elem(&1, 1))
    assert Iconvex.Specs.vietunicode_vni_codecs() == modules
    assert Enum.all?(modules, &(&1 in Iconvex.Specs.codecs()))
    assert Enum.all?(modules, &(&1 in Iconvex.Specs.catalogued_codecs()))

    registrations = Iconvex.Specs.registrations()

    for {_profile, codec, canonical, reference_alias, _count, _max_bytes} <- @profiles do
      assert Enum.any?(registrations, fn registration ->
               registration.codec == codec and registration.canonical == canonical and
                 registration.source == "VIETUNICODE-2002" and
                 registration.aliases == [reference_alias]
             end)

      assert {:ok, %{codec: ^codec}} = Iconvex.ExternalRegistry.resolve(canonical)
      assert {:ok, %{codec: ^codec}} = Iconvex.ExternalRegistry.resolve(reference_alias)
    end

    for generic <- ["VNI", "VNI-ANSI", "VNI-ASCII", "VNI-MAC", "VNI-EMAIL"] do
      assert :error = Iconvex.ExternalRegistry.resolve(generic)
    end
  end

  test "RED: every normalized token is exact in both scalar directions" do
    for {profile, codec, _canonical, _alias, expected_count, _max_bytes} <- @profiles do
      rows = Enum.filter(normalized_rows(), &(&1.profile == profile))
      assert length(rows) == expected_count

      for %{token: token, codepoint: codepoint} <- rows do
        assert apply(codec, :decode, [token]) == {:ok, [codepoint]}
        assert apply(codec, :decode_to_utf8, [token]) == {:ok, <<codepoint::utf8>>}
        assert apply(codec, :encode, [[codepoint]]) == {:ok, token}
        assert apply(codec, :encode_from_utf8, [<<codepoint::utf8>>]) == {:ok, token}
      end
    end
  end

  test "RED: all octets and every mapped-token boundary follow independent longest match" do
    for {profile, codec, _canonical, _alias, _count, _max_bytes} <- @profiles do
      rows = Enum.filter(normalized_rows(), &(&1.profile == profile))
      decode = token_map(rows)

      for byte <- 0..255 do
        input = <<byte>>
        expected = reference_decode(input, decode)
        assert apply(codec, :decode, [input]) == expected
      end

      for %{token: token} <- rows, byte <- 0..255 do
        input = token <> <<byte>>
        expected = reference_decode(input, decode)
        assert apply(codec, :decode, [input]) == expected
      end
    end
  end

  test "RED: inverse behavior is exhaustive, including Internet Mail collisions" do
    for {profile, codec, _canonical, _alias, _count, _max_bytes} <- @profiles do
      rows = Enum.filter(normalized_rows(), &(&1.profile == profile))
      decode = token_map(rows)
      repertoire = rows |> Enum.map(& &1.codepoint) |> Enum.sort()

      collision_count =
        Enum.reduce(repertoire, 0, fn first, collisions ->
          Enum.reduce(repertoire, collisions, fn second, pair_collisions ->
            assert {:ok, encoded} = apply(codec, :encode, [[first, second]])
            expected = reference_decode(encoded, decode)
            actual = apply(codec, :decode, [encoded])
            assert actual == expected

            if actual == {:ok, [first, second]}, do: pair_collisions, else: pair_collisions + 1
          end)
        end)

      case profile do
        :email -> assert collision_count == 134
        _other -> assert collision_count == 0
      end
    end
  end

  test "RED: stream decoding agrees at every split and retains every extendable suffix" do
    for {profile, codec, _canonical, _alias, _count, _max_bytes} <- @profiles do
      rows = Enum.filter(normalized_rows(), &(&1.profile == profile))
      decode = token_map(rows)
      input = rows |> Enum.take_every(17) |> Enum.map_join(& &1.token)
      assert {:ok, expected} = reference_decode(input, decode)

      for split <- 0..byte_size(input) do
        left = binary_part(input, 0, split)
        right = binary_part(input, split, byte_size(input) - split)
        assert {:ok, left_decoded, pending} = apply(codec, :decode_chunk, [left, false])
        assert {:ok, right_decoded, <<>>} = apply(codec, :decode_chunk, [pending <> right, true])
        assert left_decoded ++ right_decoded == expected
      end

      prefixes = proper_prefixes(rows)

      for prefix <- prefixes do
        assert {:ok, [], ^prefix} = apply(codec, :decode_chunk, [prefix, false])
      end
    end
  end

  test "RED: strict, discard, replacement, and malformed UTF-8 policies progress" do
    for {profile, codec, _canonical, _alias, _count, _max_bytes} <- @profiles do
      rows = Enum.filter(normalized_rows(), &(&1.profile == profile))
      decode = token_map(rows)

      invalid =
        Enum.find(
          0..255,
          &(reference_decode(<<&1>>, decode) != {:ok, [&1]} and not Map.has_key?(decode, <<&1>>))
        )

      if invalid do
        input = " " <> <<invalid>> <> " "
        assert apply(codec, :decode, [input]) == {:error, :invalid_sequence, 1, <<invalid>>}
        assert apply(codec, :decode_discard, [input]) == {:ok, ~c"  "}
      end

      assert apply(codec, :encode, [[?A, 0x1F600, ?B]]) ==
               {:error, :unrepresentable_character, 0x1F600}

      assert apply(codec, :encode_discard, [[?A, 0x1F600, ?B]]) ==
               apply(codec, :encode, [~c"AB"])

      assert apply(codec, :encode_substitute, [[?A, 0x1F600, ?B], fn _ -> [??] end]) ==
               apply(codec, :encode, [~c"A?B"])

      assert apply(codec, :encode_from_utf8, [<<"A", 0xFF, "B">>]) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF, ?B>>}
    end
  end

  test "RED: public conversion and streaming policies use the native profile codecs" do
    for {_profile, codec, canonical, _alias, _count, _max_bytes} <- @profiles do
      assert {:ok, token} = Iconvex.register_codec_if_absent(codec)

      try do
        text = "Đ Á ơ ự"
        codepoints = String.to_charlist(text)
        assert {:ok, encoded} = apply(codec, :encode, [codepoints])
        assert Iconvex.convert(text, "UTF-8", canonical) == {:ok, encoded}
        assert Iconvex.convert(encoded, canonical, "UTF-8") == {:ok, text}

        chunks = for <<byte <- encoded>>, do: <<byte>>
        assert {:ok, stream} = Iconvex.stream(chunks, canonical, "UTF-8")
        assert stream |> Enum.to_list() |> IO.iodata_to_binary() == text
      after
        if is_reference(token), do: assert(:ok == Iconvex.unregister_codec(codec, token))
      end

      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(codec)
    end
  end

  test "RED: the complete Unicode scalar corpus exposes no accidental encoder keys" do
    corpus = File.read!(@unicode_corpus)
    assert sha256(corpus) == @unicode_corpus_sha256
    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint

    for {profile, codec, _canonical, _alias, expected_count, _max_bytes} <- @profiles do
      rows = Enum.filter(normalized_rows(), &(&1.profile == profile))
      inverse = Map.new(rows, &{&1.codepoint, &1.token})

      expected =
        for codepoint <- codepoints,
            token = inverse[codepoint],
            token != nil,
            into: <<>>,
            do: token

      assert byte_size(expected) >= expected_count
      assert apply(codec, :encode_discard, [codepoints]) == {:ok, expected}
    end
  end

  defp normalized_rows do
    ["profile,token,unicode,origin" | rows] =
      @mapping_path |> File.read!() |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [profile, token, codepoint, origin] = String.split(row, ",", parts: 4)

      %{
        profile: String.to_existing_atom(profile),
        token: Base.decode16!(token, case: :mixed),
        codepoint: String.to_integer(codepoint, 16),
        origin: mapping_origin(origin)
      }
    end)
  end

  defp mapping_origin("ascii_identity"), do: :ascii_identity
  defp mapping_origin("source_vietnamese"), do: :source_vietnamese

  defp token_map(rows), do: Map.new(rows, &{&1.token, &1.codepoint})

  defp expected_profile(source_rows, profile) do
    identity = Map.new(0..127, &{<<&1>>, &1})

    Enum.reduce(source_rows, identity, fn row, mapping ->
      Map.put(mapping, Map.fetch!(row.tokens, profile), row.codepoint)
    end)
  end

  defp parse_source_rows(source) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^\S+\s+(\d+(?:,\d+)*)\s+(\d+(?:,\d+)*)\s+(\d+(?:,\d+)*)\s+(\d+(?:,\d+)*)\s+(.+?)\s*$/,
             line
           ) do
        [_, ascii, ansi, mac, email, description] ->
          [
            %{
              tokens: %{
                ascii: decimal_token(ascii),
                ansi: decimal_token(ansi),
                mac: decimal_token(mac),
                email: decimal_token(email)
              },
              codepoint: description_codepoint(description)
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp decimal_token(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
    |> :erlang.list_to_binary()
  end

  defp description_codepoint(description) do
    [base | modifiers] = String.split(description)

    case {base, modifiers} do
      {"D", ["bar"]} ->
        0x0110

      {"d", ["bar"]} ->
        0x0111

      {<<letter>>, marks} ->
        combining = Enum.map(marks, &combining_mark/1)
        [codepoint] = :unicode.characters_to_nfc_list([letter | combining])
        codepoint
    end
  end

  defp combining_mark("acute"), do: 0x0301
  defp combining_mark("grave"), do: 0x0300
  defp combining_mark("hook-above"), do: 0x0309
  defp combining_mark("tilde"), do: 0x0303
  defp combining_mark("dot-below"), do: 0x0323
  defp combining_mark("breve"), do: 0x0306
  defp combining_mark("circumflex"), do: 0x0302
  defp combining_mark("horn"), do: 0x031B

  defp reference_decode(input, decode), do: reference_decode(input, decode, 0, [])
  defp reference_decode(<<>>, _decode, _offset, result), do: {:ok, :lists.reverse(result)}

  defp reference_decode(input, decode, offset, result) do
    candidates = for size <- 1..min(3, byte_size(input)), do: binary_part(input, 0, size)

    case candidates |> Enum.reverse() |> Enum.find(&Map.has_key?(decode, &1)) do
      nil ->
        <<invalid, _::binary>> = input
        {:error, :invalid_sequence, offset, <<invalid>>}

      token ->
        size = byte_size(token)
        <<_::binary-size(size), rest::binary>> = input
        reference_decode(rest, decode, offset + size, [Map.fetch!(decode, token) | result])
    end
  end

  defp proper_prefixes(rows) do
    tokens = MapSet.new(Enum.map(rows, & &1.token))

    rows
    |> Enum.flat_map(fn %{token: token} ->
      for size <- 1..(byte_size(token) - 1)//1, do: binary_part(token, 0, size)
    end)
    |> Enum.filter(&MapSet.member?(tokens, &1))
    |> Enum.uniq()
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
