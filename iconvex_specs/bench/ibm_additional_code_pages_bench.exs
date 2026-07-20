profiles = [
  Iconvex.Specs.IBM310293P100CompositeVPUA,
  Iconvex.Specs.IBMTNZCP310B1EAE3C,
  Iconvex.Specs.IBM907CDRAP100VPUAComposite,
  Iconvex.Specs.IBM1116850P100Composite,
  Iconvex.Specs.IBM1117437P100Composite,
  Iconvex.Specs.DECGreek81994,
  Iconvex.Specs.DECTurkish81994
]

quick? = "--quick" in System.argv()
logical_bytes = if quick?, do: 262_144, else: 1_048_576
samples = if quick?, do: 3, else: 7
warmups = if quick?, do: 1, else: 2
reduction_scaling_limit = 2.3

measure = fn fun ->
  for _ <- 1..warmups do
    {:ok, _output} = fun.()
    :erlang.garbage_collect()
  end

  measurements =
    for _ <- 1..samples do
      :erlang.garbage_collect()
      {:reductions, before} = Process.info(self(), :reductions)
      {microseconds, {:ok, _output}} = :timer.tc(fun)
      {:reductions, after_run} = Process.info(self(), :reductions)
      {microseconds, after_run - before}
    end

  median_index = div(samples, 2)
  median_us = measurements |> Enum.map(&elem(&1, 0)) |> Enum.sort() |> Enum.at(median_index)

  median_reductions =
    measurements |> Enum.map(&elem(&1, 1)) |> Enum.sort() |> Enum.at(median_index)

  {median_us, median_reductions}
end

corpus = fn alphabet, size ->
  copies = div(size + byte_size(alphabet) - 1, byte_size(alphabet))
  alphabet |> :binary.copy(copies) |> binary_part(0, size)
end

IO.puts("profile\tdirection\tinput MiB/s\tmedian us\treduction scaling\ttime scaling")

scaling_results =
  for codec <- profiles, direction <- [:decode, :encode] do
    name = codec.canonical_name()

    alphabet =
      for byte <- 0x00..0xFF,
          match?({:ok, [_codepoint]}, codec.decode(<<byte>>)),
          into: <<>>,
          do: <<byte>>

    small_units = corpus.(alphabet, div(logical_bytes, 2))
    large_units = corpus.(alphabet, logical_bytes)
    {:ok, small_utf8} = Iconvex.convert(small_units, name, "UTF-8")
    {:ok, large_utf8} = Iconvex.convert(large_units, name, "UTF-8")

    {small_input, large_input, source, destination} =
      case direction do
        :decode -> {small_units, large_units, name, "UTF-8"}
        :encode -> {small_utf8, large_utf8, "UTF-8", name}
      end

    {small_us, small_reductions} =
      measure.(fn -> Iconvex.convert(small_input, source, destination) end)

    {large_us, large_reductions} =
      measure.(fn -> Iconvex.convert(large_input, source, destination) end)

    reduction_scaling = large_reductions / max(small_reductions, 1)
    time_scaling = large_us / max(small_us, 1)
    mib_per_second = byte_size(large_input) / 1_048_576 / (large_us / 1_000_000)

    IO.puts(
      Enum.join(
        [
          name,
          direction,
          Float.round(mib_per_second, 2),
          large_us,
          "#{Float.round(reduction_scaling, 3)}x",
          "#{Float.round(time_scaling, 3)}x"
        ],
        "\t"
      )
    )

    if reduction_scaling > reduction_scaling_limit do
      raise "#{name} #{direction} reduction scaling #{Float.round(reduction_scaling, 3)}x exceeds #{reduction_scaling_limit}x"
    end

    {name, direction, reduction_scaling}
  end

IO.puts(
  "all #{length(scaling_results)} reduction-scaling gates passed (limit #{reduction_scaling_limit}x)"
)

gnu = System.get_env("GNU_ICONV", "/opt/homebrew/opt/libiconv/bin/iconv")

if File.regular?(gnu) do
  {version, 0} = System.cmd(gnu, ["--version"], stderr_to_stdout: true)
  [first_line | _] = String.split(version, "\n")

  IO.puts(
    "GNU comparison unavailable: #{first_line} exposes none of the seven qualified profile identities"
  )
else
  IO.puts("GNU comparison unavailable: set GNU_ICONV to a GNU libiconv executable")
end
