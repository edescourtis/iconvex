defmodule Iconvex.ReviewRigorCoverageContractTest do
  use ExUnit.Case, async: false

  test "lazy stream finalizes incomplete UTF-8 under both recovery policies" do
    assert "ok" ==
             ["ok", <<0xC3>>]
             |> Iconvex.stream!("UTF-8", "UTF-8", invalid: :discard)
             |> Enum.join()

    assert "ok<c3>" ==
             ["ok", <<0xC3>>]
             |> Iconvex.stream!("UTF-8", "UTF-8", byte_substitute: "<%02x>")
             |> Enum.join()
  end

  test "lazy target discard and substitution match one-shot conversion" do
    chunks = ["A", "😀", "B"]

    assert "AB" ==
             chunks
             |> Iconvex.stream!("UTF-8", "ASCII", unrepresentable: :discard)
             |> Enum.join()

    assert "A<U+1F600>B" ==
             chunks
             |> Iconvex.stream!("UTF-8", "ASCII", unicode_substitute: "<U+%04X>")
             |> Enum.join()
  end

  test "surface suffixes are accepted and invalid explicit surface values are rejected" do
    assert {:ok, "A\n"} = Iconvex.convert("A\n", "ASCII//ZOS_UNIX", "UTF-8")
    assert {:ok, "A\n"} = Iconvex.convert("A\n", "UTF-8", "ASCII//ZOS_UNIX")

    assert {:error, {:invalid_option, :from_surface, {:invalid_value, :bad}}} =
             Iconvex.convert("A", "ASCII", "UTF-8", from_surface: :bad)

    assert {:error, {:invalid_option, :to_surface, {:invalid_value, :bad}}} =
             Iconvex.convert("A", "UTF-8", "ASCII", to_surface: :bad)

    assert {:error, {:invalid_option, :unrepresentable, {:invalid_value, :bad}}} =
             Iconvex.convert("A", "UTF-8", "ASCII", unrepresentable: :bad)
  end

  test "invalid-byte default delegates to configured byte substitution" do
    parent = self()

    assert {:ok, "A<ff>B"} =
             Iconvex.convert(<<"A", 0xFF, "B">>, "UTF-8", "UTF-8",
               byte_substitute: "<%02x>",
               on_invalid_byte: fn event ->
                 send(parent, {:default_invalid_byte, event})
                 :default
               end
             )

    assert_receive {:default_invalid_byte,
                    %Iconvex.InvalidByte{offset: 1, byte: 0xFF, sequence: <<0xFF>>}}
  end

  test "typed conversion errors retain their stable public messages" do
    decode_error =
      Iconvex.Error.exception(
        kind: :invalid_sequence,
        encoding: "UTF-8",
        offset: 7,
        sequence: <<0xFF>>
      )

    encode_error =
      Iconvex.Error.exception(
        kind: :unrepresentable_character,
        encoding: "ASCII",
        codepoint: 0x1F600
      )

    assert Exception.message(decode_error) == "invalid_sequence in UTF-8 at byte offset 7"
    assert Exception.message(encode_error) == "ASCII cannot represent U+1F600"
  end

  test "packed validation reports incomplete units before padding" do
    assert Iconvex.Packed.unpack_lsb(<<0x80>>, 6, 7) ==
             {:error, :incomplete_unit, 0, 6}
  end

  test "GB18030 rejects the first algorithmic value above the Unicode range" do
    over_range = <<0xE3, 0x32, 0x9A, 0x36>>

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "GB18030",
              offset: 0,
              sequence: ^over_range
            }} = Iconvex.convert(over_range, "GB18030", "UTF-8")
  end

  test "live heir reports non-ownership while the registry owns ETS" do
    assert :ets.info(Iconvex.ExternalRegistry, :owner) ==
             Process.whereis(Iconvex.ExternalRegistry)

    assert Iconvex.ExternalRegistry.Heir.unregister_owned(__MODULE__, make_ref()) == :not_owner
    assert Iconvex.ExternalRegistry.Heir.unregister_set(make_ref()) == :not_owner
  end

  test "RED: registry singletons ignore unrelated process messages" do
    registry = Process.whereis(Iconvex.ExternalRegistry)
    heir = Process.whereis(Iconvex.ExternalRegistry.Heir)

    send(registry, {:unrelated_registry_message, make_ref()})
    assert :sys.get_state(registry) == %{}
    assert Process.whereis(Iconvex.ExternalRegistry) == registry

    send(heir, {:unrelated_heir_message, make_ref()})
    assert :sys.get_state(heir) == nil
    assert Process.whereis(Iconvex.ExternalRegistry.Heir) == heir
  end

  test "external canonical names are ASCII-sorted and case-deduplicated" do
    names = Iconvex.ExternalRegistry.canonical_names()
    assert names == Enum.sort(names)
    assert length(names) == length(Enum.uniq_by(names, &String.upcase(&1, :ascii)))
  end
end
