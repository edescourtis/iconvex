defmodule Iconvex.Specs.KPS956697Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.KPS956697

  @source_directory Path.expand("../priv/sources/kps9566-97", __DIR__)

  @normalized Path.expand("../priv/sources/kps9566-97/mappings.txt", __DIR__)
  @current Path.expand("../priv/sources/unicode-misc/KPS9566.TXT", __DIR__)

  test "registers the ISO-IR graphic set and its EUC-KP transport separately" do
    for {canonical, aliases} <- [
          {"ISO-IR-202", ["ISOIR202", "ISO_202", "CSISO202KOREAN"]},
          {"KPS-9566-97", ["KPS9566-97", "KPS956697", "EUC-KP-97", "EUC-KP"]}
        ],
        name <- [canonical | aliases] do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins every primary source, the corrected normalized map, and the independent audit" do
    manifest = KPS956697.manifest()

    assert manifest.assigned_positions == 8_259
    assert manifest.direct_wg2_mappings == 8_176
    assert manifest.supplemented_positions == 83

    assert manifest.current_mapping_sha256 ==
             "2ac236ba8c299211b4e17bf8cef9547453413701d132bcc9f0a09de97a153327"

    assert manifest.normalized_sha256 ==
             "ded760ddb190222b33d66f6b6e556af8713604b7da18e7014d74d5b3ee6d0e3b"

    assert manifest.pike_revision == "4bf9adbd874894d2484de1664969de43e4206492"

    assert manifest.pike_sha256 ==
             "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860"

    assert Enum.map(manifest.sources, &{&1.file, &1.sha256}) == [
             {"kp2ks_ucs-v09.txt",
              "08f2d3879f259ef0660567c6e35efd65462d6b61344e9366936148edaa07ca71"},
             {"n2564.pdf", "d5812c238e71afa6520e01d60d5b76294a4d4b4ccb176f376ad2468d0c279759"},
             {"iso-ir-202.pdf",
              "a3a7ac70e9098fdc0e7974849149f61855cb93bf93449580e2b35e9ae7db3c98"},
             {"n2374.pdf", "480594cb57c258b2f3b2966e21d79b8ba08cc22adc7255c31cf0532aa40275bb"}
           ]

    for source <- manifest.sources do
      path = Path.join(@source_directory, source.file)
      assert sha256(File.read!(path)) == source.sha256
    end

    assert sha256(File.read!(@current)) == manifest.current_mapping_sha256
    assert sha256(File.read!(@normalized)) == manifest.normalized_sha256
  end

  test "covers all 8,259 registered characters and only registered positions" do
    mappings = mappings()
    assigned = assigned_positions()

    assert length(assigned) == 8_259
    assert Enum.count(assigned, fn {_bytes, codepoint} -> codepoint != nil end) == 8_176
    assert map_size(mappings) == 8_259
    assert MapSet.new(Map.keys(mappings)) == MapSet.new(Enum.map(assigned, &elem(&1, 0)))

    # The only actual repertoire changes between the two standards are explicit
    # in Unicode's KPS 9566-2003 source.  All other shared positions retain the
    # corrected modern Unicode value.
    current = current_mappings()
    assert mappings[<<0xA8, 0xA6>>] == 0x212A
    assert current[<<0xA8, 0xA6>>] == 0x20AC
    assert mappings[<<0xAC, 0xCF>>] == 0xF13A
    refute Map.has_key?(current, <<0xAC, 0xCF>>)

    assert Enum.all?(mappings, fn
             {<<0xA8, 0xA6>>, 0x212A} -> true
             {<<0xAC, 0xCF>>, 0xF13A} -> true
             {bytes, codepoint} -> current[bytes] == codepoint
           end)
  end

  @tag timeout: 120_000
  test "exhausts every two-byte input word for both transports" do
    [iso_ir, euc] = KPS956697.codecs()
    euc_expected = mappings()

    iso_expected =
      Map.new(euc_expected, fn {<<first, second>>, codepoint} ->
        {<<first - 0x80, second - 0x80>>, codepoint}
      end)

    for value <- 0..0xFFFF do
      bytes = <<value::16>>

      case Map.fetch(iso_expected, bytes) do
        {:ok, codepoint} -> assert iso_ir.decode(bytes) == {:ok, [codepoint]}
        :error -> assert match?({:error, _, _, _}, iso_ir.decode(bytes))
      end

      <<first, second>> = bytes

      cond do
        first <= 0x7F and second <= 0x7F ->
          assert euc.decode(bytes) == {:ok, [first, second]}

        Map.has_key?(euc_expected, bytes) ->
          assert euc.decode(bytes) == {:ok, [euc_expected[bytes]]}

        true ->
          assert match?({:error, _, _, _}, euc.decode(bytes))
      end
    end
  end

  test "distinguishes incomplete prefixes from malformed single bytes exhaustively" do
    [iso_ir, euc] = KPS956697.codecs()
    mappings = mappings()
    iso_leads = MapSet.new(mappings, fn {<<first, _second>>, _codepoint} -> first - 0x80 end)
    euc_leads = MapSet.new(mappings, fn {<<first, _second>>, _codepoint} -> first end)

    for byte <- 0..255 do
      iso_result = iso_ir.decode(<<byte>>)

      if MapSet.member?(iso_leads, byte),
        do: assert(match?({:error, :incomplete_sequence, 0, _}, iso_result)),
        else: assert(match?({:error, :invalid_sequence, 0, _}, iso_result))

      euc_result = euc.decode(<<byte>>)

      cond do
        byte <= 0x7F ->
          assert euc_result == {:ok, [byte]}

        MapSet.member?(euc_leads, byte) ->
          assert match?({:error, :incomplete_sequence, 0, _}, euc_result)

        true ->
          assert match?({:error, :invalid_sequence, 0, _}, euc_result)
      end
    end
  end

  test "round-trips the full registered repertoire in one conversion" do
    mappings = mappings() |> Enum.sort_by(fn {bytes, _codepoint} -> bytes end)
    unicode = mappings |> Enum.map(&elem(&1, 1)) |> List.to_string()
    euc_bytes = mappings |> Enum.map(&elem(&1, 0)) |> IO.iodata_to_binary()

    iso_bytes =
      mappings
      |> Enum.map(fn {<<first, second>>, _codepoint} -> <<first - 0x80, second - 0x80>> end)
      |> IO.iodata_to_binary()

    assert Iconvex.convert(euc_bytes, "KPS-9566-97", "UTF-8") == {:ok, unicode}
    assert Iconvex.convert(unicode, "UTF-8", "KPS-9566-97") == {:ok, euc_bytes}
    assert Iconvex.convert(iso_bytes, "ISO-IR-202", "UTF-8") == {:ok, unicode}
    assert Iconvex.convert(unicode, "UTF-8", "ISO-IR-202") == {:ok, iso_bytes}
  end

  @tag timeout: 120_000
  test "checks canonical encoding over every Unicode scalar" do
    mappings = mappings()

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    euc_encode = canonical_encode(mappings)

    euc_output =
      euc_encode
      |> Enum.sort()
      |> Enum.map(fn {_codepoint, bytes} -> bytes end)
      |> IO.iodata_to_binary()

    iso_output =
      euc_encode
      |> Enum.sort()
      |> Enum.map(fn {_codepoint, <<first, second>>} -> <<first - 0x80, second - 0x80>> end)
      |> IO.iodata_to_binary()

    assert Iconvex.convert(all_scalars, "UTF-8", "KPS-9566-97", unrepresentable: :discard) ==
             {:ok, IO.iodata_to_binary(Enum.to_list(0..127)) <> euc_output}

    assert Iconvex.convert(all_scalars, "UTF-8", "ISO-IR-202", unrepresentable: :discard) ==
             {:ok, iso_output}
  end

  test "keeps KPS-97 observably distinct from KPS-2003" do
    assert Iconvex.convert(<<0xA8, 0xA6>>, "KPS-9566-97", "UTF-8") ==
             {:ok, <<0x212A::utf8>>}

    assert Iconvex.convert(<<0xA8, 0xA6>>, "KPS-9566-2003", "UTF-8") ==
             {:ok, <<0x20AC::utf8>>}

    assert Iconvex.convert(<<0xAC, 0xCF>>, "KPS-9566-97", "UTF-8") ==
             {:ok, <<0xF13A::utf8>>}

    assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
             Iconvex.convert(<<0xAC, 0xCF>>, "KPS-9566-2003", "UTF-8")
  end

  defp mappings do
    @normalized
    |> File.read!()
    |> :binary.split("\n", [:global])
    |> Enum.reduce(%{}, fn line, result ->
      case :binary.split(line, "\t") do
        [encoded, unicode] when byte_size(encoded) == 4 ->
          Map.put(result, Base.decode16!(encoded), String.to_integer(unicode, 16))

        _ ->
          result
      end
    end)
  end

  defp assigned_positions do
    Path.join(@source_directory, "kp2ks_ucs-v09.txt")
    |> File.read!()
    |> :binary.split("\n", [:global])
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^[0-9]{2}\s+[0-9]{2}\s+([0-9A-F]{4})\s+(?:[0-9]{2}|--)\s+(?:[0-9]{2}|--)\s+(?:[0-9A-F]{4}|----)\s+([0-9A-F]{4,6}|----)(?:\s|$)/,
             line,
             capture: :all_but_first
           ) do
        [encoded, "----"] -> [{Base.decode16!(encoded), nil}]
        [encoded, unicode] -> [{Base.decode16!(encoded), String.to_integer(unicode, 16)}]
        nil -> []
      end
    end)
  end

  defp current_mappings do
    @current
    |> File.read!()
    |> :binary.split("\n", [:global])
    |> Enum.reduce(%{}, fn line, result ->
      case Regex.run(~r/^0x([0-9A-Fa-f]{4})\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
        [encoded, unicode] ->
          Map.put(result, Base.decode16!(encoded), String.to_integer(unicode, 16))

        nil ->
          result
      end
    end)
  end

  defp canonical_encode(mappings) do
    mappings
    |> Enum.sort_by(fn {bytes, _codepoint} -> bytes end)
    |> Enum.reduce(%{}, fn {bytes, codepoint}, result -> Map.put_new(result, codepoint, bytes) end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
