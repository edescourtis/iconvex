defmodule Iconvex.Telecom.ReviewRegressionTest do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.{GSM0338, Packed, SIMAlphaIdentifier}
  alias Iconvex.Telecom.{SIMAlphaIdentifierCodec, TBCDCodec}

  test "SIM and TBCD UTF-8 fast callbacks return the external-codec error contract" do
    assert SIMAlphaIdentifierCodec.decode(<<0x81>>) ==
             {:error, :incomplete_sequence, 0, <<0x81>>}

    assert SIMAlphaIdentifierCodec.decode_to_utf8(<<0x81>>) ==
             {:error, :incomplete_sequence, 0, <<0x81>>}

    assert TBCDCodec.decode_to_utf8(<<0x1F>>) ==
             {:error, :invalid_sequence, 0, <<0x1F>>}

    assert SIMAlphaIdentifierCodec.decode(<<0x83>>) ==
             {:error, :invalid_sequence, 0, <<0x83>>}

    assert SIMAlphaIdentifierCodec.decode_to_utf8(<<0x83>>) ==
             {:error, :invalid_sequence, 0, <<0x83>>}

    assert {:error,
            %Iconvex.Error{
              kind: :incomplete_sequence,
              encoding: "SIM-ALPHA-IDENTIFIER",
              offset: 0,
              sequence: <<0x81>>
            }} = Iconvex.convert(<<0x81>>, "SIM-ALPHA-IDENTIFIER", "UTF-8")

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "TBCD",
              offset: 0,
              sequence: <<0x1F>>
            }} = Iconvex.convert(<<0x1F>>, "TBCD", "UTF-8")
  end

  test "compressed SIM surrogate is a typed invalid sequence, never an exception" do
    input = <<0x82, 1, 0xD8, 0x00, 0x80>>

    assert SIMAlphaIdentifier.decode(input) == {:error, {:invalid_ucs2, 0xD800}}

    assert SIMAlphaIdentifierCodec.decode_to_utf8(input) ==
             {:error, :invalid_sequence, 4, <<0x80>>}

    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "SIM-ALPHA-IDENTIFIER",
              offset: 4,
              sequence: <<0x80>>
            }} = Iconvex.convert(input, "SIM-ALPHA-IDENTIFIER", "UTF-8")
  end

  test "GSM option validation rejects non-keywords, unknown keys, and duplicates everywhere" do
    entry_points = [
      &GSM0338.decode("A", &1),
      &GSM0338.decode_discard("A", &1),
      &GSM0338.decode_utf8("A", &1),
      &GSM0338.encode([?A], &1),
      &GSM0338.encode_discard([?A], &1),
      &GSM0338.encode_utf8("A", &1)
    ]

    for call <- entry_points do
      assert call.(:not_a_list) == {:error, :options_must_be_a_keyword_list}
      assert call.([:not_a_pair]) == {:error, :options_must_be_a_keyword_list}
      assert call.(lokcing: :portuguese) == {:error, {:unknown_option, :lokcing}}

      assert call.(locking: :default, locking: :portuguese) ==
               {:error, {:duplicate_option, :locking}}
    end

    assert GSM0338.decode(<<0x04>>, locking: :portuguese) == {:ok, [0x00EA]}
  end

  test "TBCD discard drops an entire malformed octet" do
    assert TBCDCodec.decode_discard(<<0xF1, 0x32>>) == {:ok, ~c"23"}
    assert TBCDCodec.decode_discard(<<0x1F, 0x32>>) == {:ok, ~c"23"}

    assert Iconvex.convert(<<0xF1, 0x32>>, "TBCD", "UTF-8", invalid: :discard) ==
             {:ok, "23"}
  end

  test "0x80 SIM padding respects UCS2 code-unit boundaries" do
    for text <- ["Aÿ", <<0xFFFF::utf8>>, "A" <> <<0xFFFF::utf8>>] do
      assert {:ok, encoded} = SIMAlphaIdentifier.encode(text, mode: :ucs2)
      assert SIMAlphaIdentifier.decode(encoded) == {:ok, text}
    end

    assert SIMAlphaIdentifier.decode(<<0x80, 0x00, ?A, 0xFF>>) == {:ok, "A"}
  end

  test "0x80 SIM aligned padding ambiguity is explicit" do
    # Without a field length, FF FF can be either U+FFFF or two unused octets.
    # The lossless default preserves it; fixed-record callers can request the
    # specification's unused-octet interpretation explicitly.
    padded_a = <<0x80, 0x00, ?A, 0xFF, 0xFF>>
    padded_y_diaeresis = <<0x80, 0x00, 0xFF, 0xFF, 0xFF>>

    assert SIMAlphaIdentifier.decode(padded_a) == {:ok, "A" <> <<0xFFFF::utf8>>}
    assert SIMAlphaIdentifier.decode(padded_a, padding: :trim) == {:ok, "A"}

    assert SIMAlphaIdentifier.decode(padded_y_diaeresis, padding: :trim) == {:ok, "ÿ"}

    assert SIMAlphaIdentifier.decode(padded_a, padding: :preserve) ==
             {:ok, "A" <> <<0xFFFF::utf8>>}

    assert SIMAlphaIdentifier.decode(padded_a, padding: :guess) ==
             {:error, {:unknown_padding_policy, :guess}}
  end

  test "SIM encoding options reject malformed and duplicate entries" do
    assert SIMAlphaIdentifier.encode("A", [{:mode}]) == {:error, :invalid_options}

    assert SIMAlphaIdentifier.encode("A", mode: :gsm, mode: :ucs2) ==
             {:error, :invalid_options}

    assert SIMAlphaIdentifier.encode("A", typo: :gsm) == {:error, :invalid_options}
  end

  test "GSM and SIM use native linear substitution callbacks" do
    gsm = Iconvex.Telecom.Codecs.GSM0338

    assert Enum.all?(
             Iconvex.Telecom.codecs(),
             &function_exported?(&1, :encode_substitute, 2)
           )

    input = :binary.copy(<<0x1F600::utf8>>, 800)
    replacement = :binary.copy("<U+1F600>", 800)

    assert Iconvex.convert(input, "UTF-8", gsm, unicode_substitute: "<U+%04X>") ==
             {:ok, replacement}

    sim_input = :binary.copy(<<0x1F600::utf8>>, 28)
    sim_replacement = :binary.copy("<U+1F600>", 28)

    assert Iconvex.convert(sim_input, "UTF-8", SIMAlphaIdentifierCodec,
             unicode_substitute: "<U+%04X>"
           ) == {:ok, sim_replacement}

    assert {:error,
            %Iconvex.Error{
              kind: :unrepresentable_character,
              encoding: "SIM-ALPHA-IDENTIFIER",
              codepoint: ?1
            }} =
             Iconvex.convert(sim_input <> <<0x1F600::utf8>>, "UTF-8", SIMAlphaIdentifierCodec,
               unicode_substitute: "<U+%04X>"
             )
  end

  test "pinned GSM ESC fallbacks agree in strict, discard, fast, and stream paths" do
    fixture = File.read!("test/fixtures/gsm-03.38-2009.ucm")
    assert fixture =~ "<U0020> \\x1B |3"
    assert fixture =~ "<U0020> \\x1B\\x1B |3"

    assert GSM0338.decode(<<0x1B>>) == {:ok, [0x20]}
    assert GSM0338.decode(<<0x1B, ?A>>) == {:ok, [0x20, ?A]}
    assert GSM0338.decode(<<0x1B, 0x1B>>) == {:ok, [0x20]}
    assert GSM0338.decode_discard(<<0x1B, ?A>>) == {:ok, [0x20, ?A]}
    assert GSM0338.decode_discard(<<0x1B, 0xFF, ?A>>) == {:ok, [0x20, ?A]}
    assert GSM0338.decode_utf8(<<0x1B, ?A>>) == {:ok, " A"}
    assert Iconvex.convert(<<0x1B, ?A>>, "GSM0338", "UTF-8") == {:ok, " A"}

    assert {:ok, converter} = Iconvex.new("GSM0338", "UTF-8")
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, <<0x1B>>)
    assert {:ok, <<>>, converter} = Iconvex.feed(converter, "A")
    assert Iconvex.finish(converter) == {:ok, " A"}
  end

  test "packed facade returns a typed error for an invalid bit order" do
    assert Packed.encode_from_utf8("A", "GSM0338", :sideways) ==
             {:error, {:invalid_order, :sideways}}

    assert Packed.decode_to_utf8(<<0::7>>, "GSM0338", :sideways) ==
             {:error, {:invalid_order, :sideways}}
  end
end

defmodule Iconvex.Telecom.ApplicationOwnershipTest do
  use ExUnit.Case, async: false

  defmodule LateSIMConflictCodec do
    @moduledoc false

    def canonical_name, do: "TEST-LATE-SIM-CONFLICT"
    def decode(input) when is_binary(input), do: {:ok, :binary.bin_to_list(input)}
    def decode_discard(input) when is_binary(input), do: decode(input)
    def encode(codepoints) when is_list(codepoints), do: {:ok, :erlang.list_to_binary(codepoints)}
    def encode_discard(codepoints) when is_list(codepoints), do: encode(codepoints)
    def encode_substitute(codepoints, _replacer) when is_list(codepoints), do: encode(codepoints)
  end

  test "application stop preserves a codec registration it did not create" do
    codec = Iconvex.Telecom.Codecs.GSM0338

    assert :ok = Application.stop(:iconvex_telecom)
    assert :ok = Iconvex.register_codec(codec)

    on_exit(fn ->
      Application.stop(:iconvex_telecom)
      Iconvex.unregister_codec(codec)
      Application.ensure_all_started(:iconvex_telecom)
    end)

    assert {:ok, started} = Application.ensure_all_started(:iconvex_telecom)
    assert :iconvex_telecom in started
    assert :ok = Application.stop(:iconvex_telecom)

    assert Iconvex.canonical_name(codec) == {:ok, "GSM0338"}
    assert Iconvex.canonical_name("TBCD") == :error
  end

  test "application stop preserves a codec that a caller replaces after startup" do
    codec = Iconvex.Telecom.Codecs.GSM0338

    assert :ok = Iconvex.register_codec(codec, canonical: "X-CALLER-GSM")

    on_exit(fn ->
      Application.stop(:iconvex_telecom)
      Iconvex.unregister_codec(codec)
      Application.ensure_all_started(:iconvex_telecom)
    end)

    assert :ok = Application.stop(:iconvex_telecom)
    assert Iconvex.canonical_name(codec) == {:ok, "X-CALLER-GSM"}
  end

  test "registry restart preserves telecom registrations and their ownership tokens" do
    old_registry = Process.whereis(Iconvex.ExternalRegistry)
    monitor = Process.monitor(old_registry)
    Process.exit(old_registry, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^old_registry, :killed}, 1_000

    try do
      assert is_pid(wait_for_registry_restart(old_registry))
      assert Iconvex.canonical_name("GSM0338") == {:ok, "GSM0338"}
      assert Iconvex.canonical_name("TBCD") == {:ok, "TBCD"}

      assert :ok = Application.stop(:iconvex_telecom)
      assert Iconvex.canonical_name("GSM0338") == :error
      assert Iconvex.canonical_name("TBCD") == :error
    after
      assert {:ok, _started} = Application.ensure_all_started(:iconvex_telecom)
    end
  end

  test "late startup conflict rolls back every earlier registration and can recover" do
    codecs = Iconvex.Telecom.codecs()
    late_codec = List.last(codecs)
    earlier_codecs = Enum.drop(codecs, -1)

    assert late_codec == Iconvex.Telecom.SIMAlphaIdentifierCodec
    assert :ok = Application.stop(:iconvex_telecom)

    on_exit(fn ->
      Application.stop(:iconvex_telecom)
      Iconvex.unregister_codec(LateSIMConflictCodec)
      Application.ensure_all_started(:iconvex_telecom)
    end)

    assert {:ok, conflict_token} =
             Iconvex.register_codec_owned(LateSIMConflictCodec,
               canonical: late_codec.canonical_name()
             )

    assert {:error, {:iconvex_telecom, start_failure}} =
             Application.ensure_all_started(:iconvex_telecom)

    assert unwrap_start_failure(start_failure) ==
             {:name_conflict, "SIM-ALPHA-IDENTIFIER"}

    refute :iconvex_telecom in Enum.map(Application.started_applications(), &elem(&1, 0))

    for codec <- earlier_codecs,
        name <- [codec.canonical_name() | codec.aliases()] do
      assert Iconvex.canonical_name(codec) == :error
      assert Iconvex.canonical_name(name) == :error
    end

    assert Iconvex.canonical_name(late_codec) == :error

    assert {:ok, %{codec: LateSIMConflictCodec, registration_token: ^conflict_token}} =
             Iconvex.ExternalRegistry.resolve("SIM-ALPHA-IDENTIFIER")

    assert :ok = Iconvex.unregister_codec(LateSIMConflictCodec, conflict_token)
    assert Iconvex.canonical_name("SIM-ALPHA-IDENTIFIER") == :error

    assert {:ok, started} = Application.ensure_all_started(:iconvex_telecom)
    assert :iconvex_telecom in started

    for codec <- codecs do
      assert Iconvex.canonical_name(codec) == {:ok, codec.canonical_name()}
    end
  end

  defp wait_for_registry_restart(old_registry, attempts \\ 1_000)

  defp wait_for_registry_restart(_old_registry, 0), do: nil

  defp wait_for_registry_restart(old_registry, attempts) do
    case Process.whereis(Iconvex.ExternalRegistry) do
      pid when is_pid(pid) and pid != old_registry ->
        pid

      _missing_or_same ->
        Process.sleep(1)
        wait_for_registry_restart(old_registry, attempts - 1)
    end
  end

  defp unwrap_start_failure({reason, {_module, :start, _arguments}}), do: reason
  defp unwrap_start_failure(reason), do: reason
end
