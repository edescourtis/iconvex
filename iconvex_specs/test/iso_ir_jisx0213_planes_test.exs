defmodule Iconvex.Specs.ISOIRJISX0213PlanesTest do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/iso-ir-jisx0213/mappings.txt", __DIR__)
  @manifest Path.expand("../priv/iso_ir_jisx0213_manifest.etf", __DIR__)
  @registrations [
    {228, ["JIS-X-0213-2000-PLANE-1"]},
    {229, ["JIS-X-0213-2000-PLANE-2", "JIS-X-0213-2004-PLANE-2"]},
    {233, ["JIS-X-0213-2004-PLANE-1"]}
  ]

  test "registers both versions of the JIS X 0213 planes" do
    for {registration, aliases} <- @registrations do
      canonical = "ISO-IR-#{registration}"

      for name <- [canonical | aliases] do
        assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
      end
    end
  end

  test "pins the official sheets and independently documented 2000-to-2004 delta" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()

    assert manifest.normalized_sha256 == sha256(File.read!(@source))

    assert manifest.gnu_jisx0213_sha256 ==
             "44a434978af14a99cf30eb89c915f8dff05d006a7bf636b329d48ccdb88b6531"

    assert manifest.cpython_2000_delta_sha256 ==
             "b8db3dce0aac8d433ea5f3ba057547c52727b9e3391971b278c9eb4cb61a7aca"

    assert Enum.map(manifest.encodings, & &1.registration_sha256) == [
             "5cf9fc6a3abdeda88b3c2de98e33ecca6cb58c9c15b42e3f950dd358ccdd5eda",
             "ed763e79de0c71156c67fef58469913c53ff80c2a63019e4fb7a67d52486e9dc",
             "28a57cecf24042569ebfc4892fb9e8479e33bb8ca7e43c83b4339cc8ea6e8abf"
           ]
  end

  @tag timeout: 120_000
  test "exhausts all 26,508 graphic positions across the three registrations" do
    mappings = parse_mappings()

    for {registration, _aliases} <- @registrations,
        first <- 0x21..0x7E,
        second <- 0x21..0x7E do
      expected =
        case Map.fetch(mappings[registration], <<first, second>>) do
          {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
          :error -> {:error, :invalid_sequence}
        end

      assert normalized(Iconvex.convert(<<first, second>>, "ISO-IR-#{registration}", "UTF-8")) ==
               expected
    end
  end

  test "round-trips every canonical single- and multi-code-point mapping" do
    mappings = parse_mappings()

    for {registration, _aliases} <- @registrations do
      encode =
        Enum.reduce(mappings[registration], %{}, fn {bytes, codepoints}, result ->
          Map.put_new(result, codepoints, bytes)
        end)

      for {codepoints, bytes} <- encode do
        assert Iconvex.convert(List.to_string(codepoints), "UTF-8", "ISO-IR-#{registration}") ==
                 {:ok, bytes}
      end
    end
  end

  @tag timeout: 120_000
  test "checks singleton encoding over every Unicode scalar" do
    mappings = parse_mappings()

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    for {registration, _aliases} <- @registrations do
      expected =
        mappings[registration]
        |> Enum.filter(fn {_bytes, codepoints} -> length(codepoints) == 1 end)
        |> Enum.reduce(%{}, fn {bytes, [codepoint]}, result ->
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

  test "captures the normative JIS X 0213:2000 versus 2004 changes" do
    assert Iconvex.convert(<<0x2E, 0x21>>, "ISO-IR-228", "UTF-8") |> normalized() ==
             {:error, :invalid_sequence}

    assert Iconvex.convert(<<0x2E, 0x21>>, "ISO-IR-233", "UTF-8") ==
             {:ok, <<0x4FF1::utf8>>}

    assert Iconvex.convert(<<0x7D, 0x3B>>, "ISO-IR-229", "UTF-8") == {:ok, <<0x9B1D::utf8>>}
  end

  defp parse_mappings do
    @source
    |> File.read!()
    |> String.split(~r/^\[([0-9]+)\]\s*$/m, include_captures: true, trim: true)
    |> Enum.drop(1)
    |> Enum.chunk_every(2)
    |> Map.new(fn [header, rows] ->
      registration =
        header |> String.trim_leading("[") |> String.trim_trailing("]") |> String.to_integer()

      mapping =
        rows
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Map.new(fn row ->
          [encoded, unicode] = String.split(row, "\t")
          bytes = Base.decode16!(encoded)

          codepoints =
            unicode |> String.split(",") |> Enum.map(&String.to_integer(&1, 16))

          {bytes, codepoints}
        end)

      {registration, mapping}
    end)
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %{kind: kind}}), do: {:error, kind}
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
