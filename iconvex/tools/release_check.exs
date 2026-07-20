#!/usr/bin/env elixir

root = Path.expand("..", __DIR__)
tmp = Path.join(System.tmp_dir!(), "iconvex-release-#{System.unique_integer([:positive])}")
unpacked = Path.join(tmp, "package")
consumer = Path.join(tmp, "consumer")

run! = fn command, args, options ->
  {output, status} = System.cmd(command, args, [stderr_to_stdout: true] ++ options)
  IO.write(output)

  if status != 0 do
    raise "#{command} #{Enum.join(args, " ")} exited with #{status}"
  end
end

File.mkdir_p!(consumer)

try do
  run!.("mix", ["deps.get"], cd: root)
  run!.("mix", ["docs", "--warnings-as-errors"], cd: root)
  run!.("mix", ["hex.build", "--unpack", "--output", unpacked], cd: root)

  File.write!(
    Path.join(consumer, "mix.exs"),
    """
    defmodule IconvexReleaseConsumer.MixProject do
      use Mix.Project

      def project do
        [app: :iconvex_release_consumer, version: "0.0.0", elixir: "~> 1.16", deps: deps()]
      end

      def application, do: [extra_applications: [:logger]]

      defp deps, do: [{:iconvex, path: #{inspect(unpacked)}}]
    end
    """
  )

  File.mkdir_p!(Path.join(consumer, "test"))
  File.write!(Path.join(consumer, "test/test_helper.exs"), "ExUnit.start()\n")

  File.write!(
    Path.join(consumer, "test/iconvex_release_smoke_test.exs"),
    """
    defmodule IconvexReleaseSmokeTest do
      use ExUnit.Case, async: true

      test "unpacked Hex artifact works as a clean dependency" do
        assert length(Iconvex.encodings()) == 112
        assert {:ok, "café"} = Iconvex.convert(<<0x63, 0x61, 0x66, 0xE9>>, "CP1252", "UTF-8")
        assert {:ok, <<0x88, 0xA5>>} = Iconvex.convert("ê̌", "UTF-8", "BIG5-HKSCS")

        assert {:ok, converter} = Iconvex.new("UTF-8", "UTF-16")
        assert {:ok, <<>>, converter} = Iconvex.feed(converter, "A")
        assert {:ok, <<>>, converter} = Iconvex.feed(converter, "B")
        assert {:ok, <<0xFE, 0xFF, 0, ?A, 0, ?B>>, _finished} =
                 Iconvex.finish_with_state(converter)

        assert {:ok, packed} = Iconvex.Packed.encode_from_utf8("Hello", "ASCII", 7)
        assert {:ok, "Hello"} = Iconvex.Packed.decode_to_utf8(packed, "ASCII", 7)
      end
    end
    """
  )

  run!.("mix", ["deps.get"], cd: consumer)
  run!.("mix", ["test", "--warnings-as-errors"], cd: consumer)
  IO.puts("clean package, docs, and consumer smoke test: PASS")
after
  File.rm_rf!(tmp)
end
