alias Iconvex.Telecom.{
  AIS6,
  CCIR476,
  IA5,
  ITA1,
  ITA2,
  ITA2S2,
  ITA2USTTY,
  ITA3,
  ITA4,
  Morse,
  MTK2,
  SIMAlphaIdentifier,
  TBCD
}

alias Iconvex.Telecom.AIS6.Armor, as: AIS6Armor
alias Iconvex.Telecom.AIS6.Packing, as: AIS6Packing
alias Iconvex.Telecom.CCIR476.Packing, as: CCIRPacking
alias Iconvex.Telecom.GSM0338.Packing, as: GSMPacking
alias Iconvex.Telecom.IA5.Packing, as: IA5Packing
alias Iconvex.Telecom.ITA1.Packing, as: ITA1Packing
alias Iconvex.Telecom.ITA2.Packing, as: ITA2Packing
alias Iconvex.Telecom.ITA3.Packing, as: ITA3Packing
alias Iconvex.Telecom.ITA4.Packing, as: ITA4Packing

iterations = 100_000
septets = :binary.copy("hellohello", 16)
{:ok, packed} = GSMPacking.pack(septets)
telegraph_utf8 = String.duplicate("HELLO 123 ", 16)
telegraph_codepoints = String.to_charlist(telegraph_utf8)
{:ok, ita2} = ITA2.encode(telegraph_codepoints)
{:ok, ita2_packed} = ITA2Packing.pack(ita2)
{:ok, ccir476} = CCIR476.encode(telegraph_codepoints)
{:ok, ccir476_packed} = CCIRPacking.pack(ccir476)
{:ok, ais6} = AIS6.encode(telegraph_codepoints)
{:ok, ais6_packed} = AIS6Packing.pack(ais6)
{:ok, ais6_armored} = AIS6Armor.encode(ais6)
s2_codepoints = String.to_charlist(String.duplicate("Hello ABC 123 ", 10))
{:ok, ita2_s2} = ITA2S2.encode(s2_codepoints)
ita1_codepoints = String.to_charlist(String.duplicate("MEET 4:30 ", 14))
{:ok, ita1} = ITA1.encode(ita1_codepoints)
{:ok, ita1_packed} = ITA1Packing.pack(ita1)
{:ok, us_tty} = ITA2USTTY.encode(telegraph_codepoints)
mtk2_codepoints = String.to_charlist(String.duplicate("TEST ТЕСТ 123 ", 10))
{:ok, mtk2} = MTK2.encode(mtk2_codepoints)
{:ok, ita3} = ITA3.encode(telegraph_codepoints)
{:ok, ita3_packed} = ITA3Packing.pack(ita3)
{:ok, ita4} = ITA4.encode(telegraph_codepoints)
{:ok, ita4_packed} = ITA4Packing.pack(ita4)
{:ok, ia5} = IA5.encode(telegraph_codepoints)
{:ok, ia5_packed} = IA5Packing.pack(ia5)
morse_codepoints = String.to_charlist(String.duplicate("HELLO WORLD 123 ", 10))
{:ok, morse} = Morse.encode(morse_codepoints)

bench = fn label, fun ->
  for _ <- 1..5_000, do: fun.()
  started = System.monotonic_time()
  for _ <- 1..iterations, do: fun.()
  elapsed = System.monotonic_time() - started
  seconds = System.convert_time_unit(elapsed, :native, :nanosecond) / 1_000_000_000
  IO.puts("#{label}: #{Float.round(iterations / seconds, 1)} ops/s")
end

bench.("GSM pack 160 septets", fn -> GSMPacking.pack(septets) end)
bench.("GSM unpack 160 septets", fn -> GSMPacking.unpack(packed, 160) end)
bench.("ITA2 encode 160 characters", fn -> ITA2.encode(telegraph_codepoints) end)
bench.("ITA2 decode 160 characters", fn -> ITA2.decode(ita2) end)
bench.("ITA2 pack #{byte_size(ita2)} units", fn -> ITA2Packing.pack(ita2) end)
bench.("ITA2 unpack #{byte_size(ita2)} units", fn -> ITA2Packing.unpack(ita2_packed) end)

bench.("ITA2 S.2 encode #{length(s2_codepoints)} characters", fn ->
  ITA2S2.encode(s2_codepoints)
end)

bench.("ITA2 S.2 decode #{byte_size(ita2_s2)} units", fn -> ITA2S2.decode(ita2_s2) end)

bench.("ITA1 encode #{length(ita1_codepoints)} characters", fn -> ITA1.encode(ita1_codepoints) end)

bench.("ITA1 decode #{byte_size(ita1)} units", fn -> ITA1.decode(ita1) end)
bench.("ITA1 pack #{byte_size(ita1)} units", fn -> ITA1Packing.pack(ita1) end)
bench.("ITA1 unpack #{byte_size(ita1)} units", fn -> ITA1Packing.unpack(ita1_packed) end)
bench.("US TTY encode 160 characters", fn -> ITA2USTTY.encode(telegraph_codepoints) end)
bench.("US TTY decode #{byte_size(us_tty)} units", fn -> ITA2USTTY.decode(us_tty) end)

bench.("MTK-2 encode #{length(mtk2_codepoints)} characters", fn ->
  MTK2.encode(mtk2_codepoints)
end)

bench.("MTK-2 decode #{byte_size(mtk2)} units", fn -> MTK2.decode(mtk2) end)
bench.("ITA3 encode 160 characters", fn -> ITA3.encode(telegraph_codepoints) end)
bench.("ITA3 decode #{byte_size(ita3)} units", fn -> ITA3.decode(ita3) end)
bench.("ITA3 pack #{byte_size(ita3)} units", fn -> ITA3Packing.pack(ita3) end)
bench.("ITA3 unpack #{byte_size(ita3)} units", fn -> ITA3Packing.unpack(ita3_packed) end)
bench.("ITA4 encode 160 characters", fn -> ITA4.encode(telegraph_codepoints) end)
bench.("ITA4 decode #{byte_size(ita4)} units", fn -> ITA4.decode(ita4) end)
bench.("ITA4 pack #{byte_size(ita4)} units", fn -> ITA4Packing.pack(ita4) end)
bench.("ITA4 unpack #{byte_size(ita4)} units", fn -> ITA4Packing.unpack(ita4_packed) end)
bench.("IA5 encode 160 characters", fn -> IA5.encode(telegraph_codepoints) end)
bench.("IA5 decode 160 units", fn -> IA5.decode(ia5) end)
bench.("IA5 pack 160 units", fn -> IA5Packing.pack(ia5) end)
bench.("IA5 unpack 160 units", fn -> IA5Packing.unpack(ia5_packed) end)

bench.("Morse encode #{length(morse_codepoints)} characters", fn ->
  Morse.encode(morse_codepoints)
end)

bench.("Morse decode #{byte_size(morse)} octets", fn -> Morse.decode(morse) end)
bench.("CCIR476 encode 160 characters", fn -> CCIR476.encode(telegraph_codepoints) end)
bench.("CCIR476 decode 160 characters", fn -> CCIR476.decode(ccir476) end)
bench.("CCIR476 pack #{byte_size(ccir476)} units", fn -> CCIRPacking.pack(ccir476) end)
bench.("CCIR476 unpack #{byte_size(ccir476)} units", fn -> CCIRPacking.unpack(ccir476_packed) end)
bench.("AIS6 encode 160 characters", fn -> AIS6.encode(telegraph_codepoints) end)
bench.("AIS6 decode 160 units", fn -> AIS6.decode(ais6) end)
bench.("AIS6 pack 160 units", fn -> AIS6Packing.pack(ais6) end)
bench.("AIS6 unpack 160 units", fn -> AIS6Packing.unpack(ais6_packed) end)
bench.("AIS6 armor 160 units", fn -> AIS6Armor.encode(ais6) end)
bench.("AIS6 dearmor 160 units", fn -> AIS6Armor.decode(ais6_armored) end)
bench.("TBCD encode 15 digits", fn -> TBCD.encode("0123456789*#abc") end)
bench.("SIM alpha auto", fn -> SIMAlphaIdentifier.encode("AА") end)
