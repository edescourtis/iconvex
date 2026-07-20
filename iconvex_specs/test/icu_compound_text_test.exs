defmodule Iconvex.Specs.ICUCompoundTextTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUCompoundText

  @source_directory Path.expand("../priv/sources/icu-78.3-compound-text", __DIR__)

  @states %{
    1 => {<<0x1B, "-M">>, "icu-internal-compound-s1.ucm"},
    2 => {<<0x1B, "-F">>, "icu-internal-compound-s2.ucm"},
    3 => {<<0x1B, "-G">>, "icu-internal-compound-s3.ucm"},
    4 => {<<0x1B, "$)A">>, "icu-internal-compound-d1.ucm"},
    5 => {<<0x1B, "$)B">>, "icu-internal-compound-d2.ucm"},
    6 => {<<0x1B, "$)C">>, "icu-internal-compound-d3.ucm"},
    7 => {<<0x1B, "$)D">>, "icu-internal-compound-d4.ucm"},
    8 => {<<0x1B, "$)G">>, "icu-internal-compound-d5.ucm"},
    9 => {<<0x1B, "$)H">>, "icu-internal-compound-d6.ucm"},
    10 => {<<0x1B, "$)I">>, "icu-internal-compound-d7.ucm"},
    11 => {<<0x1B, "%G">>, "icu-internal-compound-t.ucm"},
    12 => {<<0x1B, "-L">>, "ibm-915_P100-1995.ucm"},
    13 => {<<0x1B, "-H">>, "ibm-916_P100-1995.ucm"},
    14 => {<<0x1B, "-D">>, "ibm-914_P100-1995.ucm"},
    15 => {<<0x1B, "-T">>, "ibm-874_P100-1995.ucm"},
    16 => {<<0x1B, "-B">>, "ibm-912_P100-1995.ucm"},
    17 => {<<0x1B, "-C">>, "ibm-913_P100-2000.ucm"},
    18 => {<<0x1B, "-_">>, "iso-8859_14-1998.ucm"},
    19 => {<<0x1B, "-b">>, "ibm-923_P100-1998.ucm"}
  }

  @source_hashes %{
    "ucnv_ct.cpp" => "4213cffee014539a69844de4194a00b19e7180a50dfe53a251306f30ebdb1c99",
    "icu-internal-compound-s1.ucm" =>
      "437ba5f7f7da47dc7b7edf3bcd692e19021f631c4fe9187215909e8d4cace1c6",
    "icu-internal-compound-s2.ucm" =>
      "26ffa17dede705f8f5394d80840fa872202946cb8503683fd929ea27b8cd23fa",
    "icu-internal-compound-s3.ucm" =>
      "8e3f57e3da24655658068a723ca5d959adaa2c50eda92c4db585d1865fe46329",
    "icu-internal-compound-d1.ucm" =>
      "6d5f55e133064ccbadcc7b89687d4dc26b80e437e8e4e6cd86d965c24ff034fd",
    "icu-internal-compound-d2.ucm" =>
      "73b5d4b34b5a95e3cbd90daf84c14be0c1f9cd97ba38f1dadb0488f184241abe",
    "icu-internal-compound-d3.ucm" =>
      "2f60172826d84b1dd6f7629d4eb5e1a489d7a41f3233228f2ef87350a3861b3b",
    "icu-internal-compound-d4.ucm" =>
      "f37e38307eeb639224ca19f21e37d347ef4b990d314fe1096ee27a2370161862",
    "icu-internal-compound-d5.ucm" =>
      "bb810c97c45773bacc11b2b4193e5c12ae3677f1816f0fb48da8afc5af56e58d",
    "icu-internal-compound-d6.ucm" =>
      "9c0ebe5e810f70c1da523fc27533db9eff2363c9b95debcb1207a8b06c8b73ee",
    "icu-internal-compound-d7.ucm" =>
      "7583980ad898def70d762c84f8f0cf05a669129469a1414191ae49ea1fedf6c6",
    "icu-internal-compound-t.ucm" =>
      "408198adce2355d51ec9b64b1a780f809a3317d0e3fe6e94ec2a069167a947af",
    "ibm-915_P100-1995.ucm" => "0dd1b9dbe2345aa647df12bbc790f5169e32e3c125b86adca1d81a6baa41ef3e",
    "ibm-916_P100-1995.ucm" => "6eede279fe214f5083eaffb27bdfdcfcacbebadb11b376e746a41fffb83df684",
    "ibm-914_P100-1995.ucm" => "48fc704bb597b0a7ee50265d1120b11aec82509ed7f4b09f813ff9299eebcf9b",
    "ibm-874_P100-1995.ucm" => "3eec8ad5c4404ddee361bd0e5964998ba741df8fa219297a1d149e4397d0935c",
    "ibm-912_P100-1995.ucm" => "f93db72a786d8af2924178cc8423e79c4b6219f4ea9ff66523adf1cb4194ece0",
    "ibm-913_P100-2000.ucm" => "4914424df9ada96ae17eae68754f19701d7c1f6124693fc5b7889843119a8da2",
    "iso-8859_14-1998.ucm" => "d219441ef482ce23f96c9542e79c94b6b932915c766cf05b6c18e14c361095f8",
    "ibm-923_P100-1998.ucm" => "6808d8015c0c7b979192d3a9438d214ef2e77f377f8b960bb5b235ae2085b895",
    "convrtrs.txt" => "29340d12f664416d51c9b9d8d34e6364a10b456e668eb3155fd5f59beaf743e9"
  }

  test "registers the X11, ICU, and Java names" do
    for name <- ["x11-compound-text", "COMPOUND_TEXT", "x-compound-text"] do
      assert {:ok, %{canonical: "x11-compound-text"}} = Iconvex.Registry.resolve(name)
    end
  end

  test "matches the canonical ICU escape selection and retains the active state" do
    codepoints = [
      0x03A9,
      0x03B1,
      0x0416,
      0x0417,
      0x00E9,
      ?A,
      0x3042,
      0x3044,
      0x3046,
      0x4E2D,
      0xAC00,
      0x1F600
    ]

    assert ICUCompoundText.encode(codepoints) ==
             {:ok,
              <<0x1B, "-F", 0xD9, 0xE1, 0x1B, "-L", 0xB6, 0xB7, 0x1B, "-A", 0xE9, ?A, 0x1B, "$)B",
                0xA4, 0xA2, 0xA4, 0xA4, 0xA4, 0xA6, 0xC3, 0xE6, 0x1B, "$)C", 0xB0, 0xA1>>}

    # ICU 78.3 silently omits unrepresentable characters even with STOP callbacks.
    assert ICUCompoundText.encode([0x1F600, ?A]) == {:ok, <<?A>>}
  end

  test "decodes every reachable row from all nineteen exact subconverters" do
    for {_state, {escape, filename}} <- @states do
      maps = directional_maps(source(filename))

      for {bytes, codepoint} <- maps.decode,
          :binary.match(bytes, <<0x1B>>) == :nomatch do
        assert ICUCompoundText.decode(escape <> bytes) == {:ok, [codepoint]},
               "#{filename} failed #{inspect(bytes)}"
      end
    end
  end

  @tag timeout: 120_000
  test "matches one ICU call over all 1,112,064 Unicode scalar values" do
    codepoints = scalar_codepoints()
    assert {:ok, encoded} = ICUCompoundText.encode(codepoints)
    assert byte_size(encoded) == 77_619
    assert sha256(encoded) == "7f872ccc6bbf554ce54e52f18f9d8025390a645bff02b0694bab35679538581d"

    assert {:ok, decoded} = ICUCompoundText.decode(encoded)
    assert length(decoded) == 20_195
    utf32 = for codepoint <- decoded, into: <<>>, do: <<codepoint::32-big>>
    assert sha256(utf32) == "5cf86c8b27a86835aef2a7b989cc1fc4163e0520523f930b8e7d8c47dac4b6e0"
  end

  test "decodes direct Latin-1, switches all escape forms, and reports malformed escapes" do
    assert ICUCompoundText.decode(<<0, ?A, 0xA0, 0xFF>>) == {:ok, [0, ?A, 0xA0, 0xFF]}

    assert ICUCompoundText.decode(<<0x1B, "-F", 0xD9, 0xE1, 0x1B, "-A", 0xE9>>) ==
             {:ok, [0x03A9, 0x03B1, 0x00E9]}

    assert ICUCompoundText.decode(<<0x1B, ?$>>) ==
             {:error, :incomplete_sequence, 0, <<0x1B, ?$>>}

    assert ICUCompoundText.decode(<<0x1B, "-Z">>) ==
             {:error, :invalid_sequence, 0, <<0x1B, ?-, ?Z>>}
  end

  test "pins the ICU state machine and all nineteen mapping sources" do
    assert ICUCompoundText.release() == "78.3"
    assert ICUCompoundText.revision() == "21d1eb0f306e1141c10931e914dfc038c06121da"

    assert ICUCompoundText.aggregate_sha256() ==
             "29154f92a16b2da89bf446193c987e5fb91d1b8a0e4791667e4dddcf29c99c66"

    assert Map.new(ICUCompoundText.sources()) == @source_hashes

    for {filename, expected_sha} <- @source_hashes do
      assert sha256(File.read!(source(filename))) == expected_sha
    end
  end

  defp scalar_codepoints do
    for <<codepoint::32-big <- File.read!("test/fixtures/all-unicode-scalars.utf32be")>>,
      do: codepoint
  end

  defp directional_maps(path) do
    rows =
      path
      |> File.stream!()
      |> Enum.flat_map(fn line ->
        case Regex.run(
               ~r/^<U([0-9A-Fa-f]+)>\s+((?:\\x[0-9A-Fa-f]{2})+)(?:\s+\|(\d))?/,
               line,
               capture: :all_but_first
             ) do
          [unicode, encoded, precision] -> [row(unicode, encoded, precision)]
          [unicode, encoded] -> [row(unicode, encoded, "0")]
          nil -> []
        end
      end)

    decode =
      rows
      |> Enum.filter(&(&1.precision in [0, 3]))
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn row, acc -> Map.put_new(acc, row.bytes, row.codepoint) end)

    %{decode: decode}
  end

  defp row(unicode, encoded, precision) do
    bytes =
      Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    %{
      codepoint: String.to_integer(unicode, 16),
      bytes: bytes,
      precision: String.to_integer(precision)
    }
  end

  defp precision_priority(%{precision: 0}), do: 0
  defp precision_priority(%{precision: precision}) when precision in [3, 4], do: 1
  defp precision_priority(%{precision: 1}), do: 2
  defp source(filename), do: Path.join(@source_directory, filename)
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
