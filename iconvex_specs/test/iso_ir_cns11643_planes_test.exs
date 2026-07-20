defmodule Iconvex.Specs.ISOIRCNS11643PlanesTest do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/icu-data-archive/cns-11643-1992.ucm", __DIR__)
  @manifest Path.expand("../priv/iso_ir_cns11643_manifest.etf", __DIR__)
  @registrations [{171, 1}, {172, 2}, {183, 3}, {184, 4}, {185, 5}, {186, 6}, {187, 7}]

  test "registers every CNS 11643-1992 ISO-IR plane" do
    for {registration, plane} <- @registrations do
      canonical = "ISO-IR-#{registration}"

      for name <- [canonical, "CNS-11643-1992-PLANE-#{plane}"] do
        assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
      end
    end
  end

  test "pins all official ISO-IR sheets and the complete ICU mapping" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()

    assert manifest.mapping_sha256 == sha256(File.read!(@source))
    assert length(manifest.encodings) == 7

    assert Enum.map(manifest.encodings, & &1.registration_sha256) == [
             "34b607d97fe86c8f8533dfad0f0469026f5d33ec14127387d7941a92acd478c7",
             "a765ba6eac366a58ebfc72570723f4b6d6eb51f7bbe3399cee47712f29fe1c9c",
             "59bd313414239f9544d707e89e27efe3749c461fd99aea81fe3a603788c9f0fe",
             "a5b4aa297116b2f5499a02e0ac37b656a436b21aedd61a2695fb16a483b13bd9",
             "a04883c2d378b77a5b047e53f80bbb5ecbe6f603fde67c11f7399a1cd85891b2",
             "045da2b90ed0d3f8522253302e4b1396720ec49549076c0ebe667f4d28e096f7",
             "f7c80adf0495d8abf0227c092f7b762b1e604e2d872b2ffc2018c6b12decae83"
           ]
  end

  @tag timeout: 120_000
  test "exhausts all 61,852 registered graphic positions" do
    mappings = parse_mappings()

    for {registration, plane} <- @registrations,
        first <- 0x21..0x7E,
        second <- 0x21..0x7E do
      expected =
        case Map.fetch(mappings[plane], <<first, second>>) do
          {:ok, codepoint} -> {:ok, <<codepoint::utf8>>}
          :error -> {:error, :invalid_sequence}
        end

      assert normalized(Iconvex.convert(<<first, second>>, "ISO-IR-#{registration}", "UTF-8")) ==
               expected
    end
  end

  @tag timeout: 120_000
  test "checks strict encode mappings over every Unicode scalar" do
    mappings = parse_mappings()

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    for {registration, plane} <- @registrations do
      expected =
        mappings[plane]
        |> Enum.reduce(%{}, fn {bytes, codepoint}, result ->
          Map.put_new(result, codepoint, bytes)
        end)
        |> Enum.sort()
        |> Enum.map(fn {_codepoint, bytes} -> bytes end)
        |> IO.iodata_to_binary()

      assert Iconvex.convert(
               all_scalars,
               "UTF-8",
               "ISO-IR-#{registration}",
               unrepresentable: :discard
             ) == {:ok, expected}
    end
  end

  test "reports incomplete and structurally invalid graphic codes" do
    assert {:error, %{kind: :incomplete_sequence, offset: 0, sequence: <<0x21>>}} =
             Iconvex.convert(<<0x21>>, "ISO-IR-171", "UTF-8")

    assert {:error, %{kind: :invalid_sequence, offset: 0, sequence: <<0x20, 0x21>>}} =
             Iconvex.convert(<<0x20, 0x21>>, "ISO-IR-171", "UTF-8")
  end

  defp parse_mappings do
    initial = Map.new(1..7, &{&1, %{}})

    @source
    |> File.stream!()
    |> Enum.reduce(initial, fn line, result ->
      case Regex.run(
             ~r/^<U([0-9A-F]+)> \\x8([1-7])\\x([0-9A-F]{2})\\x([0-9A-F]{2}) \|0$/,
             String.trim(line),
             capture: :all_but_first
           ) do
        [unicode, plane, first, second] ->
          plane = String.to_integer(plane)
          bytes = <<String.to_integer(first, 16), String.to_integer(second, 16)>>
          codepoint = String.to_integer(unicode, 16)
          Map.update!(result, plane, &Map.put_new(&1, bytes, codepoint))

        nil ->
          result
      end
    end)
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %{kind: kind}}), do: {:error, kind}
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
