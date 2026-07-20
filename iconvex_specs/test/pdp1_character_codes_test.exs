defmodule Iconvex.Specs.PDP1CharacterCodesTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.PDP1Concise1960InitialLower, as: Concise1960Lower
  alias Iconvex.Specs.PDP1Concise1960InitialUpper, as: Concise1960Upper
  alias Iconvex.Specs.PDP1ConciseFIODEC1963InitialLower, as: Concise1963Lower
  alias Iconvex.Specs.PDP1ConciseFIODEC1963InitialUpper, as: Concise1963Upper
  alias Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialLower, as: FIODEC1963Lower
  alias Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialUpper, as: FIODEC1963Upper
  alias Iconvex.Specs.PDP1FridenFPC81960InitialLower, as: Friden1960Lower
  alias Iconvex.Specs.PDP1FridenFPC81960InitialUpper, as: Friden1960Upper

  @source_dir Path.expand("../priv/sources/pdp1-character-codes", __DIR__)

  @concise_1960_graphics [
    {0o00, ?\s, ?\s},
    {0o01, ?1, ?'},
    {0o02, ?2, ?@},
    {0o03, ?3, ?#},
    {0o04, ?4, ?=},
    {0o05, ?5, ?%},
    {0o06, ?6, 0x00A2},
    {0o07, ?7, ??},
    {0o10, ?8, ?*},
    {0o11, ?9, ?(},
    {0o20, ?0, ?)},
    {0o21, ?/, ?:},
    {0o22, ?s, ?S},
    {0o23, ?t, ?T},
    {0o24, ?u, ?U},
    {0o25, ?v, ?V},
    {0o26, ?w, ?W},
    {0o27, ?x, ?X},
    {0o30, ?y, ?Y},
    {0o31, ?z, ?Z},
    {0o33, ?,, ?,},
    {0o36, 0x09, 0x09},
    {0o40, ?-, ?"},
    {0o41, ?j, ?J},
    {0o42, ?k, ?K},
    {0o43, ?l, ?L},
    {0o44, ?m, ?M},
    {0o45, ?n, ?N},
    {0o46, ?o, ?O},
    {0o47, ?p, ?P},
    {0o50, ?q, ?Q},
    {0o51, ?r, ?R},
    {0o53, ?$, ?-},
    {0o60, ?&, ?;},
    {0o61, ?a, ?A},
    {0o62, ?b, ?B},
    {0o63, ?c, ?C},
    {0o64, ?d, ?D},
    {0o65, ?e, ?E},
    {0o66, ?f, ?F},
    {0o67, ?g, ?G},
    {0o70, ?h, ?H},
    {0o71, ?i, ?I},
    {0o73, ?., ?.},
    {0o77, 0x0D, 0x0D}
  ]

  @friden_1960_units [
    {0o020, 0o00},
    {0o001, 0o01},
    {0o002, 0o02},
    {0o023, 0o03},
    {0o004, 0o04},
    {0o025, 0o05},
    {0o026, 0o06},
    {0o007, 0o07},
    {0o010, 0o10},
    {0o031, 0o11},
    {0o040, 0o20},
    {0o061, 0o21},
    {0o062, 0o22},
    {0o043, 0o23},
    {0o064, 0o24},
    {0o045, 0o25},
    {0o046, 0o26},
    {0o067, 0o27},
    {0o070, 0o30},
    {0o051, 0o31},
    {0o073, 0o33},
    {0o076, 0o36},
    {0o100, 0o40},
    {0o121, 0o41},
    {0o122, 0o42},
    {0o103, 0o43},
    {0o124, 0o44},
    {0o105, 0o45},
    {0o106, 0o46},
    {0o127, 0o47},
    {0o130, 0o50},
    {0o111, 0o51},
    {0o133, 0o53},
    {0o160, 0o60},
    {0o141, 0o61},
    {0o142, 0o62},
    {0o163, 0o63},
    {0o144, 0o64},
    {0o165, 0o65},
    {0o166, 0o66},
    {0o147, 0o67},
    {0o150, 0o70},
    {0o171, 0o71},
    {0o153, 0o73},
    {0o200, 0o77}
  ]

  @concise_1963_graphics [
    {0o00, ?\s, ?\s},
    {0o01, ?1, ?"},
    {0o02, ?2, ?'},
    {0o03, ?3, ?~},
    {0o04, ?4, 0x2283},
    {0o05, ?5, 0x2228},
    {0o06, ?6, 0x2227},
    {0o07, ?7, ?<},
    {0o10, ?8, ?>},
    {0o11, ?9, 0x2191},
    {0o20, ?0, 0x2192},
    {0o21, ?/, ??},
    {0o22, ?s, ?S},
    {0o23, ?t, ?T},
    {0o24, ?u, ?U},
    {0o25, ?v, ?V},
    {0o26, ?w, ?W},
    {0o27, ?x, ?X},
    {0o30, ?y, ?Y},
    {0o31, ?z, ?Z},
    {0o33, ?,, ?=},
    {0o36, 0x09, 0x09},
    {0o40, 0x00B7, ?_},
    {0o41, ?j, ?J},
    {0o42, ?k, ?K},
    {0o43, ?l, ?L},
    {0o44, ?m, ?M},
    {0o45, ?n, ?N},
    {0o46, ?o, ?O},
    {0o47, ?p, ?P},
    {0o50, ?q, ?Q},
    {0o51, ?r, ?R},
    {0o54, ?-, ?+},
    {0o55, ?), ?]},
    {0o56, 0x0305, ?|},
    {0o57, ?(, ?[},
    {0o61, ?a, ?A},
    {0o62, ?b, ?B},
    {0o63, ?c, ?C},
    {0o64, ?d, ?D},
    {0o65, ?e, ?E},
    {0o66, ?f, ?F},
    {0o67, ?g, ?G},
    {0o70, ?h, ?H},
    {0o71, ?i, ?I},
    {0o73, ?., 0x00D7},
    {0o75, 0x08, 0x08},
    {0o77, 0x0D, 0x0D}
  ]

  @fiodec_1963_units [
    {0o200, 0o00},
    {0o001, 0o01},
    {0o002, 0o02},
    {0o203, 0o03},
    {0o004, 0o04},
    {0o205, 0o05},
    {0o206, 0o06},
    {0o007, 0o07},
    {0o010, 0o10},
    {0o211, 0o11},
    {0o020, 0o20},
    {0o221, 0o21},
    {0o222, 0o22},
    {0o023, 0o23},
    {0o224, 0o24},
    {0o025, 0o25},
    {0o026, 0o26},
    {0o227, 0o27},
    {0o230, 0o30},
    {0o031, 0o31},
    {0o233, 0o33},
    {0o236, 0o36},
    {0o040, 0o40},
    {0o241, 0o41},
    {0o242, 0o42},
    {0o043, 0o43},
    {0o244, 0o44},
    {0o045, 0o45},
    {0o046, 0o46},
    {0o247, 0o47},
    {0o250, 0o50},
    {0o051, 0o51},
    {0o054, 0o54},
    {0o255, 0o55},
    {0o256, 0o56},
    {0o057, 0o57},
    {0o061, 0o61},
    {0o062, 0o62},
    {0o263, 0o63},
    {0o064, 0o64},
    {0o265, 0o65},
    {0o266, 0o66},
    {0o067, 0o67},
    {0o070, 0o70},
    {0o271, 0o71},
    {0o073, 0o73},
    {0o075, 0o75},
    {0o277, 0o77}
  ]

  test "primary-source transcriptions and metadata are pinned" do
    source_1960 = Path.join(@source_dir, "pdp1_1960.csv")
    source_1963 = Path.join(@source_dir, "pdp1_fiodec_1963.csv")
    metadata = Path.join(@source_dir, "SOURCE_METADATA.md")

    assert File.exists?(source_1960)
    assert File.exists?(source_1963)
    assert File.exists?(metadata)

    assert Concise1960Lower.source_sha256() ==
             "7495a32bca4897aa54fb0b073149303b66a17bf2f96371e930aa300594c38ab6"

    assert Concise1963Lower.source_sha256() ==
             "8490b72962584f30c9dc7f3a9684ba3eeb79c7d5530b78ee371a6efe098a8f21"

    assert Concise1960Lower.table_sha256() == sha256(source_1960)
    assert Concise1963Lower.table_sha256() == sha256(source_1963)
    assert source_1960 |> File.stream!() |> Enum.count() == 49
    assert source_1963 |> File.stream!() |> Enum.count() == 56
    refute metadata |> File.read!() |> String.contains?("permission unknown")
  end

  test "all 64 concise 1960 patterns are exhaustively classified in both initial states" do
    assert_all_units(Concise1960Lower, Concise1960Upper, @concise_1960_graphics, [
      0o72,
      0o74
    ])
  end

  test "all 256 Friden FPC-8 rows are exhaustively classified and odd parity is enforced" do
    assert Enum.all?(Enum.map(@friden_1960_units, &elem(&1, 0)), &odd_parity?/1)
    expected = remap_units(@concise_1960_graphics, @friden_1960_units)
    assert_all_units(Friden1960Lower, Friden1960Upper, expected, [0o172, 0o174, 0o177])
  end

  test "all 64 concise 1963 patterns are exhaustively classified in both initial states" do
    assert_all_units(Concise1963Lower, Concise1963Upper, @concise_1963_graphics, [
      0o34,
      0o35,
      0o72,
      0o74
    ])
  end

  test "all 256 FIO-DEC rows are classified including tape feed, stop, delete and parity" do
    assert Enum.all?(Enum.map(@fiodec_1963_units, &elem(&1, 0)), &odd_parity?/1)
    expected = remap_units(@concise_1963_graphics, @fiodec_1963_units)

    assert_all_units(FIODEC1963Lower, FIODEC1963Upper, expected, [
      0o000,
      0o013,
      0o100,
      0o272,
      0o274
    ])
  end

  test "state transitions and physical-vs-concise space semantics are exact" do
    assert {:ok, ~c"aABb"} = Concise1960Lower.decode(<<0o61, 0o74, 0o61, 0o62, 0o72, 0o62>>)
    assert {:ok, ~c"Aa"} = Concise1960Upper.decode(<<0o61, 0o72, 0o61>>)
    assert {:ok, ~c"aA"} = Friden1960Lower.decode(<<0o141, 0o174, 0o141>>)
    assert {:ok, ~c"aA"} = Concise1963Lower.decode(<<0o61, 0o74, 0o61>>)
    assert {:ok, ~c"aA"} = FIODEC1963Lower.decode(<<0o061, 0o274, 0o061>>)
    assert {:ok, ~c" "} = Concise1963Lower.decode(<<0o00>>)
    assert {:ok, []} = FIODEC1963Lower.decode(<<0o000, 0o013, 0o100>>)
    assert {:ok, ~c" "} = FIODEC1963Lower.decode(<<0o200>>)
  end

  test "strict offsets and discard recovery retain case state at invalid units" do
    assert {:error, :invalid_sequence, 1, <<0o12>>} =
             Concise1963Lower.decode(<<0o74, 0o12, 0o61>>)

    assert {:ok, ~c"A"} = Concise1963Lower.decode_discard(<<0o74, 0o12, 0o61>>)

    assert {:error, :invalid_sequence, 1, <<0o60>>} =
             FIODEC1963Lower.decode(<<0o274, 0o60, 0o61>>)

    assert {:ok, ~c"A"} = FIODEC1963Lower.decode_discard(<<0o274, 0o60, 0o61>>)
  end

  test "encoding uses the current state and inserts only necessary shifts" do
    assert {:ok, <<0o61, 0o62, 0o74, 0o61, 0o62, 0o72, 0o61>>} =
             Concise1960Lower.encode(~c"abABa")

    assert {:ok, <<0o141, 0o142, 0o174, 0o141, 0o142, 0o172, 0o141>>} =
             Friden1960Lower.encode(~c"abABa")

    assert {:ok, <<0o61, 0o62, 0o74, 0o61, 0o62, 0o72, 0o61>>} =
             Concise1963Lower.encode(~c"abABa")

    assert {:ok, <<0o061, 0o062, 0o274, 0o061, 0o062, 0o272, 0o061>>} =
             FIODEC1963Lower.encode(~c"abABa")

    assert {:ok, <<0o40, 0o40>>} = Concise1960Lower.encode(~c"--")
    assert {:ok, <<0o53, 0o53>>} = Concise1960Upper.encode(~c"--")
  end

  test "discard and substitution preserve state across failures" do
    assert {:error, :unrepresentable_character, 0x1F642} =
             Concise1963Lower.encode([?a, 0x1F642, ?A])

    assert {:ok, <<0o61, 0o74, 0o61>>} =
             Concise1963Lower.encode_discard([?a, 0x1F642, ?A])

    assert {:ok, <<0o61, 0o01, 0o74, 0o61>>} =
             Concise1963Lower.encode_substitute([?a, 0x1F642, ?A], fn _ -> [?1] end)

    assert {:error, :unrepresentable_character, 0x1F642} =
             Concise1963Lower.encode_substitute([0x1F642], fn _ -> [0x1F642] end)
  end

  test "stateful stream callbacks match one-shot at every source and Unicode split" do
    for module <- [
          Concise1960Lower,
          Concise1960Upper,
          Friden1960Lower,
          Friden1960Upper,
          Concise1963Lower,
          Concise1963Upper,
          FIODEC1963Lower,
          FIODEC1963Upper
        ] do
      text = ~c"abABa09"
      {:ok, encoded} = module.encode(text)
      assert_stream_splits(module, encoded, text)
    end
  end

  test "direct UTF-8 fast paths preserve first-error ordering" do
    assert {:ok, "aA\u2283\u2228\u2227\u2192"} =
             Concise1963Lower.decode_to_utf8(<<0o61, 0o74, 0o61, 0o04, 0o05, 0o06, 0o20>>)

    assert {:ok, <<0o61, 0o74, 0o61, 0o04, 0o05, 0o06, 0o20>>} =
             Concise1963Lower.encode_from_utf8("aA\u2283\u2228\u2227\u2192")

    assert {:error, :unrepresentable_character, 0x1F642} =
             Concise1963Lower.encode_from_utf8("a🙂\xFF")

    assert {:decode_error, :invalid_sequence, 1, <<0xFF>>} =
             Concise1963Lower.encode_from_utf8("a\xFF")
  end

  test "every Unicode scalar is accepted exactly when one of the source states maps it" do
    for {module, graphics} <- [
          {Concise1960Lower, @concise_1960_graphics},
          {Concise1960Upper, @concise_1960_graphics},
          {Friden1960Lower, @concise_1960_graphics},
          {Friden1960Upper, @concise_1960_graphics},
          {Concise1963Lower, @concise_1963_graphics},
          {Concise1963Upper, @concise_1963_graphics},
          {FIODEC1963Lower, @concise_1963_graphics},
          {FIODEC1963Upper, @concise_1963_graphics}
        ] do
      supported = graphics |> Enum.flat_map(fn {_, l, u} -> [l, u] end) |> MapSet.new()

      for scalar <- unicode_scalars() do
        case module.encode([scalar]) do
          {:ok, bytes} ->
            assert MapSet.member?(supported, scalar)
            assert {:ok, [^scalar]} = module.decode(bytes)

          {:error, :unrepresentable_character, ^scalar} ->
            refute MapSet.member?(supported, scalar)
        end
      end
    end
  end

  test "profile identity, transport width and source citations stay explicit" do
    assert Concise1960Lower.unit_bits() == 6
    assert Concise1963Lower.unit_bits() == 6
    assert Friden1960Lower.unit_bits() == 8
    assert FIODEC1963Lower.unit_bits() == 8
    assert Concise1960Lower.stateful?()
    assert FIODEC1963Lower.stateful?()
    assert Concise1960Lower.source_pages() == [12, 17]
    assert Concise1960Lower.printed_source_pages() == ["20-21", "30-31"]
    assert Concise1963Lower.source_pages() == [24, 69, 70]
    assert Concise1963Lower.printed_source_pages() == ["23", "68-69"]
    refute "PDP-1" in Concise1960Upper.aliases()
    refute "FIODEC" in FIODEC1963Upper.aliases()
  end

  defp assert_all_units(lower_module, upper_module, graphics, actions) do
    lower = Map.new(graphics, fn {unit, lower, _upper} -> {unit, lower} end)
    upper = Map.new(graphics, fn {unit, _lower, upper} -> {unit, upper} end)
    assigned = MapSet.new(Map.keys(lower) ++ actions)
    max_unit = if lower_module.unit_bits() == 6, do: 0x3F, else: 0xFF

    for unit <- 0..max_unit do
      cond do
        Map.has_key?(lower, unit) ->
          assert {:ok, [Map.fetch!(lower, unit)]} == lower_module.decode(<<unit>>)
          assert {:ok, [Map.fetch!(upper, unit)]} == upper_module.decode(<<unit>>)
          assert {:ok, <<unit>>} == lower_module.encode([Map.fetch!(lower, unit)])
          assert {:ok, <<unit>>} == upper_module.encode([Map.fetch!(upper, unit)])

        MapSet.member?(assigned, unit) ->
          assert {:ok, []} == lower_module.decode(<<unit>>)
          assert {:ok, []} == upper_module.decode(<<unit>>)

        true ->
          assert {:error, :invalid_sequence, 0, <<unit>>} == lower_module.decode(<<unit>>)
          assert {:error, :invalid_sequence, 0, <<unit>>} == upper_module.decode(<<unit>>)
      end
    end
  end

  defp remap_units(graphics, physical_units) do
    by_concise = Map.new(graphics, fn {unit, lower, upper} -> {unit, {lower, upper}} end)

    Enum.map(physical_units, fn {physical, concise} ->
      {lower, upper} = Map.fetch!(by_concise, concise)
      {physical, lower, upper}
    end)
  end

  defp assert_stream_splits(module, encoded, expected) do
    for split <- 0..byte_size(encoded) do
      <<left::binary-size(split), right::binary>> = encoded
      state0 = module.stream_decoder_init()
      assert {:ok, left_decoded, state1, <<>>} = module.decode_chunk(left, state0, false)
      assert {:ok, right_decoded, _state2, <<>>} = module.decode_chunk(right, state1, true)
      assert left_decoded ++ right_decoded == expected
    end

    for split <- 0..length(expected) do
      {left, right} = Enum.split(expected, split)
      state0 = module.stream_encoder_init()
      assert {:ok, left_encoded, state1, []} = module.encode_chunk(left, state0, false, :error)

      assert {:ok, right_encoded, _state2, []} =
               module.encode_chunk(right, state1, true, :error)

      assert left_encoded <> right_encoded == encoded
    end
  end

  defp unicode_scalars do
    Stream.concat(0..0xD7FF, 0xE000..0x10FFFF)
  end

  defp odd_parity?(byte), do: byte |> Integer.digits(2) |> Enum.sum() |> rem(2) == 1

  defp sha256(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end
