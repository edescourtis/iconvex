defmodule Iconvex.Specs.TeXMathEncodingsTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.TeXLiveOMLCMMI10ToUnicode2026, as: OML
  alias Iconvex.Specs.TeXLiveOMSCMSY10ToUnicode2026, as: OMS

  @source_dir Path.expand("../priv/sources/tex-live-oml-oms-2026", __DIR__)

  @profiles [
    {OML, :oml_cmmi10, "oml_tounicode.csv"},
    {OMS, :oms_cmsy10, "oms_tounicode.csv"}
  ]

  test "source transcriptions are complete, contiguous, bijective, and digest-pinned" do
    expected_digests = %{
      "oml_tounicode.csv" => "dba7cd27dcc30d1d2a6f455bc0a0e9ddb6f75bed6b6ff67e16486a728d6c1852",
      "oms_tounicode.csv" => "45659590cd5bdda7b353979362601bfb70e8980522e78a3e13eb0e3476c477ef"
    }

    for {_module, _profile, filename} <- @profiles do
      rows = source_rows(filename)

      assert Enum.map(rows, &elem(&1, 0)) == Enum.to_list(0x00..0x7F)
      assert rows |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 128
      assert sha256(Path.join(@source_dir, filename)) == expected_digests[filename]
    end
  end

  test "profiles expose the audited identities and provenance" do
    assert Code.ensure_loaded?(OML)
    assert Code.ensure_loaded?(OMS)

    assert OML.canonical_name() == "TEX-LIVE-OML-CMMI10-TOUNICODE-2026"
    assert OML.aliases() == ["OML", "OML-ENCODING", "TEX-MATH-ITALIC"]
    assert OML.codec_id() == :tex_live_oml_cmmi10_tounicode_2026
    assert OML.unit_bits() == 7

    assert OMS.canonical_name() == "TEX-LIVE-OMS-CMSY10-TOUNICODE-2026"
    assert OMS.aliases() == ["OMS", "OMS-ENCODING", "TEX-MATH-SYMBOLS"]
    assert OMS.codec_id() == :tex_live_oms_cmsy10_tounicode_2026
    assert OMS.unit_bits() == 7

    for {module, profile, filename} <- @profiles do
      assert module.table_sha256() == sha256(Path.join(@source_dir, filename))
      assert module.source_commit() == "7c8574ae28a5b257f7b92cc1e5e317255644e40d"

      assert module.source_artifact_sha256() ==
               "e49bef156ccaf6f6e3616103a5ff6b0363aedb33ad06623fe63f6ccc41e2b72e"

      assert module.profile() == profile
    end
  end

  test "all 128 assigned bytes decode and encode exactly through both APIs" do
    for {module, _profile, filename} <- @profiles do
      rows = source_rows(filename)
      bytes = rows |> Enum.map(&elem(&1, 0)) |> :erlang.list_to_binary()
      codepoints = Enum.map(rows, &elem(&1, 1))
      utf8 = List.to_string(codepoints)

      assert module.decode(bytes) == {:ok, codepoints}
      assert module.encode(codepoints) == {:ok, bytes}
      assert module.decode_to_utf8(bytes) == {:ok, utf8}
      assert module.encode_from_utf8(utf8) == {:ok, bytes}

      for {byte, codepoint} <- rows do
        assert module.decode(<<byte>>) == {:ok, [codepoint]}
        assert module.encode([codepoint]) == {:ok, <<byte>>}
      end
    end
  end

  test "every non-OML/OMS octet is rejected at the exact byte offset" do
    for {module, _profile, _filename} <- @profiles,
        byte <- 0x80..0xFF do
      assert module.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
      assert module.decode(<<0x00, byte>>) == {:error, :invalid_sequence, 1, <<byte>>}

      assert module.decode_to_utf8(<<0x00, byte>>) ==
               {:error, :invalid_sequence, 1, <<byte>>}
    end
  end

  test "discard and substitution policies remain linear and exact" do
    for {module, _profile, filename} <- @profiles do
      rows = source_rows(filename)
      [{0x00, first}, {0x01, second} | _] = rows
      {0x30, replacement} = Enum.at(rows, 0x30)

      assert module.decode_discard(<<0x00, 0x80, 0x01, 0xFF>>) == {:ok, [first, second]}
      assert module.encode_discard([first, 0x10FFFF, second]) == {:ok, <<0x00, 0x01>>}

      assert module.encode_substitute([first, 0x10FFFF, second], fn 0x10FFFF ->
               [replacement]
             end) ==
               {:ok, <<0x00, 0x30, 0x01>>}

      assert module.encode([first, 0x10FFFF]) ==
               {:error, :unrepresentable_character, 0x10FFFF}
    end
  end

  test "stateless chunk callbacks preserve policy behavior without pending state" do
    for {module, _profile, filename} <- @profiles do
      rows = source_rows(filename)
      [{0x00, first}, {0x01, second} | _] = rows
      {0x30, replacement} = Enum.at(rows, 0x30)

      assert module.decode_chunk(<<0x00, 0x01>>, false) == {:ok, [first, second], <<>>}

      assert module.decode_chunk(<<0x80>>, true) ==
               {:error, :invalid_sequence, 0, <<0x80>>}

      assert module.encode_chunk([first, second], false, :error) ==
               {:ok, <<0x00, 0x01>>, []}

      assert module.encode_chunk([first, 0x10FFFF, second], true, :discard) ==
               {:ok, <<0x00, 0x01>>, []}

      assert module.encode_chunk(
               [first, 0x10FFFF, second],
               true,
               {:replace, fn _ -> [replacement] end}
             ) == {:ok, <<0x00, 0x30, 0x01>>, []}
    end
  end

  test "UTF-8 fast encoding reports malformed input with byte-precise offsets" do
    for {module, _profile, _filename} <- @profiles do
      assert module.encode_from_utf8(<<0x2603::utf8>>) ==
               {:error, :unrepresentable_character, 0x2603}

      assert module.encode_from_utf8(<<?A, 0xFF>>) ==
               {:decode_error, :invalid_sequence, 1, <<0xFF>>}

      assert module.encode_from_utf8(<<?A, 0xE2, 0x82>>) ==
               {:decode_error, :incomplete_sequence, 1, <<0xE2, 0x82>>}

      assert module.encode_from_utf8(<<0x2603::utf8, 0xFF>>) ==
               {:error, :unrepresentable_character, 0x2603}
    end
  end

  test "normalization-sensitive targets remain exact and are never aliased" do
    assert OML.decode(<<0x0A, 0x60, 0x6C>>) == {:ok, [0x2126, 0x2113, ?l]}
    assert OML.encode([0x2126, 0x2113, ?l]) == {:ok, <<0x0A, 0x60, 0x6C>>}
    assert OML.encode([0x03A9]) == {:error, :unrepresentable_character, 0x03A9}

    assert OMS.decode(<<0x3C, 0x52, 0x3D, 0x49>>) == {:ok, [0x211C, ?R, 0x2111, ?I]}
    assert OMS.encode([0x211C, ?R, 0x2111, ?I]) == {:ok, <<0x3C, 0x52, 0x3D, 0x49>>}
  end

  test "metadata preserves upstream license caveats without vendored source blobs" do
    metadata = File.read!(Path.join(@source_dir, "SOURCE_METADATA.md"))

    for statement <- [
          "LGPL-2.1-or-later",
          "LaTeX Project Public License version 1.3c",
          "Knuth License",
          "mixed upstream licensing",
          "No upstream source blob is redistributed",
          "Not shipped: any upstream `.dtx`, `.mf`, `.tpf`, PDF"
        ] do
      assert metadata =~ statement
    end
  end

  defp source_rows(filename) do
    [_header | rows] =
      @source_dir
      |> Path.join(filename)
      |> File.read!()
      |> String.split("\n", trim: true)

    Enum.map(rows, fn row ->
      [byte, codepoint] = String.split(row, ",")
      {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
    end)
  end

  defp sha256(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
