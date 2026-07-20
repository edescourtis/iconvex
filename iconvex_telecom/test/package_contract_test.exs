defmodule Iconvex.Telecom.PackageContractTest do
  use ExUnit.Case, async: false

  @languages ~w(TURKISH SPANISH PORTUGUESE BENGALI GUJARATI HINDI KANNADA MALAYALAM ORIYA PUNJABI TAMIL TELUGU URDU)
  @locking_languages @languages -- ["SPANISH"]

  @readme Path.expand("../README.md", __DIR__)
  @changelog Path.expand("../CHANGELOG.md", __DIR__)

  test "RED: packaged README links Iconvex through its durable package page" do
    readme = File.read!(@readme)

    assert readme =~ "[Iconvex](https://hex.pm/packages/iconvex)"
    refute readme =~ "](../iconvex)"
  end

  test "RED: release documents state the current full-stack cardinality" do
    assert File.read!(@readme) =~ "2,093 unique canonical"
    assert File.read!(@changelog) =~ "2,093-codec full-stack registry"
  end

  test "consumer package excludes development corpora" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for development_directory <- ~w(test bench tools) do
      refute development_directory in package_files
    end
  end

  test "publishes base, national profile, locking-only, and single-shift-only codecs" do
    expected =
      [
        "AIS6",
        "CCIR476",
        "GSM0338",
        "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3",
        "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2",
        "ITA1",
        "ITA2",
        "ITA2-S2",
        "ITA2-US-TTY",
        "ITA3",
        "ITA4",
        "ITU-T-T.50-IRV",
        "MORSE-ITU-M1677",
        "MTK-2",
        "SIM-ALPHA-IDENTIFIER",
        "TBCD"
      ] ++
        Enum.map(@languages, &"GSM0338-#{&1}") ++
        Enum.map(@locking_languages, &"GSM0338-LOCKING-#{&1}") ++
        Enum.map(@languages, &"GSM0338-SINGLE-#{&1}")

    assert Iconvex.Telecom.encodings() == Enum.sort(expected)
    assert length(Iconvex.Telecom.codecs()) == 54

    documentation = File.read!("SUPPORTED_ENCODINGS.md")
    Enum.each(expected, &assert(documentation =~ "`#{&1}`"))
  end

  test "generated inventory is an exact runtime canonical-name and alias snapshot" do
    inventory =
      "SUPPORTED_CODEC_INVENTORY.csv"
      |> File.read!()
      |> String.split("\n", trim: true)
      |> tl()
      |> Enum.map(fn line ->
        [canonical, aliases, module, stateful] = String.split(line, ",", parts: 4)

        %{
          "canonical" => canonical,
          "aliases" => aliases,
          "module" => module,
          "stateful" => stateful
        }
      end)

    codecs = Iconvex.Telecom.codecs()

    assert length(inventory) == 54
    assert Enum.map(inventory, & &1["canonical"]) == Iconvex.Telecom.encodings()

    for {row, codec} <- Enum.zip(inventory, Enum.sort_by(codecs, & &1.canonical_name())) do
      assert row["canonical"] == codec.canonical_name()
      assert row["module"] == inspect(codec)
      assert row["stateful"] == to_string(codec.stateful?())
      assert String.split(row["aliases"], "|", trim: true) == Enum.sort(codec.aliases())
    end
  end

  test "registers all named codecs with Iconvex" do
    assert Iconvex.canonical_name("gsm-03.38") == {:ok, "GSM0338"}
    assert Iconvex.canonical_name("gsm0338-turkish") == {:ok, "GSM0338-TURKISH"}

    assert Iconvex.convert(<<0x04, 0x1B, 0x47>>, "GSM0338-TURKISH", "UTF-8") ==
             {:ok, "€Ğ"}

    assert Iconvex.convert("ç", "UTF-8", "GSM0338-SINGLE-SPANISH") ==
             {:ok, <<0x1B, 0x09>>}

    assert Iconvex.convert("12345", "UTF-8", "TBCD") == {:ok, <<0x21, 0x43, 0xF5>>}

    assert Iconvex.convert(<<0x81, 2, 0x08, 0x41, 0x90>>, "SIM-ALPHA", "UTF-8") ==
             {:ok, "AА"}
  end

  test "all 39 GSM wrappers are wired to their declared table pair" do
    input = <<0x00, 0x04, 0x1B, 0x09, 0x1B, 0x65, ?A, ?z>>

    for spec <- Iconvex.Telecom.Codecs.specs() do
      assert spec.module.canonical_name() == spec.canonical

      assert spec.module.decode(input) ==
               Iconvex.Telecom.GSM0338.Engine.decode(
                 input,
                 spec.locking,
                 spec.single_shift
               )

      assert spec.module.decode_to_utf8(input) ==
               Iconvex.Telecom.GSM0338.Engine.decode_to_utf8(
                 input,
                 spec.locking,
                 spec.single_shift
               )
    end
  end

  test "application stop removes its codecs and restart restores them" do
    assert :ok = Application.stop(:iconvex_telecom)
    assert Iconvex.canonical_name("GSM0338") == :error

    assert {:ok, started} = Application.ensure_all_started(:iconvex_telecom)
    assert :iconvex_telecom in started
    assert Iconvex.canonical_name("GSM0338") == {:ok, "GSM0338"}
  end
end
