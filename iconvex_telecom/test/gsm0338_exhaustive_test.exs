defmodule Iconvex.Telecom.GSM0338ExhaustiveTest do
  use ExUnit.Case, async: true

  alias Iconvex.Telecom.GSM0338.{Engine, Tables}

  @locking_ids [0, 1] ++ Enum.to_list(3..13)
  @single_ids Enum.to_list(0..13)

  test "the generated data is pinned to the audited reference source" do
    assert Tables.source() == %{
             android_repository_commit: "1cdfff555f4a21f71ccc978290e2e212e2f8b168",
             file_sha256: "af28d761a4efbdafe6e5c65b23d0b3ace20164454f39db03dc796246772387ba",
             specification: "3GPP TS 23.038 Release 19 / ETSI TS 123 038 V19.0.0"
           }
  end

  test "all 137 ICU round-trip mappings agree in both directions" do
    fixture = File.read!("test/fixtures/gsm-03.38-2009.ucm")

    assert :crypto.hash(:sha256, fixture) |> Base.encode16(case: :lower) ==
             "e53e04bb4a022713276ff63702fd404681f70288b43eab14e467636a9c5edcba"

    mappings =
      Regex.scan(~r/^<U([0-9A-F]+)> ((?:\\x[0-9A-F]{2})+) \|0$/m, fixture,
        capture: :all_but_first
      )

    assert length(mappings) == 137

    for [hex_codepoint, byte_source] <- mappings do
      codepoint = String.to_integer(hex_codepoint, 16)

      bytes =
        Regex.scan(~r/\\x([0-9A-F]{2})/, byte_source, capture: :all_but_first)
        |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
        |> :erlang.list_to_binary()

      assert Engine.decode(bytes, 0, 0) == {:ok, [codepoint]}
      assert Engine.encode([codepoint], 0, 0) == {:ok, bytes}
    end
  end

  test "every table has all 128 positions and the current corrected cells" do
    for locking_id <- @locking_ids do
      assert tuple_size(Tables.locking(locking_id)) == 128
    end

    assert Tables.locking(2) == nil

    for single_id <- @single_ids do
      assert tuple_size(Tables.single_shift(single_id)) == 128
    end

    assert elem(Tables.locking(7), 0x24) == 0x0CA1
    assert elem(Tables.single_shift(11), 0x24) == 0x0BEE
    assert elem(Tables.single_shift(12), 0x22) == 0x0C6C
    assert elem(Tables.single_shift(12), 0x23) == 0x0C6D
  end

  test "all 1,651 non-escape locking cells decode exactly" do
    for locking_id <- @locking_ids,
        byte <- 0..127,
        byte != 0x1B do
      expected = elem(Tables.locking(locking_id), byte)

      assert Engine.decode(<<byte>>, locking_id, 0) == {:ok, [expected]},
             "locking=#{locking_id}, byte=#{byte}"
    end
  end

  test "all 23,296 extension cells decode for every valid independent pair" do
    for locking_id <- @locking_ids,
        single_id <- @single_ids,
        byte <- 0..127 do
      expected =
        cond do
          byte == 0x1B ->
            [0x20]

          codepoint = elem(Tables.single_shift(single_id), byte) ->
            [codepoint]

          true ->
            [0x20, elem(Tables.locking(locking_id), byte)]
        end

      input = <<0x1B, byte>>

      assert Engine.decode(input, locking_id, single_id) == {:ok, expected},
             "locking=#{locking_id}, single=#{single_id}, byte=#{byte}"

      assert Engine.decode_to_utf8(input, locking_id, single_id) ==
               {:ok, List.to_string(expected)},
             "UTF-8 locking=#{locking_id}, single=#{single_id}, byte=#{byte}"
    end
  end

  test "every representable character round-trips for all 182 table pairs" do
    for locking_id <- @locking_ids, single_id <- @single_ids do
      locking = Tables.locking_encode(locking_id)
      single = Tables.single_encode(single_id)
      codepoints = (Map.keys(locking) ++ Map.keys(single)) |> Enum.uniq()

      for codepoint <- codepoints do
        assert {:ok, bytes} = Engine.encode([codepoint], locking_id, single_id)
        assert Engine.decode(bytes, locking_id, single_id) == {:ok, [codepoint]}

        assert Engine.encode_from_utf8(<<codepoint::utf8>>, locking_id, single_id) ==
                 {:ok, bytes}
      end
    end
  end

  test "locking characters always take the canonical one-septet path" do
    for locking_id <- @locking_ids, single_id <- @single_ids do
      for {codepoint, byte} <- Tables.locking_encode(locking_id) do
        assert Engine.encode([codepoint], locking_id, single_id) == {:ok, <<byte>>}
      end
    end
  end

  test "every high-bit octet is invalid and discard stays linear" do
    for byte <- 0x80..0xFF do
      assert Engine.decode(<<byte>>, 0, 0) == {:error, :invalid_sequence, 0, <<byte>>}
    end

    input = :binary.copy(<<0xFF, ?A>>, 100_000) <> <<0x1B>>

    assert Engine.decode_discard(input, 0, 0) ==
             {:ok, List.duplicate(?A, 100_000) ++ [0x20]}
  end
end
