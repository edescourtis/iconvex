defmodule Iconvex.StatefulSplitBoundaryRegressionTest do
  use ExUnit.Case, async: true

  @jp_ms "ISO-2022-JP-MS"
  @utf7 "UTF-7"
  @utf8 "UTF-8"

  @iso_diagnostic_encodings [
    "ISO-2022-JP",
    "ISO-2022-JP-1",
    "ISO-2022-JP-2",
    "ISO-2022-JP-MS",
    "ISO-2022-CN",
    "ISO-2022-CN-EXT"
  ]

  @invalid_escape <<0x1B, "ASC">>
  @jp_ms_shift_input <<0x1B, "$B", 0x0E, 0x46, 0x7C, 0x1B, "(B", "AB">>
  @jp_ms_minimal_shift_input <<0x1B, "$B", 0x0E, 0x1B, "(B", "!!">>
  @utf7_source "A£+"
  @utf7_expected "A+AKMAKw-"

  test "JP-MS ignored shifts cannot corrupt scanner state across any split or policy" do
    parent = self()

    callback = fn event ->
      send(parent, {:unexpected_jp_ms_invalid_byte, event})
      :error
    end

    options_sets = [
      [],
      [invalid: :discard],
      [byte_substitute: "%02X"],
      [on_invalid_byte: callback]
    ]

    for {input, expected} <- [
          {@jp_ms_shift_input, "日AB"},
          {@jp_ms_minimal_shift_input, "!!"}
        ],
        options <- options_sets do
      assert {:ok, ^expected} = Iconvex.convert(input, @jp_ms, @utf8, options)

      for split <- 0..byte_size(input) do
        assert stream_result(input, split, @jp_ms, @utf8, options) == {:ok, expected},
               "JP-MS split #{split} changed #{inspect(input)} under #{inspect(options)}"
      end
    end

    refute_received {:unexpected_jp_ms_invalid_byte, _event}
  end

  test "ISO-2022 invalid-escape diagnostics and callback decisions are split invariant" do
    for encoding <- @iso_diagnostic_encodings do
      expected_error =
        {:error, {:invalid_sequence, encoding, 0, @invalid_escape}}

      assert conversion_result(@invalid_escape, encoding, @utf8, []) == expected_error

      for split <- 0..byte_size(@invalid_escape) do
        assert stream_result(@invalid_escape, split, encoding, @utf8, []) == expected_error,
               "#{encoding} strict split #{split} truncated its diagnostic frame"
      end

      for {options, expected} <- [
            {[invalid: :discard], "ASC"},
            {[byte_substitute: "%02X"], "1BASC"}
          ] do
        assert {:ok, ^expected} = Iconvex.convert(@invalid_escape, encoding, @utf8, options)

        for split <- 0..byte_size(@invalid_escape) do
          assert stream_result(@invalid_escape, split, encoding, @utf8, options) ==
                   {:ok, expected}
        end
      end

      assert_callback_frame(encoding, :one_shot)

      for split <- 0..byte_size(@invalid_escape) do
        assert_callback_frame(encoding, {:stream, split})
      end
    end
  end

  test "ISO-2022-KR already retains its complete four-byte callback frame" do
    assert_callback_frame("ISO-2022-KR", :one_shot)

    for split <- 0..byte_size(@invalid_escape) do
      assert_callback_frame("ISO-2022-KR", {:stream, split})
    end
  end

  test "UTF-7 streaming keeps plus inside an active Base64 shift at every source split" do
    options_sets = [
      [],
      [unrepresentable: :discard],
      [unicode_substitute: "<U+%04X>"],
      [transliterate: true]
    ]

    assert {:ok, @utf7_source} = Iconvex.convert(@utf7_expected, @utf7, @utf8)

    for options <- options_sets do
      assert {:ok, @utf7_expected} = Iconvex.convert(@utf7_source, @utf8, @utf7, options)

      for split <- 0..byte_size(@utf7_source) do
        assert stream_result(@utf7_source, split, @utf8, @utf7, options) ==
                 {:ok, @utf7_expected},
               "UTF-7 target split #{split} prematurely closed the active shift"
      end
    end
  end

  test "UTF-7 recovery emits a completed implicit shift before its replacement" do
    input = <<?+, ?A, ?0, ?0, 0x00>>
    shifted = <<0x034D::utf8>>

    assert Iconvex.convert(input, @utf7, @utf8, byte_substitute: "%02X") ==
             {:ok, shifted <> "00"}

    for split <- 0..byte_size(input) do
      assert stream_result(input, split, @utf7, @utf8, byte_substitute: "%02X") ==
               {:ok, shifted <> "00"},
             "UTF-7 split #{split} emitted recovery before the completed shift"

      tag = make_ref()
      parent = self()

      callback = fn event ->
        send(parent, {tag, event})
        {:replace, "X"}
      end

      assert stream_result(input, split, @utf7, @utf8, on_invalid_byte: callback) ==
               {:ok, shifted <> "X"}

      assert_receive {^tag,
                      %Iconvex.InvalidByte{
                        encoding: @utf7,
                        kind: :invalid_sequence,
                        offset: 4,
                        byte: 0,
                        sequence: <<0>>
                      }}

      refute_receive {^tag, _extra_event}
    end
  end

  defp assert_callback_frame(encoding, mode) do
    parent = self()
    tag = {encoding, mode}

    callback = fn event ->
      send(parent, {:invalid_escape, tag, event})

      if event.sequence == @invalid_escape,
        do: {:replace, "X"},
        else: :error
    end

    result =
      case mode do
        :one_shot ->
          Iconvex.convert(@invalid_escape, encoding, @utf8, on_invalid_byte: callback)

        {:stream, split} ->
          stream_result(
            @invalid_escape,
            split,
            encoding,
            @utf8,
            on_invalid_byte: callback
          )
      end

    assert result == {:ok, "XASC"}

    assert_receive {:invalid_escape, ^tag,
                    %Iconvex.InvalidByte{
                      kind: :invalid_sequence,
                      offset: 0,
                      byte: 0x1B,
                      sequence: @invalid_escape
                    }}

    refute_received {:invalid_escape, ^tag, _extra_event}
  end

  defp conversion_result(input, from, to, options) do
    case Iconvex.convert(input, from, to, options) do
      {:ok, output} ->
        {:ok, output}

      {:error, %Iconvex.Error{} = error} ->
        {:error, {error.kind, error.encoding, error.offset, error.sequence}}
    end
  end

  defp stream_result(input, split, from, to, options) do
    left = binary_part(input, 0, split)
    right = binary_part(input, split, byte_size(input) - split)

    try do
      {:ok, [left, right] |> Iconvex.stream!(from, to, options) |> Enum.join()}
    rescue
      error in Iconvex.Error ->
        {:error, {error.kind, error.encoding, error.offset, error.sequence}}
    end
  end
end
