defmodule Iconvex.Specs.CDC612DisplayCodeTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{CDC612DisplayCode63, CDC612DisplayCode64, Packed}

  @source_path Path.expand(
                 "../priv/sources/cdc-display-code/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf",
                 __DIR__
               )
  @source_sha256 "86980dc43cd81f8666241277c56ab1f7c07f11b6c900c0a5d73a77cee4421be6"

  @canonical64 for(
                 codepoint <- 0x00..0x1F,
                 do: {codepoint, [0o76, codepoint + 0o40]}
               ) ++
                 [
                   {0x20, [0o55]},
                   {?!, [0o66]},
                   {?", [0o64]},
                   {?#, [0o60]},
                   {?$, [0o53]},
                   {?%, [0o63]},
                   {?&, [0o67]},
                   {?', [0o70]},
                   {?\(, [0o51]},
                   {?\), [0o52]},
                   {?*, [0o47]},
                   {?+, [0o45]},
                   {?,, [0o56]},
                   {?-, [0o46]},
                   {?., [0o57]},
                   {?/, [0o50]}
                 ] ++
                 for(
                   codepoint <- ?0..?9,
                   do: {codepoint, [codepoint - ?0 + 0o33]}
                 ) ++
                 [
                   {?:, [0o74, 0o04]},
                   {?;, [0o77]},
                   {?<, [0o72]},
                   {?=, [0o54]},
                   {?>, [0o73]},
                   {??, [0o71]},
                   {?@, [0o74, 0o01]}
                 ] ++
                 for(
                   codepoint <- ?A..?Z,
                   do: {codepoint, [codepoint - ?A + 0o01]}
                 ) ++
                 [
                   {?[, [0o61]},
                   {?\\, [0o75]},
                   {?], [0o62]},
                   {?^, [0o74, 0o02]},
                   {?_, [0o65]},
                   {?`, [0o74, 0o07]}
                 ] ++
                 for(
                   codepoint <- ?a..?z,
                   do: {codepoint, [0o76, codepoint - ?a + 0o01]}
                 ) ++
                 [
                   {?{, [0o76, 0o33]},
                   {?|, [0o76, 0o34]},
                   {?}, [0o76, 0o35]},
                   {?~, [0o76, 0o36]},
                   {0x7F, [0o76, 0o37]}
                 ]

  @escaped64 Map.new(@canonical64, fn {codepoint, units} -> {List.to_tuple(units), codepoint} end)

  @direct64 @canonical64
            |> Enum.filter(fn {_codepoint, units} -> length(units) == 1 end)
            |> Map.new(fn {codepoint, [unit]} -> {unit, codepoint} end)
            |> Map.put(0o00, ?:)

  test "RED: pins the complete official 6/12 grammar and ASCII conversion table" do
    assert sha256(File.read!(@source_path)) == @source_sha256
    assert CDC612DisplayCode64.source_pages() == [165, 167, 168, 169, 170, 171]

    assert CDC612DisplayCode64.printed_source_pages() == [
             "A-1",
             "A-3",
             "A-4",
             "A-5",
             "A-6",
             "A-7"
           ]

    assert CDC612DisplayCode64.unit_bits() == 6
    assert CDC612DisplayCode64.variable_units_per_character() == 1..2
  end

  test "all 128 ASCII values match table A-2 in both directions" do
    assert length(@canonical64) == 128
    assert @canonical64 |> Enum.map(&elem(&1, 0)) |> Enum.sort() == Enum.to_list(0x00..0x7F)

    for {codepoint, units} <- @canonical64 do
      binary = :binary.list_to_bin(units)
      assert CDC612DisplayCode64.encode([codepoint]) == {:ok, binary}
      assert CDC612DisplayCode64.decode(binary) == {:ok, [codepoint]}
    end

    all_units = @canonical64 |> Enum.flat_map(&elem(&1, 1)) |> :binary.list_to_bin()
    assert CDC612DisplayCode64.encode(Enum.to_list(0x00..0x7F)) == {:ok, all_units}
    assert CDC612DisplayCode64.decode(all_units) == {:ok, Enum.to_list(0x00..0x7F)}
    assert CDC612DisplayCode64.decode(<<0o00>>) == {:ok, ~c":"}
  end

  test "every two-unit input agrees with an independent 6/12 grammar oracle" do
    for first <- 0..63, second <- 0..63 do
      input = <<first, second>>
      assert CDC612DisplayCode64.decode(input) == oracle_decode(input, :set64)
    end

    for unit <- 64..255 do
      assert CDC612DisplayCode64.decode(<<unit>>) ==
               {:error, :invalid_sequence, 0, <<unit>>}

      assert CDC612DisplayCode64.decode(<<0o01, unit>>) ==
               {:error, :invalid_sequence, 1, <<unit>>}
    end
  end

  test "63-character mode preserves the documented colon/percent anomaly" do
    for {codepoint, units64} <- @canonical64, codepoint not in [?%, ?:] do
      binary = :binary.list_to_bin(units64)
      assert CDC612DisplayCode63.encode([codepoint]) == {:ok, binary}
      assert CDC612DisplayCode63.decode(binary) == {:ok, [codepoint]}
    end

    assert CDC612DisplayCode63.encode([?:]) == {:ok, <<0o63>>}
    assert CDC612DisplayCode63.decode(<<0o63>>) == {:ok, ~c":"}
    assert CDC612DisplayCode63.decode(<<0o74, 0o04>>) == {:ok, ~c":"}
    assert CDC612DisplayCode63.encode([?%]) == {:error, :unrepresentable_character, ?%}
    assert CDC612DisplayCode63.decode(<<0o00>>) == {:error, :invalid_sequence, 0, <<0o00>>}

    for first <- 0..63, second <- 0..63 do
      input = <<first, second>>
      assert CDC612DisplayCode63.decode(input) == oracle_decode(input, :set63)
    end
  end

  test "escape errors, truncation, discard, and direct UTF-8 paths are exact" do
    for invalid <- [0o00, 0o03, 0o05, 0o06] ++ Enum.to_list(0o10..0o77) do
      assert CDC612DisplayCode64.decode(<<0o74, invalid>>) ==
               {:error, :invalid_sequence, 0, <<0o74, invalid>>}
    end

    assert CDC612DisplayCode64.decode(<<0o76, 0o00>>) ==
             {:error, :invalid_sequence, 0, <<0o76, 0o00>>}

    assert CDC612DisplayCode64.decode(<<0o74>>) ==
             {:error, :incomplete_sequence, 0, <<0o74>>}

    assert CDC612DisplayCode64.decode(<<0o01, 0o76>>) ==
             {:error, :incomplete_sequence, 1, <<0o76>>}

    assert CDC612DisplayCode64.decode_discard(<<0o01, 0o74, 0o03, 0xFF, 0o02>>) ==
             {:ok, ~c"AB"}

    assert CDC612DisplayCode64.encode_discard([?A, 0x2603, ?a]) ==
             {:ok, <<0o01, 0o76, 0o01>>}

    assert CDC612DisplayCode64.encode_from_utf8("Aa:\0") ==
             {:ok, <<0o01, 0o76, 0o01, 0o74, 0o04, 0o76, 0o40>>}

    assert CDC612DisplayCode64.decode_to_utf8(<<0o01, 0o76, 0o01, 0o74, 0o04, 0o76, 0o40>>) ==
             {:ok, "Aa:\0"}

    assert CDC612DisplayCode64.encode_from_utf8("☃") ==
             {:error, :unrepresentable_character, 0x2603}

    assert CDC612DisplayCode64.encode_from_utf8(<<?A, 0xFF>>) ==
             {:decode_error, :invalid_sequence, 1, <<0xFF>>}
  end

  test "registry and exact packed transports preserve 6/12 unit boundaries" do
    assert Iconvex.canonical_name("CDC-6-12-DISPLAY-CODE") ==
             {:ok, "CDC-6-12-DISPLAY-CODE-64"}

    assert Iconvex.canonical_name("CDC-6-12-DISPLAY-CODE-63") ==
             {:ok, "CDC-6-12-DISPLAY-CODE-63"}

    units = <<0o01, 0o76, 0o01, 0o74, 0o04, 0o76, 0o40>>

    for order <- [:msb, :lsb] do
      assert {:ok, packed} = Packed.encode_from_utf8("Aa:\0", "CDC-6-12-DISPLAY-CODE", order)
      assert Packed.decode_to_utf8(packed, "CDC-6-12-DISPLAY-CODE", order) == {:ok, "Aa:\0"}

      assert bit_size_or_declared(packed) == 42
    end

    assert Packed.encode_from_utf8("Aa:\0", "CDC-6-12-DISPLAY-CODE", :msb) ==
             {:ok, for(<<unit <- units>>, into: <<>>, do: <<unit::6>>)}

    assert {:error,
            %Iconvex.Error{
              kind: :incomplete_sequence,
              encoding: "CDC-6-12-DISPLAY-CODE-64",
              offset: 0,
              sequence: <<0o74>>
            }} = Packed.decode_to_utf8(<<0o74::6>>, "CDC-6-12-DISPLAY-CODE", :msb)
  end

  defp oracle_decode(input, set), do: oracle_decode(input, set, 0, [])
  defp oracle_decode(<<>>, _set, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp oracle_decode(<<prefix>>, _set, offset, _acc) when prefix in [0o74, 0o76],
    do: {:error, :incomplete_sequence, offset, <<prefix>>}

  defp oracle_decode(<<prefix, unit, rest::binary>>, set, offset, acc)
       when prefix in [0o74, 0o76] do
    case @escaped64 do
      %{{^prefix, ^unit} => codepoint} ->
        oracle_decode(rest, set, offset + 2, [codepoint | acc])

      _ ->
        {:error, :invalid_sequence, offset, <<prefix, unit>>}
    end
  end

  defp oracle_decode(<<unit, rest::binary>>, set, offset, acc) do
    direct =
      if set == :set64, do: @direct64, else: @direct64 |> Map.delete(0o00) |> Map.put(0o63, ?:)

    case direct do
      %{^unit => codepoint} -> oracle_decode(rest, set, offset + 1, [codepoint | acc])
      _ -> {:error, :invalid_sequence, offset, <<unit>>}
    end
  end

  defp bit_size_or_declared(%Iconvex.Packed.LSB{bit_size: bit_size}), do: bit_size
  defp bit_size_or_declared(bitstring), do: bit_size(bitstring)
  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
