defmodule Iconvex.Specs.UnicodeSignatureProfile do
  @moduledoc false

  alias Iconvex.UnicodeCodec

  @utf16le %{id: :utf16le}
  @utf16be %{id: :utf16be}
  @utf32be %{id: :utf32be}
  @utf32le %{id: :utf32le}

  def decode(input, :utf16_le_default) when is_binary(input) do
    case input do
      <<0xFE, 0xFF, rest::binary>> -> decode_with_offset(@utf16be, rest, 2)
      <<0xFF, 0xFE, rest::binary>> -> decode_with_offset(@utf16le, rest, 2)
      _ -> UnicodeCodec.decode(@utf16le, input)
    end
  end

  def decode(input, :utf32be) when is_binary(input) do
    {body, offset} = strip_matching_signature(input, <<0x00, 0x00, 0xFE, 0xFF>>)
    decode_with_offset(@utf32be, body, offset)
  end

  def decode(input, :utf32le) when is_binary(input) do
    {body, offset} = strip_matching_signature(input, <<0xFF, 0xFE, 0x00, 0x00>>)
    decode_with_offset(@utf32le, body, offset)
  end

  def decode_discard(input, :utf16_le_default) when is_binary(input) do
    case input do
      <<0xFE, 0xFF, rest::binary>> -> UnicodeCodec.decode_discard(@utf16be, rest)
      <<0xFF, 0xFE, rest::binary>> -> UnicodeCodec.decode_discard(@utf16le, rest)
      _ -> UnicodeCodec.decode_discard(@utf16le, input)
    end
  end

  def decode_discard(input, :utf32be) when is_binary(input) do
    {body, _offset} = strip_matching_signature(input, <<0x00, 0x00, 0xFE, 0xFF>>)
    UnicodeCodec.decode_discard(@utf32be, body)
  end

  def decode_discard(input, :utf32le) when is_binary(input) do
    {body, _offset} = strip_matching_signature(input, <<0xFF, 0xFE, 0x00, 0x00>>)
    UnicodeCodec.decode_discard(@utf32le, body)
  end

  def encode(codepoints, profile) when is_list(codepoints) do
    {entry, signature} = encoder(profile)

    with {:ok, body} <- UnicodeCodec.encode(entry, codepoints) do
      {:ok, prepend_if_nonempty(signature, body)}
    end
  end

  def encode_discard(codepoints, profile) when is_list(codepoints) do
    {entry, signature} = encoder(profile)
    {:ok, body} = UnicodeCodec.encode_discard(entry, codepoints)
    {:ok, prepend_if_nonempty(signature, body)}
  end

  def encode_substitute(codepoints, profile, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    {entry, signature} = encoder(profile)

    with {:ok, body} <- UnicodeCodec.encode_substitute(entry, codepoints, replacer) do
      {:ok, prepend_if_nonempty(signature, body)}
    end
  end

  def decode_to_utf8(input, profile) do
    with {:ok, codepoints} <- decode(input, profile), do: {:ok, List.to_string(codepoints)}
  end

  def encode_from_utf8(input, profile) when is_binary(input) do
    if String.valid?(input) do
      encode(String.to_charlist(input), profile)
    else
      Iconvex.Specs.CodecSupport.malformed_utf8(input)
    end
  end

  def stream_decoder_init(_profile), do: :initial

  def decode_chunk(input, :initial, final?, :utf16_le_default) when is_binary(input) do
    cond do
      not final? and byte_size(input) < 2 ->
        {:ok, [], :initial, input}

      match?(<<0xFE, 0xFF, _::binary>>, input) ->
        <<_signature::binary-size(2), body::binary>> = input
        decode_body(@utf16be, body, {:body, @utf16be}, final?, 2)

      match?(<<0xFF, 0xFE, _::binary>>, input) ->
        <<_signature::binary-size(2), body::binary>> = input
        decode_body(@utf16le, body, {:body, @utf16le}, final?, 2)

      true ->
        decode_body(@utf16le, input, {:body, @utf16le}, final?, 0)
    end
  end

  def decode_chunk(input, :initial, final?, profile) when profile in [:utf32be, :utf32le] do
    {entry, signature} = encoder(profile)

    cond do
      not final? and byte_size(input) < 4 ->
        {:ok, [], :initial, input}

      byte_size(input) >= 4 and binary_part(input, 0, 4) == signature ->
        body = binary_part(input, 4, byte_size(input) - 4)
        decode_body(entry, body, {:body, entry}, final?, 4)

      true ->
        decode_body(entry, input, {:body, entry}, final?, 0)
    end
  end

  def decode_chunk(input, {:body, entry} = state, final?, _profile) when is_binary(input),
    do: decode_body(entry, input, state, final?, 0)

  def stream_encoder_init(_profile), do: false

  def encode_chunk(codepoints, started?, _final?, policy, profile) when is_list(codepoints) do
    {entry, signature} = encoder(profile)

    with {:ok, body} <- encode_with_policy(entry, codepoints, policy) do
      prefix = if not started? and body != <<>>, do: signature, else: <<>>
      {:ok, prefix <> body, started? or body != <<>>, []}
    end
  end

  defp decode_with_offset(entry, input, prefix_size) do
    case UnicodeCodec.decode(entry, input) do
      {:error, kind, offset, sequence} ->
        {:error, kind, prefix_size + offset, sequence}

      result ->
        result
    end
  end

  defp decode_body(entry, input, state, final?, prefix_size) do
    case UnicodeCodec.decode(entry, input) do
      {:ok, codepoints} ->
        {:ok, codepoints, state, <<>>}

      {:error, :incomplete_sequence, offset, _sequence} when not final? ->
        prefix = binary_part(input, 0, offset)

        case UnicodeCodec.decode(entry, prefix) do
          {:ok, codepoints} ->
            pending = binary_part(input, offset, byte_size(input) - offset)
            {:ok, codepoints, state, pending}

          {:error, kind, nested_offset, nested_sequence} ->
            {:error, kind, prefix_size + nested_offset, nested_sequence}
        end

      {:error, kind, offset, sequence} ->
        {:error, kind, prefix_size + offset, sequence}
    end
  end

  defp encode_with_policy(entry, codepoints, :error),
    do: UnicodeCodec.encode(entry, codepoints)

  defp encode_with_policy(entry, codepoints, :discard),
    do: UnicodeCodec.encode_discard(entry, codepoints)

  defp encode_with_policy(entry, codepoints, {:replace, replacer}),
    do: UnicodeCodec.encode_substitute(entry, codepoints, replacer)

  defp strip_matching_signature(<<signature::binary-size(4), rest::binary>>, signature),
    do: {rest, 4}

  defp strip_matching_signature(input, _signature), do: {input, 0}

  defp encoder(:utf16_le_default), do: {@utf16le, <<0xFF, 0xFE>>}
  defp encoder(:utf32be), do: {@utf32be, <<0x00, 0x00, 0xFE, 0xFF>>}
  defp encoder(:utf32le), do: {@utf32le, <<0xFF, 0xFE, 0x00, 0x00>>}

  defp prepend_if_nonempty(_signature, <<>>), do: <<>>
  defp prepend_if_nonempty(signature, body), do: signature <> body
end

defmodule Iconvex.Specs.IconvexUTF16SignatureLEDefault do
  @moduledoc """
  Iconvex-defined UTF-16 signature profile with little-endian default input.

  This is a project profile, not a Unicode-standard encoding scheme. Its
  encoder prepends a little-endian U+FEFF signature to nonempty output. Its
  decoder consumes either UTF-16 signature and otherwise defaults to little
  endian.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.UnicodeSignatureProfile, as: Profile

  @impl true
  def canonical_name, do: "ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT"

  @impl true
  def aliases, do: ["ICONVEX_UTF_16_SIGNATURE_LE_DEFAULT"]

  @impl true
  def codec_id, do: :iconvex_utf16_signature_le_default

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: Profile.decode(input, :utf16_le_default)

  @impl true
  def decode_discard(input), do: Profile.decode_discard(input, :utf16_le_default)

  @impl true
  def encode(codepoints), do: Profile.encode(codepoints, :utf16_le_default)

  @impl true
  def encode_discard(codepoints), do: Profile.encode_discard(codepoints, :utf16_le_default)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Profile.encode_substitute(codepoints, :utf16_le_default, replacer)

  @impl true
  def decode_to_utf8(input), do: Profile.decode_to_utf8(input, :utf16_le_default)

  @impl true
  def encode_from_utf8(input), do: Profile.encode_from_utf8(input, :utf16_le_default)

  @impl true
  def stream_decoder_init, do: Profile.stream_decoder_init(:utf16_le_default)

  @impl true
  def decode_chunk(input, state, final?),
    do: Profile.decode_chunk(input, state, final?, :utf16_le_default)

  @impl true
  def stream_encoder_init, do: Profile.stream_encoder_init(:utf16_le_default)

  @impl true
  def encode_chunk(codepoints, state, final?, policy),
    do: Profile.encode_chunk(codepoints, state, final?, policy, :utf16_le_default)

  @impl true
  def decode_error_consumption(_kind, sequence) when byte_size(sequence) >= 2, do: 2
  def decode_error_consumption(_kind, _sequence), do: 1
end

defmodule Iconvex.Specs.IconvexUTF32BESignature do
  @moduledoc """
  Iconvex-defined fixed-big-endian UTF-32 profile with an output signature.

  This is a project profile, not a Unicode-standard encoding scheme. It
  prepends and consumes a matching big-endian U+FEFF signature on nonempty
  encoded text.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.UnicodeSignatureProfile, as: Profile

  @impl true
  def canonical_name, do: "ICONVEX-UTF-32BE-SIGNATURE"

  @impl true
  def aliases, do: ["ICONVEX_UTF_32BE_SIGNATURE"]

  @impl true
  def codec_id, do: :iconvex_utf32be_signature

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: Profile.decode(input, :utf32be)

  @impl true
  def decode_discard(input), do: Profile.decode_discard(input, :utf32be)

  @impl true
  def encode(codepoints), do: Profile.encode(codepoints, :utf32be)

  @impl true
  def encode_discard(codepoints), do: Profile.encode_discard(codepoints, :utf32be)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Profile.encode_substitute(codepoints, :utf32be, replacer)

  @impl true
  def decode_to_utf8(input), do: Profile.decode_to_utf8(input, :utf32be)

  @impl true
  def encode_from_utf8(input), do: Profile.encode_from_utf8(input, :utf32be)

  @impl true
  def stream_decoder_init, do: Profile.stream_decoder_init(:utf32be)

  @impl true
  def decode_chunk(input, state, final?),
    do: Profile.decode_chunk(input, state, final?, :utf32be)

  @impl true
  def stream_encoder_init, do: Profile.stream_encoder_init(:utf32be)

  @impl true
  def encode_chunk(codepoints, state, final?, policy),
    do: Profile.encode_chunk(codepoints, state, final?, policy, :utf32be)

  @impl true
  def decode_error_consumption(_kind, sequence) when byte_size(sequence) >= 4, do: 4
  def decode_error_consumption(_kind, _sequence), do: 1
end

defmodule Iconvex.Specs.IconvexUTF32LESignature do
  @moduledoc """
  Iconvex-defined fixed-little-endian UTF-32 profile with an output signature.

  This is a project profile, not a Unicode-standard encoding scheme. It
  prepends and consumes a matching little-endian U+FEFF signature on nonempty
  encoded text.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.UnicodeSignatureProfile, as: Profile

  @impl true
  def canonical_name, do: "ICONVEX-UTF-32LE-SIGNATURE"

  @impl true
  def aliases, do: ["ICONVEX_UTF_32LE_SIGNATURE"]

  @impl true
  def codec_id, do: :iconvex_utf32le_signature

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: Profile.decode(input, :utf32le)

  @impl true
  def decode_discard(input), do: Profile.decode_discard(input, :utf32le)

  @impl true
  def encode(codepoints), do: Profile.encode(codepoints, :utf32le)

  @impl true
  def encode_discard(codepoints), do: Profile.encode_discard(codepoints, :utf32le)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Profile.encode_substitute(codepoints, :utf32le, replacer)

  @impl true
  def decode_to_utf8(input), do: Profile.decode_to_utf8(input, :utf32le)

  @impl true
  def encode_from_utf8(input), do: Profile.encode_from_utf8(input, :utf32le)

  @impl true
  def stream_decoder_init, do: Profile.stream_decoder_init(:utf32le)

  @impl true
  def decode_chunk(input, state, final?),
    do: Profile.decode_chunk(input, state, final?, :utf32le)

  @impl true
  def stream_encoder_init, do: Profile.stream_encoder_init(:utf32le)

  @impl true
  def encode_chunk(codepoints, state, final?, policy),
    do: Profile.encode_chunk(codepoints, state, final?, policy, :utf32le)

  @impl true
  def decode_error_consumption(_kind, sequence) when byte_size(sequence) >= 4, do: 4
  def decode_error_consumption(_kind, _sequence), do: 1
end
