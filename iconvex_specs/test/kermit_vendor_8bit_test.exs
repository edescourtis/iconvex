defmodule Iconvex.Specs.KermitVendor8BitTest do
  use ExUnit.Case, async: false

  @kermit Path.expand(
            "../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
            __DIR__
          )

  @chunk_units 4_096

  @profiles [
    {"BULGARIA-PC", ["CP856-BULGARIAN", "DATECS-CP856"], "u_cp856", 0x80},
    {"MAZOVIA", ["MAZOVIA-PC", "CP667"], "u_mazovia", 0x80},
    {"QNX-CONSOLE", ["QNX-PC-GRAPHICS"], "u_qnxgrph", 0x80},
    {"DG-INTERNATIONAL", ["DATA-GENERAL-INTERNATIONAL"], "u_dgi", 0xA0},
    {"KERMIT-DG-LINEDRAWING", ["DG-LINEDRAWING"], "u_dgline", :source},
    {"KERMIT-DG-WORDPROCESSING", ["DG-WORDPROCESSING"], "u_dgword", :source},
    {"KERMIT-HP-MATH-TECHNICAL", ["HP-MATH-TECHNICAL"], "u_hpmath", :source},
    {"KERMIT-SNI-BRACKETS", ["SNI-BRACKETS"], "u_snibrack", :source},
    {"KERMIT-SNI-EURO", ["SNI-EURO"], "u_snieuro", :source},
    {"KERMIT-SNI-FACET", ["SNI-FACET"], "u_snifacet", :source},
    {"KERMIT-SNI-IBM", ["SNI-IBM"], "u_sniibm", :source}
  ]

  @terminal_profiles Enum.filter(@profiles, &(elem(&1, 3) == :source))

  test "RED: vendor profiles decode every octet exactly from the pinned Kermit tables" do
    source = File.read!(@kermit)

    for {encoding, _aliases, table_name, table_offset} <- @profiles do
      %{table: table} = kermit_table(source, table_name, table_offset)

      for byte <- 0x00..0xFF do
        case elem(table, byte) do
          nil ->
            assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 0}} =
                     Iconvex.convert(<<byte>>, encoding, "UTF-8")

          codepoint ->
            assert Iconvex.convert(<<byte>>, encoding, "UTF-32BE") ==
                     {:ok, <<codepoint::unsigned-big-32>>}
        end
      end
    end
  end

  test "each vendor profile encodes its complete canonical inverse" do
    source = File.read!(@kermit)

    for {encoding, _aliases, table_name, table_offset} <- @profiles do
      %{table: table} = kermit_table(source, table_name, table_offset)

      for {codepoint, byte} <- canonical_inverse(table) do
        assert Iconvex.convert(<<codepoint::unsigned-big-32>>, "UTF-32BE", encoding) ==
                 {:ok, <<byte>>}
      end

      assert {:error, %Iconvex.Error{kind: :unrepresentable_character}} =
               Iconvex.convert(<<0x10FFFF::unsigned-big-32>>, "UTF-32BE", encoding)
    end
  end

  test "aliases and Hungarian ISO-IR-86 identity are exposed without ambiguity" do
    for {canonical, aliases, _table_name, _table_offset} <- @profiles,
        alias_name <- aliases do
      assert Iconvex.canonical_name(alias_name) == {:ok, canonical}
    end

    assert Iconvex.canonical_name("HUNGARIAN") == {:ok, "MSZ_7795.3"}
    assert Iconvex.canonical_name("ISO-IR-86") == {:ok, "MSZ_7795.3"}

    for byte <- 0x00..0x7F do
      expected = Iconvex.Specs.RFC1345.decode("MSZ_7795.3", <<byte>>)

      expected_result =
        case expected do
          {:ok, [codepoint]} -> {:ok, <<codepoint::unsigned-big-32>>}
          {:error, _kind, _offset, _rest} -> :unreachable
        end

      assert Iconvex.convert(<<byte>>, "HUNGARIAN", "UTF-32BE") == expected_result
    end
  end

  test "near-match identities and historically disputed cells stay distinct" do
    source = File.read!(@kermit)
    %{table: cp437} = kermit_table(source, "u_cp437", 0x80)
    %{table: mazovia} = kermit_table(source, "u_mazovia", 0x80)
    %{table: qnx} = kermit_table(source, "u_qnxgrph", 0x80)
    %{table: bulgaria} = kermit_table(source, "u_cp856", 0x80)
    %{table: dgi} = kermit_table(source, "u_dgi", 0xA0)

    assert table_difference(mazovia, cp437) == 17
    assert table_difference(qnx, cp437) == 3
    assert table_difference(bulgaria, cp437) == 76

    assert elem(qnx, 0xE0) == 0x221D
    assert elem(qnx, 0xEE) == 0x2208
    assert elem(qnx, 0xFE) == 0x25AE

    assert elem(mazovia, 0x86) == 0x0105
    assert elem(mazovia, 0xA7) == 0x017C
    assert elem(bulgaria, 0x80) == 0x0410
    assert elem(bulgaria, 0xBF) == 0x044F
    assert elem(dgi, 0xD7) == 0x0276
    assert Enum.count(Tuple.to_list(dgi), &is_nil/1) == 4

    # IBM's registered CP856 is Hebrew; the Bulgarian name is deliberately
    # qualified so installing this package never hijacks plain CP856.
    refute Iconvex.canonical_name("CP856") == {:ok, "BULGARIA-PC"}
  end

  test "native direct paths preserve offsets, policies, malformed UTF-8, and chunk boundaries" do
    source = File.read!(@kermit)

    assert length(@terminal_profiles) == 7

    for {encoding, _aliases, table_name, table_offset} <- @profiles do
      %{table: table} = kermit_table(source, table_name, table_offset)

      units =
        table
        |> canonical_inverse()
        |> Enum.sort_by(fn {_codepoint, byte} -> byte end)

      repeats = div(@chunk_units, length(units)) + 1

      encoded =
        units
        |> Enum.map(fn {_codepoint, byte} -> byte end)
        |> :erlang.list_to_binary()
        |> :binary.copy(repeats)

      utf8 =
        units
        |> Enum.map(fn {codepoint, _byte} -> <<codepoint::utf8>> end)
        |> IO.iodata_to_binary()
        |> :binary.copy(repeats)

      assert byte_size(encoded) > @chunk_units
      assert length(units) * repeats > @chunk_units

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}
    end

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
             Iconvex.convert(<<0x41, 0xDC>>, "DG-INTERNATIONAL", "UTF-8")

    assert Iconvex.convert(<<0x41, 0xDC, 0x42>>, "DG-INTERNATIONAL", "UTF-8", invalid: :discard) ==
             {:ok, "AB"}

    assert Iconvex.convert("A🙂B", "UTF-8", "MAZOVIA", unrepresentable: :discard) ==
             {:ok, "AB"}

    assert {:error, %Iconvex.Error{kind: :incomplete_sequence, offset: 1}} =
             Iconvex.convert(<<0x41, 0xC2>>, "UTF-8", "QNX-CONSOLE")

    assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
             Iconvex.convert(<<0x41, 0xFF>>, "UTF-8", "BULGARIA-PC")
  end

  test "all seven terminal subset headers drive the oracle and invalid policies preserve nonzero offsets" do
    source = File.read!(@kermit)

    assert length(@terminal_profiles) == 7

    for {encoding, _aliases, table_name, :source} <- @terminal_profiles do
      %{header_offset: header_offset, table: table, size: size} =
        kermit_table(source, table_name, :source)

      assert {size, header_offset} == {94, 33}

      inverse = canonical_inverse(table)
      invalid_byte = table |> Tuple.to_list() |> Enum.find_index(&is_nil/1)
      {codepoint, valid_byte} = Enum.find(inverse, fn {candidate, _byte} -> candidate > 0x7F end)
      utf8 = <<codepoint::utf8>>

      assert is_integer(invalid_byte)
      assert valid_byte != invalid_byte

      assert {:error,
              %Iconvex.Error{
                kind: :invalid_sequence,
                offset: 1,
                sequence: <<^invalid_byte>>
              }} =
               Iconvex.convert(
                 <<valid_byte, invalid_byte, valid_byte>>,
                 encoding,
                 "UTF-8"
               )

      assert Iconvex.convert(
               <<valid_byte, invalid_byte, valid_byte>>,
               encoding,
               "UTF-8",
               invalid: :discard
             ) == {:ok, utf8 <> utf8}

      assert {:error,
              %Iconvex.Error{
                kind: :invalid_sequence,
                offset: malformed_offset,
                sequence: <<0xFF>>
              }} = Iconvex.convert(utf8 <> <<0xFF>>, "UTF-8", encoding)

      assert malformed_offset == byte_size(utf8)
      assert malformed_offset > 0

      assert Iconvex.convert(
               utf8 <> <<0x10FFFF::utf8>> <> utf8,
               "UTF-8",
               encoding,
               unrepresentable: :discard
             ) == {:ok, <<valid_byte, valid_byte>>}
    end
  end

  test "the audited source revision is immutable" do
    assert sha256(@kermit) == "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"
  end

  defp kermit_table(source, name, table_offset) do
    source_without_comments = Regex.replace(~r|/\*.*?\*/|s, source, "")

    pattern =
      ~r/struct\s+x_to_unicode\s+#{Regex.escape(name)}\s*=\s*\{\s*(?<size>\d+)\s*,\s*(?<offset>\d+)\s*,(?<body>.*?)\n\};/s

    %{"body" => body, "offset" => offset_text, "size" => size_text} =
      Regex.named_captures(pattern, source_without_comments)

    header_offset = String.to_integer(offset_text)
    size = String.to_integer(size_text)
    offset = if table_offset == :source, do: header_offset, else: table_offset

    high =
      ~r/0x([0-9A-Fa-f]+)/
      |> Regex.scan(body, capture: :all_but_first)
      |> Enum.map(fn
        [replacement] when replacement in ["fffd", "FFFD"] -> nil
        [hex] -> String.to_integer(hex, 16)
      end)

    if length(high) != size do
      raise "#{name} header declares #{size} cells, parsed #{length(high)}"
    end

    table = List.to_tuple(for byte <- 0x00..0xFF, do: kermit_codepoint(byte, offset, high))
    %{header_offset: header_offset, offset: offset, size: size, table: table}
  end

  defp kermit_codepoint(byte, offset, _high) when byte < offset, do: byte

  defp kermit_codepoint(byte, offset, high) when byte < offset + length(high),
    do: Enum.at(high, byte - offset)

  defp kermit_codepoint(_byte, _offset, _high), do: nil

  defp canonical_inverse(table) do
    table
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
    |> Enum.reduce(%{}, fn {codepoint, byte}, acc -> Map.put_new(acc, codepoint, byte) end)
  end

  defp table_difference(left, right) do
    left
    |> Tuple.to_list()
    |> Enum.zip(Tuple.to_list(right))
    |> Enum.count(fn {a, b} -> a != b end)
  end

  defp sha256(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end
