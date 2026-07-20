alias Iconvex.Specs.{
  FieldataUNIVAC1100,
  FieldataUNIVAC4009Input,
  FieldataUNIVAC4009LosslessVPUA,
  FieldataUNIVAC4009Output,
  FieldataUNIVAC4009RawVPUA,
  Packed
}

profiles = [
  FieldataUNIVAC1100,
  FieldataUNIVAC4009Input,
  FieldataUNIVAC4009Output,
  FieldataUNIVAC4009LosslessVPUA,
  FieldataUNIVAC4009RawVPUA
]

logical_units = 262_144
units = :binary.copy(<<0o06>>, logical_units)

median_us = fn function ->
  for _ <- 1..2, do: function.()

  samples =
    for _ <- 1..9 do
      {microseconds, {:ok, _result}} = :timer.tc(function)
      microseconds
    end

  samples |> Enum.sort() |> Enum.at(div(length(samples), 2))
end

report = fn label, function ->
  microseconds = median_us.(function)
  mib_per_second = logical_units / 1_048_576 / (microseconds / 1_000_000)
  IO.puts("#{label}\t#{Float.round(mib_per_second, 2)} Mi logical units/s\t#{microseconds} us")
end

for codec <- profiles do
  canonical = codec.canonical_name()
  {:ok, text} = codec.decode_to_utf8(units)
  {:ok, msb} = Packed.encode_from_utf8(text, canonical, :msb)
  {:ok, lsb} = Packed.encode_from_utf8(text, canonical, :lsb)

  report.("#{canonical} byte decode", fn -> codec.decode_to_utf8(units) end)
  report.("#{canonical} byte encode", fn -> codec.encode_from_utf8(text) end)

  report.("#{canonical} packed MSB encode", fn ->
    Packed.encode_from_utf8(text, canonical, :msb)
  end)

  report.("#{canonical} packed MSB decode", fn -> Packed.decode_to_utf8(msb, canonical, :msb) end)

  report.("#{canonical} packed LSB encode", fn ->
    Packed.encode_from_utf8(text, canonical, :lsb)
  end)

  report.("#{canonical} packed LSB decode", fn -> Packed.decode_to_utf8(lsb, canonical, :lsb) end)
end
