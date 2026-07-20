defmodule Iconvex do
  @moduledoc """
  Pure BEAM character-set conversion based on GNU libiconv 1.19.

  `convert/4` performs complete, one-shot conversion. `stream/4` provides lazy,
  bounded-memory conversion with incremental state for built-in stateless and
  stateful codecs. The older `new/3`, `feed/2`, and `finish/1` API remains a
  buffered transaction whose final result is exactly one `convert/4` call.
  """

  alias Iconvex.{
    Converter,
    Error,
    EscapeCodec,
    ExternalCallbacks,
    ExternalRegistry,
    GB18030Codec,
    InvalidByte,
    Registry,
    RouteSnapshot,
    StatefulCodec,
    TableCodec,
    Tables,
    TargetArbitrator,
    Transliterator,
    UnicodeCodec,
    UTF7Codec
  }

  @default_options [
    invalid: :error,
    unrepresentable: :error,
    transliterate: false,
    byte_substitute: nil,
    unicode_substitute: nil,
    on_invalid_byte: nil,
    from_surface: nil,
    to_surface: nil
  ]

  @option_keys Keyword.keys(@default_options)
  @max_substitution_width 65_536
  @route_capture_fast_retries 8
  @multibyte_unicode_ids ~w(
    ucs2 ucs2be ucs2le ucs2internal ucs2swapped
    ucs4 ucs4be ucs4le ucs4internal ucs4swapped
    utf16 utf16be utf16le utf32 utf32be utf32le
  )a
  @scalar_fallback_target_ids ~w(
    utf8
    utf16 utf16be utf16le utf32 utf32be utf32le
    gb18030_2005 gb18030_2022
  )a
  @surrogate_unit_target_ids ~w(utf7 java)a
  @ucs2_target_ids ~w(ucs2 ucs2be ucs2le ucs2internal ucs2swapped)a
  @explicit_ucs4_target_ids ~w(ucs4be ucs4le ucs4internal ucs4swapped)a
  @explicit_utf32_source_ids ~w(utf32be utf32le)a
  @direct_ucs4_target_ids [
    :ucs4,
    :utf16,
    :utf16be,
    :utf16le,
    :utf32,
    :utf32be,
    :utf32le
    | @explicit_ucs4_target_ids
  ]
  @direct_stateful_ucs4_target_ids ~w(
    hz iso2022_kr
    iso2022_jp iso2022_jp1 iso2022_jp2 iso2022_jpms iso2022_jp_ext
  )a
  @tag_capable_target_ids ~w(
    utf8 utf7 utf16 utf16be utf16le utf32 utf32be utf32le
    ucs4 ucs4be ucs4le ucs4internal ucs4swapped
    c99 java gb18030_2005 gb18030_2022 iso2022_jp2
  )a

  @type encoding :: String.t() | atom()
  @type conversion_option ::
          {:invalid, :error | :discard}
          | {:unrepresentable, :error | :discard}
          | {:transliterate, boolean()}
          | {:byte_substitute, nil | binary()}
          | {:unicode_substitute, nil | binary()}
          | {:on_invalid_byte, nil | invalid_byte_handler()}
          | {:from_surface, nil | :zos_unix}
          | {:to_surface, nil | :zos_unix}
  @type invalid_byte_replacement :: binary() | non_neg_integer() | [non_neg_integer()]
  @type invalid_byte_handler ::
          (InvalidByte.t() ->
             :default | :error | :discard | {:replace, invalid_byte_replacement()})
  @type conversion_options :: [conversion_option()]
  @type registration_token :: reference()
  @type request_error ::
          :unknown_encoding
          | :already_finished
          | {:invalid_argument, atom()}
          | {:invalid_options, :expected_keyword}
          | {:invalid_option, atom(), term()}
          | {:invalid_callback_return, atom(), term()}
          | {:invalid_codec_callback_return, module(), {atom(), non_neg_integer()}, term()}
          | {:streaming_unsupported, :source | :target, String.t()}
          | {:invalid_suffix, String.t()}
  @type conversion_result :: {:ok, binary()} | {:error, Error.t() | request_error()}

  @doc "Returns all currently registered canonical encoding names."
  @spec encodings() :: [String.t()]
  def encodings, do: Registry.canonical_names()

  @doc """
  Registers a codec implemented by an external library.

  `:canonical` can replace the module's declared canonical name for this
  registration. This lets independent sources expose colliding codec names
  under source-qualified names without overriding a built-in. Module and
  option aliases remain active and subject to the normal conflict checks.
  """
  @spec register_codec(module(), keyword()) :: :ok | {:error, term()}
  def register_codec(module, options \\ []), do: ExternalRegistry.register(module, options)

  @doc """
  Registers a codec and returns an ownership token for conditional cleanup.

  This variant retains `register_codec/2` replacement semantics. A library
  should normally prefer `register_codec_if_absent/2` during application start.
  Registrations and their tokens survive a supervised registry-worker restart
  while the `:iconvex` application remains running.
  """
  @spec register_codec_owned(module(), keyword()) ::
          {:ok, registration_token()} | {:error, term()}
  def register_codec_owned(module, options \\ []),
    do: ExternalRegistry.register_owned(module, options)

  @doc """
  Atomically registers a codec only when that module is not already registered.

  Returns `{:ok, token}` for a new registration or `{:ok, :existing}` without
  replacing caller-owned metadata. Pass a returned token to
  `unregister_codec/2` during application shutdown. Registration replacement
  has one externally visible commit point, so concurrent lookups see either
  the complete old entry or the complete new entry.
  """
  @spec register_codec_if_absent(module(), keyword()) ::
          {:ok, registration_token() | :existing} | {:error, term()}
  def register_codec_if_absent(module, options \\ []),
    do: ExternalRegistry.register_if_absent(module, options)

  @doc "Removes a previously registered external codec."
  @spec unregister_codec(module()) :: :ok | {:error, term()}
  def unregister_codec(module), do: ExternalRegistry.unregister(module)

  @doc "Removes a codec only when `token` owns its current registration."
  @spec unregister_codec(module(), registration_token()) :: :ok | {:error, term()}
  def unregister_codec(module, token), do: ExternalRegistry.unregister(module, token)

  @doc "Resolves an encoding name, alias, built-in ID, or registered codec module."
  @spec canonical_name(encoding()) :: {:ok, String.t()} | :error
  def canonical_name(name) do
    case Registry.resolve(name) do
      {:ok, entry} -> {:ok, entry.canonical}
      :error -> :error
    end
  end

  @doc "Equivalent to `convert/4` with default options."
  @spec convert(binary(), encoding(), encoding()) :: conversion_result()
  def convert(input, from, to), do: convert(input, from, to, [])

  @doc """
  Converts a complete encoded binary.

  Invalid options and suffixes return typed request errors. Malformed source
  input returns `Iconvex.Error`. Destination handling follows GNU libiconv:
  ordinary unavailable characters error, while extended UCS values use U+FFFD
  when the destination family defines that fallback and can encode it.
  Discard, transliteration, and substitution options take precedence over the
  fallback. GNU suffixes such as `//IGNORE`, `//NON_IDENTICAL_DISCARD`, and
  `//TRANSLIT` may be appended to encoding names.
  """
  @spec convert(binary(), encoding(), encoding(), conversion_options()) :: conversion_result()
  def convert(input, from, to, options) when is_binary(input) do
    with :ok <- validate_options(options),
         {:ok, from, source_options} <- parse_source(from),
         {:ok, to, target_options} <- parse_target(to),
         options = normalize_options(source_options, target_options, options),
         {:ok, from_entry, to_entry, provider_snapshot} <- capture_routes(from, to) do
      Tables.with_provider_snapshot(provider_snapshot, fn ->
        convert_resolved(input, from_entry, to_entry, options)
      end)
    else
      :error -> {:error, :unknown_encoding}
      {:error, _reason} = error -> error
    end
  end

  def convert(_input, _from, _to, _options), do: {:error, {:invalid_argument, :input}}

  @doc "Equivalent to `stream/4` with default options."
  @spec stream(Enumerable.t(), encoding(), encoding()) ::
          {:ok, Enumerable.t()} | {:error, request_error()}
  def stream(enumerable, from, to), do: stream(enumerable, from, to, [])

  @doc """
  Creates a lazy, bounded-memory conversion stream.

  Input enumerable must emit binaries. Output stream emits converted binaries
  as source chunks become stable. Conversion errors raise `Iconvex.Error`
  during enumeration because earlier output may already have been consumed.

  Built-in stateful codecs carry designation, shift, Base64, and BOM state
  across chunks. External codecs opt in through the incremental callbacks in
  `Iconvex.Codec`; a missing callback returns
  `{:streaming_unsupported, role, encoding}` instead of silently buffering.
  """
  @spec stream(Enumerable.t(), encoding(), encoding(), conversion_options()) ::
          {:ok, Enumerable.t()} | {:error, request_error()}
  def stream(enumerable, from, to, options) do
    with {:ok, converter} <- new(from, to, options),
         {:ok, stream} <-
           Tables.with_provider_snapshot(converter.provider_snapshot, fn ->
             Iconvex.Stream.build(enumerable, converter)
           end) do
      {:ok, stream}
    end
  end

  @doc "Equivalent to `stream/4`, returning the stream or raising for request errors."
  @spec stream!(Enumerable.t(), encoding(), encoding(), conversion_options()) :: Enumerable.t()
  def stream!(enumerable, from, to, options \\ []) do
    case stream(enumerable, from, to, options) do
      {:ok, stream} -> stream
      {:error, :unknown_encoding} -> raise ArgumentError, "unknown character encoding"
      {:error, reason} -> raise ArgumentError, "invalid streaming request: #{inspect(reason)}"
    end
  end

  @doc "Equivalent to `convert!/4` with default options."
  @spec convert!(binary(), encoding(), encoding()) :: binary()
  def convert!(input, from, to), do: convert!(input, from, to, [])

  @doc "Converts a complete binary, raising for conversion or request errors."
  @spec convert!(binary(), encoding(), encoding(), conversion_options()) :: binary()
  def convert!(input, from, to, options) do
    case convert(input, from, to, options) do
      {:ok, output} -> output
      {:error, %Error{} = error} -> raise error
      {:error, :unknown_encoding} -> raise ArgumentError, "unknown character encoding"
      {:error, reason} -> raise ArgumentError, "invalid conversion request: #{inspect(reason)}"
    end
  end

  @doc "Equivalent to `new/3` with default options."
  @spec new(encoding(), encoding()) :: {:ok, Converter.t()} | {:error, request_error()}
  def new(from, to), do: new(from, to, [])

  @doc """
  Creates a buffered chunked converter.

  Encoding entries and table-provider routing are resolved once, so a converter
  remains stable if an external codec or its provider is later unregistered,
  replaced, or stopped.
  """
  @spec new(encoding(), encoding(), conversion_options()) ::
          {:ok, Converter.t()} | {:error, request_error()}
  def new(from, to, options) do
    with :ok <- validate_options(options),
         {:ok, source, source_options} <- parse_source(from),
         {:ok, target, target_options} <- parse_target(to),
         options = normalize_options(source_options, target_options, options),
         {:ok, from_entry, to_entry, provider_snapshot} <- capture_routes(source, target) do
      {:ok,
       %Converter{
         from: source,
         to: target,
         from_entry: from_entry,
         to_entry: to_entry,
         options: options,
         stateful_source?: true,
         provider_snapshot: provider_snapshot
       }}
    else
      :error -> {:error, :unknown_encoding}
      {:error, _reason} = error -> error
    end
  end

  defp capture_routes(from, to), do: capture_routes(from, to, 1)

  defp capture_routes(from, to, attempt) when attempt <= @route_capture_fast_retries do
    generation = RouteSnapshot.generation()
    result = resolve_routes(from, to)
    run_after_route_capture_hook(attempt)

    if RouteSnapshot.generation_current?(generation) do
      result
    else
      :erlang.yield()
      capture_routes(from, to, attempt + 1)
    end
  end

  defp capture_routes(from, to, _attempt) do
    case RouteSnapshot.serialized(fn ->
           run_before_serialized_route_resolve_hook()
           resolve_routes(from, to)
         end) do
      :route_retry ->
        :ok = ExternalRegistry.await_ready()
        capture_routes(from, to, 1)

      result ->
        result
    end
  end

  defp resolve_routes(from, to) do
    with {:ok, from_entry} <- Registry.resolve(from),
         {:ok, to_entry} <- Registry.resolve(to) do
      {:ok, from_entry, to_entry, Tables.provider_snapshot()}
    end
  end

  if Mix.env() == :test do
    defp run_after_route_capture_hook(attempt) do
      case Process.get({__MODULE__, :after_route_capture}) do
        {owner, reference, remaining}
        when is_pid(owner) and is_reference(reference) and is_integer(remaining) and
               remaining > 0 ->
          if remaining == 1 do
            Process.delete({__MODULE__, :after_route_capture})
          else
            Process.put({__MODULE__, :after_route_capture}, {owner, reference, remaining - 1})
          end

          send(owner, {:iconvex_route_capture_read, self(), reference, attempt})

          receive do
            {:continue_iconvex_route_capture, ^reference} -> :ok
          end

        _unset ->
          :ok
      end
    end

    defp run_before_serialized_route_resolve_hook do
      case Process.get({__MODULE__, :before_serialized_route_resolve}) do
        {owner, reference} when is_pid(owner) and is_reference(reference) ->
          Process.delete({__MODULE__, :before_serialized_route_resolve})
          send(owner, {:iconvex_serialized_route_resolve, self(), reference})

          receive do
            {:continue_iconvex_serialized_route_resolve, ^reference} -> :ok
          end

        _unset ->
          :ok
      end
    end
  else
    defp run_after_route_capture_hook(_attempt), do: :ok
    defp run_before_serialized_route_resolve_hook, do: :ok
  end

  @doc """
  Adds a binary chunk in O(1) time.

  Output is intentionally empty until finalization. Full buffering is the
  contract that makes chunked conversion exactly equivalent to `convert/4`
  across every possible byte split.
  """
  @spec feed(Converter.t(), binary()) ::
          {:ok, binary(), Converter.t()} | {:error, request_error()}
  def feed(%Converter{finished?: true}, _chunk), do: {:error, :already_finished}

  def feed(%Converter{} = converter, chunk) when is_binary(chunk) do
    {:ok, <<>>,
     %{
       converter
       | chunks: [chunk | converter.chunks],
         input_bytes: converter.input_bytes + byte_size(chunk)
     }}
  end

  def feed(%Converter{}, _chunk), do: {:error, {:invalid_argument, :chunk}}

  @doc """
  Performs the buffered conversion and returns its final output.

  Errors use byte offsets from the beginning of the complete stream. Because
  Elixir values are immutable, this compatibility function cannot mark the
  caller's converter finished; use `finish_with_state/1` when lifecycle checks
  are required.
  """
  @spec finish(Converter.t()) :: conversion_result()
  def finish(%Converter{finished?: true}), do: {:error, :already_finished}

  def finish(%Converter{} = converter) do
    case finish_conversion(converter) do
      {:ok, output} -> {:ok, output}
      error -> error
    end
  end

  @doc "Finalizes a buffered converter and returns its terminal state."
  @spec finish_with_state(Converter.t()) ::
          {:ok, binary(), Converter.t()} | {:error, Error.t() | request_error()}
  def finish_with_state(%Converter{finished?: true}), do: {:error, :already_finished}

  def finish_with_state(%Converter{} = converter) do
    case finish_conversion(converter) do
      {:ok, output} -> {:ok, output, %{converter | finished?: true}}
      error -> error
    end
  end

  defp finish_conversion(converter) do
    input =
      case converter.pending do
        <<>> -> converter.chunks |> :lists.reverse() |> IO.iodata_to_binary()
        overridden -> overridden
      end

    Tables.with_provider_snapshot(converter.provider_snapshot, fn ->
      convert_resolved(input, converter.from_entry, converter.to_entry, converter.options)
    end)
  end

  defp convert_resolved(input, from, to, options) do
    case fast_convert(input, from, to, options) do
      :miss ->
        input = source_surface_input(from, input, options[:from_surface])

        with {:ok, codepoints} <- decode_with_policy(from, to, input, options),
             {:ok, output} <- encode_with_policy(from, to, codepoints, options) do
          {:ok, output}
        else
          error -> conversion_error(error, from, to)
        end

      result ->
        case result do
          {:ok, _output} = success -> success
          error -> conversion_error(error, from, to)
        end
    end
  end

  defp fast_convert(input, %{id: :utf8}, %{id: :utf8}, options) do
    if strict_options?(options) and String.valid?(input), do: {:ok, input}, else: :miss
  end

  defp fast_convert(input, %{kind: :table} = from, %{id: :utf8}, options) do
    if strict_options?(options), do: TableCodec.decode_to_utf8(from, input), else: :miss
  end

  defp fast_convert(input, %{id: :utf8}, %{kind: :table} = to, options) do
    if strict_options?(options) do
      case TableCodec.encode_from_utf8(to, input) do
        {:encode_error, :unrepresentable_character, codepoint}
        when codepoint in 0xE0000..0xE007F ->
          :miss

        result ->
          result
      end
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{id: :utf8},
         options
       )
       when from_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard do
      UnicodeCodec.explicit_ucs4_to_utf8_discard(input, explicit_ucs4_endian(from_id))
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{kind: :external, codec: codec},
         options
       )
       when from_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard and
         is_nil(options[:on_invalid_byte]) and rem(byte_size(input), 4) == 0 do
      external_encode_from_explicit_ucs4_discard(
        codec,
        input,
        explicit_ucs4_endian(from_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{kind: :stateful, id: to_id} = to,
         options
       )
       when from_id in @explicit_ucs4_target_ids and
              to_id in @direct_stateful_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard and
         is_nil(options[:on_invalid_byte]) and rem(byte_size(input), 4) == 0 do
      StatefulCodec.encode_from_explicit_ucs4_discard(
        to,
        input,
        explicit_ucs4_endian(from_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{kind: :table} = to,
         options
       )
       when from_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard do
      TableCodec.encode_from_explicit_ucs4_discard(
        to,
        input,
        explicit_ucs4_endian(from_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :table} = from,
         %{kind: :unicode, id: to_id},
         options
       )
       when to_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:invalid] == :discard and
         is_nil(options[:on_invalid_byte]) do
      TableCodec.decode_to_explicit_ucs4_discard(
        from,
        input,
        explicit_ucs4_endian(to_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :gb18030} = from,
         %{kind: :unicode, id: to_id},
         options
       )
       when to_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:invalid] == :discard and
         is_nil(options[:on_invalid_byte]) do
      GB18030Codec.decode_to_explicit_ucs4_discard(
        from,
        input,
        explicit_ucs4_endian(to_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :stateful, id: from_id} = from,
         %{kind: :unicode, id: to_id},
         options
       )
       when from_id != :utf7 and to_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:invalid] == :discard and
         is_nil(options[:on_invalid_byte]) do
      StatefulCodec.decode_to_explicit_ucs4_discard(
        from,
        input,
        explicit_ucs4_endian(to_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :escape} = from,
         %{kind: :unicode, id: to_id},
         options
       )
       when to_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:invalid] == :discard and
         is_nil(options[:on_invalid_byte]) do
      EscapeCodec.decode_to_explicit_ucs4_discard(
        from,
        input,
        explicit_ucs4_endian(to_id)
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{id: :utf32be},
         %{id: :utf16},
         options
       ) do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard do
      with {:ok, filtered} <- remove_utf32be_fffe(input, []),
           output when is_binary(output) <-
             :unicode.characters_to_binary(filtered, {:utf32, :big}, {:utf16, :big}) do
        prefix = if output == <<>>, do: <<>>, else: <<0xFE, 0xFF>>
        {:ok, prefix <> output}
      else
        _unsupported_or_malformed -> :miss
      end
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{id: :utf16},
         %{kind: :unicode, id: to_id},
         options
       )
       when to_id == :utf32be or to_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) do
      with {:ok, filtered} <- remove_utf16be_boms(input),
           {:ok, to_encoding} <- direct_unicode_encoding(to_id),
           output when is_binary(output) <-
             :unicode.characters_to_binary(filtered, {:utf16, :big}, to_encoding) do
        {:ok, output}
      else
        _swapped_or_malformed -> :miss
      end
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{kind: :unicode, id: to_id},
         options
       )
       when (from_id in @explicit_ucs4_target_ids and to_id in @ucs2_target_ids) or
              (from_id in @ucs2_target_ids and to_id in @explicit_ucs4_target_ids) do
    cond do
      not direct_unicode_options?(options) ->
        :miss

      from_id in @explicit_ucs4_target_ids and options[:unrepresentable] == :discard ->
        UnicodeCodec.direct_convert(
          input,
          from_id,
          to_id,
          options[:invalid],
          options[:unrepresentable]
        )

      from_id in @ucs2_target_ids and options[:invalid] == :discard and
          is_nil(options[:on_invalid_byte]) ->
        UnicodeCodec.direct_convert(
          input,
          from_id,
          to_id,
          options[:invalid],
          options[:unrepresentable]
        )

      true ->
        :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{kind: :unicode, id: to_id},
         options
       )
       when (from_id in @explicit_ucs4_target_ids and to_id in @direct_ucs4_target_ids) or
              ((from_id in [:ucs4, :utf32] or from_id in @explicit_utf32_source_ids) and
                 to_id in @explicit_ucs4_target_ids) do
    if direct_unicode_options?(options) and
         (from_id not in [:ucs4, :utf32, :utf32be, :utf32le] or
            is_nil(options[:on_invalid_byte])) do
      UnicodeCodec.direct_convert(
        input,
        from_id,
        to_id,
        options[:invalid],
        options[:unrepresentable]
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{id: :c99},
         options
       )
       when from_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard do
      EscapeCodec.encode_c99_explicit_ucs4_discard(input, explicit_ucs4_endian(from_id))
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{id: :java},
         options
       )
       when from_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:unrepresentable] == :discard do
      EscapeCodec.encode_java_explicit_ucs4_discard(input, explicit_ucs4_endian(from_id))
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :unicode, id: from_id},
         %{kind: :unicode, id: to_id},
         options
       ) do
    with true <- direct_unicode_options?(options),
         {:ok, from_encoding} <- direct_unicode_encoding(from_id),
         {:ok, to_encoding} <- direct_unicode_encoding(to_id),
         output when is_binary(output) <-
           :unicode.characters_to_binary(input, from_encoding, to_encoding) do
      {:ok, output}
    else
      _unsupported_or_malformed -> :miss
    end
  end

  defp fast_convert(
         input,
         %{id: :utf7},
         %{kind: :unicode, id: to_id},
         options
       )
       when to_id in @explicit_ucs4_target_ids do
    if options[:invalid] == :discard and options[:on_invalid_byte] == nil and
         direct_unicode_options?(options) do
      case UTF7Codec.decode_discard_gnu_ucs4(input, explicit_ucs4_endian(to_id)) do
        {:ok, output} -> {:ok, output}
        :incomplete -> :miss
      end
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :external, codec: codec},
         %{kind: :unicode, id: to_id},
         options
       )
       when to_id in @explicit_ucs4_target_ids do
    if direct_unicode_options?(options) and options[:invalid] == :discard and
         is_nil(options[:on_invalid_byte]) do
      external_decode_to_explicit_ucs4_discard(
        codec,
        input,
        explicit_ucs4_endian(to_id),
        to_id
      )
    else
      :miss
    end
  end

  defp fast_convert(
         input,
         %{kind: :external, codec: codec},
         %{id: :utf8},
         options
       ) do
    if strict_options?(options), do: external_decode_to_utf8(codec, input), else: :miss
  end

  defp fast_convert(
         input,
         %{id: :utf8},
         %{kind: :external, stateful?: false, codec: codec},
         options
       ) do
    if strict_options?(options), do: external_encode_from_utf8(codec, input), else: :miss
  end

  defp fast_convert(
         input,
         %{id: :utf8},
         %{kind: :external, stateful?: true, codec: codec},
         options
       ) do
    if strict_options?(options), do: external_encode_from_utf8(codec, input), else: :miss
  end

  defp fast_convert(_input, _from, _to, _options), do: :miss

  defp external_decode_to_utf8(codec, input) do
    case ExternalCallbacks.call(codec, :decode_to_utf8, [input]) do
      {:called, {:ok, output}} when is_binary(output) ->
        if String.valid?(output), do: {:ok, output}, else: :miss

      {:called, {:error, kind, offset, sequence} = error}
      when kind in [:invalid_sequence, :incomplete_sequence] and is_integer(offset) and
             offset >= 0 and offset <= byte_size(input) and is_binary(sequence) ->
        error

      {:called, _malformed} ->
        :miss

      :missing ->
        :miss
    end
  end

  defp external_encode_from_utf8(codec, input) do
    case ExternalCallbacks.call(codec, :encode_from_utf8, [input]) do
      {:called, {:ok, output}} when is_binary(output) ->
        {:ok, output}

      {:called, {:error, :unrepresentable_character, codepoint}}
      when is_integer(codepoint) and codepoint >= 0 ->
        {:encode_error, :unrepresentable_character, codepoint}

      {:called, {:encode_error, :unrepresentable_character, codepoint} = error}
      when is_integer(codepoint) and codepoint >= 0 ->
        error

      {:called, {:decode_error, kind, offset, sequence} = error}
      when kind in [:invalid_sequence, :incomplete_sequence] and is_integer(offset) and
             offset >= 0 and offset <= byte_size(input) and is_binary(sequence) ->
        external_encode_prefix_error(codec, input, offset, error)

      {:called, _malformed} ->
        :miss

      :missing ->
        :miss
    end
  end

  defp external_encode_from_explicit_ucs4_discard(codec, input, endian) do
    case ExternalCallbacks.call(codec, :encode_from_ucs4_discard, [input, endian]) do
      {:called, {:ok, output}} when is_binary(output) -> {:ok, output}
      {:called, _unsupported_or_malformed_callback} -> :miss
      :missing -> :miss
    end
  end

  defp external_decode_to_explicit_ucs4_discard(codec, input, endian, to_id) do
    case ExternalCallbacks.call(codec, :decode_to_ucs4_discard, [input, endian]) do
      {:called, {:ok, output}} when is_binary(output) and rem(byte_size(output), 4) == 0 ->
        {:ok, output}

      {:called, _unsupported_or_malformed_callback} ->
        external_decode_to_explicit_ucs4(codec, input, to_id)

      :missing ->
        external_decode_to_explicit_ucs4(codec, input, to_id)
    end
  end

  defp external_decode_to_explicit_ucs4(codec, input, to_id) do
    case ExternalCallbacks.call(codec, :decode_to_utf8, [input]) do
      {:called, {:ok, utf8}} when is_binary(utf8) ->
        with {:ok, to_encoding} <- direct_unicode_encoding(to_id),
             output when is_binary(output) <-
               :unicode.characters_to_binary(utf8, :utf8, to_encoding) do
          {:ok, output}
        else
          _invalid_utf8_or_unsupported_target -> :miss
        end

      {:called, _strict_error_or_malformed_callback} ->
        :miss

      :missing ->
        :miss
    end
  end

  defp external_encode_prefix_error(_codec, _input, 0, error), do: error

  defp external_encode_prefix_error(codec, input, offset, error) do
    prefix = binary_part(input, 0, offset)

    case :unicode.characters_to_list(prefix, :utf8) do
      codepoints when is_list(codepoints) ->
        case codec.encode(codepoints) do
          {:ok, output} when is_binary(output) ->
            error

          {:error, :unrepresentable_character, codepoint}
          when is_integer(codepoint) and codepoint >= 0 ->
            {:encode_error, :unrepresentable_character, codepoint}

          {:encode_error, :unrepresentable_character, codepoint} = encode_error
          when is_integer(codepoint) and codepoint >= 0 ->
            encode_error

          _malformed ->
            :miss
        end

      _malformed_prefix ->
        :miss
    end
  end

  defp direct_unicode_options?(options) do
    options[:transliterate] == false and options[:byte_substitute] == nil and
      options[:unicode_substitute] == nil and options[:from_surface] == nil and
      options[:to_surface] == nil
  end

  defp direct_unicode_encoding(:utf8), do: {:ok, :utf8}
  defp direct_unicode_encoding(:utf16be), do: {:ok, {:utf16, :big}}
  defp direct_unicode_encoding(:utf16le), do: {:ok, {:utf16, :little}}
  defp direct_unicode_encoding(:utf32be), do: {:ok, {:utf32, :big}}
  defp direct_unicode_encoding(:utf32le), do: {:ok, {:utf32, :little}}
  defp direct_unicode_encoding(:ucs4be), do: {:ok, {:utf32, :big}}
  defp direct_unicode_encoding(:ucs4le), do: {:ok, {:utf32, :little}}

  defp direct_unicode_encoding(:ucs4internal),
    do: {:ok, {:utf32, :erlang.system_info(:endian)}}

  defp direct_unicode_encoding(:ucs4swapped) do
    endian = if :erlang.system_info(:endian) == :big, do: :little, else: :big
    {:ok, {:utf32, endian}}
  end

  defp direct_unicode_encoding(_id), do: :error

  defp explicit_ucs4_endian(:ucs4be), do: :big
  defp explicit_ucs4_endian(:ucs4le), do: :little
  defp explicit_ucs4_endian(:ucs4internal), do: :erlang.system_info(:endian)

  defp explicit_ucs4_endian(:ucs4swapped),
    do: if(:erlang.system_info(:endian) == :big, do: :little, else: :big)

  defp remove_utf32be_fffe(<<>>, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp remove_utf32be_fffe(<<0, 0, 0xFF, 0xFE, rest::binary>>, acc),
    do: remove_utf32be_fffe(rest, acc)

  defp remove_utf32be_fffe(<<unit::binary-size(4), rest::binary>>, acc),
    do: remove_utf32be_fffe(rest, [unit | acc])

  defp remove_utf32be_fffe(_unaligned, _acc), do: :error

  defp remove_utf16be_boms(input) when rem(byte_size(input), 2) == 1, do: :error

  defp remove_utf16be_boms(input) do
    markers = :binary.compile_pattern([<<0xFE, 0xFF>>, <<0xFF, 0xFE>>])
    remove_utf16be_boms(input, markers, 0, 0, [])
  end

  defp remove_utf16be_boms(input, markers, search_offset, segment_offset, acc) do
    input_size = byte_size(input)

    case :binary.match(input, markers, scope: {search_offset, input_size - search_offset}) do
      :nomatch ->
        suffix = binary_part(input, segment_offset, input_size - segment_offset)

        case acc do
          [] -> {:ok, suffix}
          _segments -> {:ok, acc |> :lists.reverse([suffix]) |> IO.iodata_to_binary()}
        end

      {offset, 2} when rem(offset, 2) == 1 ->
        remove_utf16be_boms(input, markers, offset + 1, segment_offset, acc)

      {offset, 2} ->
        case binary_part(input, offset, 2) do
          <<0xFE, 0xFF>> ->
            if utf16be_high_surrogate_before?(input, offset) do
              :surrogate_boundary
            else
              segment = binary_part(input, segment_offset, offset - segment_offset)
              remove_utf16be_boms(input, markers, offset + 2, offset + 2, [segment | acc])
            end

          <<0xFF, 0xFE>> ->
            :swapped
        end
    end
  end

  defp utf16be_high_surrogate_before?(input, offset) when offset >= 2 do
    case binary_part(input, offset - 2, 2) do
      <<high::unsigned-big-16>> when high in 0xD800..0xDBFF -> true
      _unit -> false
    end
  end

  defp utf16be_high_surrogate_before?(_input, _offset), do: false

  defp conversion_error({:error, kind, offset, sequence}, from, _to),
    do: conversion_error({:decode_error, kind, offset, sequence}, from, nil)

  defp conversion_error({:decode_error, kind, offset, sequence}, from, _to) do
    {:error,
     Error.exception(
       kind: kind,
       encoding: from.canonical,
       offset: offset,
       sequence: sequence
     )}
  end

  defp conversion_error({:encode_error, kind, codepoint}, _from, to),
    do: {:error, Error.exception(kind: kind, encoding: to.canonical, codepoint: codepoint)}

  defp conversion_error({:request_error, reason}, _from, _to), do: {:error, reason}

  defp strict_options?(options), do: options == @default_options

  defp decode_with_policy(entry, target, input, options) do
    case {options[:on_invalid_byte], options[:invalid], options[:byte_substitute]} do
      {nil, :discard, _format} ->
        decode_with_policy_mode(entry, input, :discard)

      {nil, :error, nil} ->
        decode_with_callback(
          entry,
          target,
          input,
          options,
          0,
          [],
          TargetArbitrator.init(),
          []
        )

      {nil, mode, nil} ->
        decode_with_policy_mode(entry, input, mode)

      {nil, _mode, format} ->
        if external_stateful_decoder?(entry) do
          Iconvex.Stream.__decode_complete_with_callback__(entry, target, input, options)
        else
          decode_substitute(entry, target, input, format, options, 0, [])
        end

      {_handler, _mode, _format} ->
        if callback_stream_decoder?(entry) do
          Iconvex.Stream.__decode_complete_with_callback__(entry, target, input, options)
        else
          decode_with_callback(
            entry,
            target,
            input,
            options,
            0,
            [],
            TargetArbitrator.init(),
            []
          )
        end
    end
  end

  defp callback_stream_decoder?(%{kind: :stateful}), do: true
  defp callback_stream_decoder?(entry), do: external_stateful_decoder?(entry)

  defp external_stateful_decoder?(%{
         kind: :external,
         stateful?: true,
         decode_error_recovery: :resynchronize,
         codec: codec
       }) do
    function_exported?(codec, :stream_decoder_init, 0) and
      function_exported?(codec, :decode_chunk, 3)
  end

  defp external_stateful_decoder?(_entry), do: false

  defp decode_with_callback(
         %{decode_error_recovery: :stop} = entry,
         target,
         input,
         options,
         base_offset,
         acc,
         target_probe,
         deferred_codepoints
       ) do
    case decode(entry, input) do
      {:ok, codepoints} ->
        {:ok, finish_decoded(acc, codepoints)}

      {:error, kind, offset, sequence}
      when kind in [:invalid_sequence, :incomplete_sequence] ->
        remaining = binary_part(input, offset, byte_size(input) - offset)
        consumption = __decode_error_consumption__(entry, kind, sequence)

        cond do
          is_integer(consumption) and consumption > 0 and
              byte_size(remaining) >= consumption ->
            <<byte, _rest::binary>> = remaining
            absolute_offset = base_offset + offset

            with {:ok, retained} <- decode_with_policy_mode(entry, input, :discard),
                 {:ok, _target_probe} <-
                   TargetArbitrator.probe(
                     target_probe,
                     entry,
                     target,
                     deferred_codepoints ++ retained,
                     options
                   ),
                 {:ok, replacement} <-
                   invalid_byte_replacement(
                     entry,
                     kind,
                     absolute_offset,
                     sequence,
                     byte,
                     options
                   ) do
              {:ok,
               acc
               |> :lists.reverse([retained, replacement])
               |> List.flatten()}
            end

          true ->
            source_error = {:decode_error, kind, base_offset + offset, sequence}

            case decode_with_policy_mode(entry, input, :discard) do
              {:ok, retained} ->
                arbitrate_terminal_source_error(
                  target_probe,
                  entry,
                  target,
                  deferred_codepoints ++ retained,
                  options,
                  source_error
                )

              _unavailable_prefix ->
                source_error
            end
        end
    end
  end

  defp decode_with_callback(
         entry,
         target,
         input,
         options,
         base_offset,
         acc,
         target_probe,
         deferred_codepoints
       ) do
    case decode(entry, input) do
      {:ok, codepoints} ->
        {:ok, finish_decoded(acc, codepoints)}

      {:error, kind, offset, sequence}
      when kind in [:invalid_sequence, :incomplete_sequence] ->
        {offset, sequence} =
          if options[:on_invalid_byte],
            do: callback_error_frame(entry, input, offset, sequence),
            else: {offset, sequence}

        prefix_codepoints = recovery_prefix_codepoints(entry, input, offset)
        remaining = binary_part(input, offset, byte_size(input) - offset)
        consumption = __decode_error_consumption__(entry, kind, sequence)

        cond do
          is_integer(consumption) and consumption > 0 and
              byte_size(remaining) >= consumption ->
            <<consumed::binary-size(consumption), rest::binary>> = remaining
            <<byte, _consumed_tail::binary>> = consumed
            absolute_offset = base_offset + offset

            with {:ok, target_probe} <-
                   TargetArbitrator.probe(
                     target_probe,
                     entry,
                     target,
                     deferred_codepoints ++ prefix_codepoints,
                     options
                   ),
                 {:ok, replacement} <-
                   invalid_byte_replacement(
                     entry,
                     kind,
                     absolute_offset,
                     sequence,
                     byte,
                     consumed,
                     options
                   ) do
              decode_with_callback(
                entry,
                target,
                rest,
                options,
                absolute_offset + consumption,
                [replacement, prefix_codepoints | acc],
                target_probe,
                replacement
              )
            end

          true ->
            arbitrate_terminal_source_error(
              target_probe,
              entry,
              target,
              deferred_codepoints ++ prefix_codepoints,
              options,
              {:decode_error, kind, base_offset + offset, sequence}
            )
        end
    end
  end

  defp arbitrate_terminal_source_error(
         target_probe,
         source,
         target,
         codepoints,
         options,
         source_error
       ) do
    case TargetArbitrator.probe(target_probe, source, target, codepoints, options) do
      {:ok, _target_probe} -> source_error
      earlier_target_error -> earlier_target_error
    end
  end

  # The strict UTF-7 decoder locates malformed shifted data immediately after
  # its `+` introducer. Callback recovery, like streaming and byte substitution,
  # replaces that introducer and replays the original shifted bytes as direct
  # input. Move only callback framing back to `+`; strict errors retain their
  # GNU-compatible offset and sequence.
  defp callback_error_frame(
         %{kind: :stateful, id: :utf7},
         input,
         offset,
         sequence
       )
       when is_integer(offset) and offset > 0 and is_binary(sequence) do
    shift_offset = offset - 1

    case input do
      <<_prefix::binary-size(shift_offset), ?+, rest::binary>>
      when byte_size(rest) >= byte_size(sequence) ->
        if binary_part(rest, 0, byte_size(sequence)) == sequence,
          do: {shift_offset, <<?+, sequence::binary>>},
          else: {offset, sequence}

      _not_a_shift_error ->
        {offset, sequence}
    end
  end

  defp callback_error_frame(_entry, _input, offset, sequence), do: {offset, sequence}

  defp decode_with_policy_mode(entry, input, :error) do
    case decode(entry, input) do
      {:ok, codepoints} -> {:ok, codepoints}
      {:error, kind, offset, sequence} -> {:decode_error, kind, offset, sequence}
    end
  end

  defp decode_with_policy_mode(%{kind: :external, codec: codec}, input, :discard),
    do: codec.decode_discard(input)

  defp decode_with_policy_mode(%{kind: :table} = entry, input, :discard),
    do: TableCodec.decode_discard(entry, input)

  defp decode_with_policy_mode(%{kind: :unicode, id: id} = entry, input, :discard)
       when id != :utf8,
       do: UnicodeCodec.decode_discard(entry, input)

  defp decode_with_policy_mode(%{kind: :stateful} = entry, input, :discard),
    do: StatefulCodec.decode_discard(entry, input)

  defp decode_with_policy_mode(entry, input, :discard), do: decode_discard(entry, input, [])

  defp decode_substitute(
         %{decode_error_recovery: :stop} = entry,
         target,
         input,
         format,
         options,
         _base_offset,
         acc
       ) do
    decode_with_stopping_recovery(
      entry,
      target,
      input,
      options,
      0,
      acc,
      fn _kind, _absolute_offset, _sequence, byte ->
        {:ok, format |> format_substitution(byte) |> String.to_charlist()}
      end
    )
  end

  defp decode_substitute(
         %{kind: :stateful} = entry,
         _target,
         input,
         format,
         _options,
         _base_offset,
         _acc
       ) do
    StatefulCodec.decode_substitute(entry, input, fn byte ->
      format |> format_substitution(byte) |> String.to_charlist()
    end)
  end

  defp decode_substitute(
         %{kind: :unicode, id: id} = entry,
         _target,
         input,
         format,
         _options,
         _base_offset,
         _acc
       )
       when id != :utf8 do
    UnicodeCodec.decode_substitute(entry, input, fn byte ->
      format |> format_substitution(byte) |> String.to_charlist()
    end)
  end

  defp decode_substitute(entry, target, input, format, options, base_offset, acc) do
    case decode(entry, input) do
      {:ok, codepoints} ->
        {:ok, finish_decoded(acc, codepoints)}

      {:error, kind, offset, sequence} when kind in [:invalid_sequence, :incomplete_sequence] ->
        prefix_codepoints = recovery_prefix_codepoints(entry, input, offset)
        remaining = binary_part(input, offset, byte_size(input) - offset)
        consumption = __decode_error_consumption__(entry, kind, sequence)

        cond do
          is_integer(consumption) and consumption > 0 and
              byte_size(remaining) >= consumption ->
            <<consumed::binary-size(consumption), rest::binary>> = remaining
            replacement = format_byte_substitutions(format, consumed)

            decode_substitute(
              entry,
              target,
              rest,
              format,
              options,
              base_offset + offset + consumption,
              [replacement, prefix_codepoints | acc]
            )

          true ->
            arbitrate_terminal_source_error(
              TargetArbitrator.init(),
              entry,
              target,
              finish_decoded(acc, prefix_codepoints),
              options,
              {:decode_error, kind, base_offset + offset, sequence}
            )
        end
    end
  end

  defp decode_discard(entry, input, acc) do
    case decode(entry, input) do
      {:ok, codepoints} ->
        {:ok, finish_decoded(acc, codepoints)}

      {:error, kind, offset, _sequence} when kind in [:invalid_sequence, :incomplete_sequence] ->
        prefix_codepoints = recovery_prefix_codepoints(entry, input, offset)

        if kind == :incomplete_sequence do
          {:ok, finish_decoded(acc, prefix_codepoints)}
        else
          tail_offset = min(offset + 1, byte_size(input))
          tail = binary_part(input, tail_offset, byte_size(input) - tail_offset)
          decode_discard(entry, tail, [prefix_codepoints | acc])
        end
    end
  end

  defp recovery_prefix_codepoints(_entry, _input, 0), do: []

  defp recovery_prefix_codepoints(%{kind: :escape} = entry, input, offset) do
    {:ok, codepoints} = EscapeCodec.decode_prefix(entry, input, offset)
    codepoints
  end

  defp recovery_prefix_codepoints(%{kind: :stateful} = entry, input, offset) do
    prefix = binary_part(input, 0, offset)

    case StatefulCodec.decode_chunk(
           entry,
           prefix,
           StatefulCodec.stream_init(entry),
           false,
           0
         ) do
      {:ok, codepoints, _source_state, _pending} -> codepoints
      _unstable_prefix -> []
    end
  end

  defp recovery_prefix_codepoints(%{kind: :external, codec: codec}, input, offset) do
    prefix = binary_part(input, 0, offset)

    case codec.decode(prefix) do
      {:ok, codepoints} ->
        codepoints

      # A stateful external codec can report a structural EOF at the physical
      # end of otherwise stable input. Its discard callback is the contract for
      # recovering those preceding codepoints so target errors can still win
      # when they occurred before the terminal source error.
      {:error, :incomplete_sequence, ^offset, _sequence} ->
        case codec.decode_discard(prefix) do
          {:ok, codepoints} -> codepoints
          _unrecoverable_prefix -> []
        end

      _unstable_prefix ->
        []
    end
  end

  defp recovery_prefix_codepoints(entry, input, offset) do
    prefix = binary_part(input, 0, offset)
    {:ok, codepoints} = decode(entry, prefix)
    codepoints
  end

  defp decode_with_stopping_recovery(
         entry,
         target,
         input,
         options,
         base_offset,
         acc,
         replacement_for_error
       ) do
    case decode(entry, input) do
      {:ok, codepoints} ->
        {:ok, finish_decoded(acc, codepoints)}

      {:error, kind, offset, sequence}
      when kind in [:invalid_sequence, :incomplete_sequence] ->
        remaining = binary_part(input, offset, byte_size(input) - offset)
        consumption = __decode_error_consumption__(entry, kind, sequence)

        cond do
          is_integer(consumption) and consumption > 0 and
              byte_size(remaining) >= consumption ->
            <<byte, _rest::binary>> = remaining
            absolute_offset = base_offset + offset

            case decode_with_policy_mode(entry, input, :discard) do
              {:ok, retained} ->
                case replacement_for_error.(kind, absolute_offset, sequence, byte) do
                  {:ok, replacement} ->
                    {:ok,
                     acc
                     |> :lists.reverse([retained, replacement])
                     |> List.flatten()}

                  error ->
                    error
                end

              error ->
                error
            end

          true ->
            arbitrate_terminal_source_error(
              TargetArbitrator.init(),
              entry,
              target,
              finish_decoded(acc, recovery_prefix_codepoints(entry, input, offset)),
              options,
              {:decode_error, kind, base_offset + offset, sequence}
            )
        end
    end
  end

  defp finish_decoded([], codepoints), do: codepoints

  defp finish_decoded(acc, codepoints),
    do: acc |> :lists.reverse([codepoints]) |> List.flatten()

  defp drop_unencodable_tags(%{kind: :external}, codepoints), do: codepoints

  defp drop_unencodable_tags(%{id: id}, codepoints) when id in @tag_capable_target_ids,
    do: codepoints

  defp drop_unencodable_tags(entry, codepoints) do
    Enum.reject(codepoints, fn
      codepoint when codepoint in 0xE0000..0xE007F -> not encodable?(entry, codepoint)
      _codepoint -> false
    end)
  end

  defp prepare_default_fallback(%{kind: :external}, codepoints, _options), do: codepoints

  defp prepare_default_fallback(entry, codepoints, options) do
    if options[:unrepresentable] == :error and is_nil(options[:unicode_substitute]) do
      map_default_fallback(entry, codepoints)
    else
      codepoints
    end
  end

  defp map_default_fallback(%{id: id}, codepoints) when id in @ucs2_target_ids do
    Enum.map(codepoints, fn
      codepoint when codepoint > 0xFFFF or codepoint in 0xD800..0xDFFF -> 0xFFFD
      0xFFFE when id == :ucs2 -> 0xFFFD
      codepoint -> codepoint
    end)
  end

  defp map_default_fallback(%{id: id}, codepoints)
       when id in @scalar_fallback_target_ids do
    Enum.map(codepoints, fn
      codepoint when codepoint > 0x10FFFF or codepoint in 0xD800..0xDFFF -> 0xFFFD
      0xFFFE when id == :utf16 -> 0xFFFD
      codepoint -> codepoint
    end)
  end

  defp map_default_fallback(%{id: id}, codepoints)
       when id in @surrogate_unit_target_ids do
    Enum.map(codepoints, fn
      codepoint when codepoint > 0x10FFFF -> 0xFFFD
      codepoint -> codepoint
    end)
  end

  defp map_default_fallback(%{id: :ucs4}, codepoints) do
    Enum.map(codepoints, fn
      codepoint when codepoint > 0x7FFFFFFF -> 0xFFFD
      codepoint -> codepoint
    end)
  end

  defp map_default_fallback(%{id: id}, codepoints) when id in @explicit_ucs4_target_ids do
    Enum.map(codepoints, fn
      codepoint when codepoint > 0xFFFFFFFF -> 0xFFFD
      codepoint -> codepoint
    end)
  end

  defp map_default_fallback(%{id: :c99}, codepoints) do
    Enum.map(codepoints, fn
      codepoint when codepoint > 0xFFFFFFFF -> 0xFFFD
      codepoint -> codepoint
    end)
  end

  defp map_default_fallback(_entry, codepoints), do: codepoints

  defp encode_with_policy(_from_entry, entry, codepoints, options) do
    unrepresentable = options[:unrepresentable]
    codepoints = target_surface_codepoints(entry, codepoints, options[:to_surface])
    codepoints = drop_unencodable_tags(entry, codepoints)

    codepoints =
      if options[:transliterate],
        do: transliterate(codepoints, entry),
        else: codepoints

    codepoints = prepare_default_fallback(entry, codepoints, options)
    encode_with_unrepresentable_policy(entry, codepoints, unrepresentable, options)
  end

  defp encode_with_unrepresentable_policy(entry, codepoints, unrepresentable, options) do
    case {unrepresentable, options[:unicode_substitute]} do
      {:discard, _format} -> encode_without_substitution(entry, codepoints, :discard)
      {_mode, nil} -> encode_without_substitution(entry, codepoints, unrepresentable)
      {_mode, format} -> encode_substitute(entry, codepoints, format, [])
    end
  end

  defp encode_without_substitution(entry, codepoints, unrepresentable) do
    case encode(entry, codepoints) do
      {:ok, output} ->
        {:ok, output}

      {:error, _kind, _codepoint} when unrepresentable == :discard ->
        encode_discard(entry, codepoints, [])

      {:error, kind, codepoint} ->
        {:encode_error, kind, codepoint}
    end
  end

  defp encode_substitute(%{kind: :table} = entry, codepoints, format, _acc) do
    entry
    |> TableCodec.encode_substitute(codepoints, substitution_replacer(format))
    |> substitution_result()
  end

  defp encode_substitute(%{kind: :unicode} = entry, codepoints, format, _acc) do
    entry
    |> UnicodeCodec.encode_substitute(codepoints, substitution_replacer(format))
    |> substitution_result()
  end

  defp encode_substitute(%{kind: :escape} = entry, codepoints, format, _acc) do
    entry
    |> EscapeCodec.encode_substitute(codepoints, substitution_replacer(format))
    |> substitution_result()
  end

  defp encode_substitute(%{kind: :gb18030} = entry, codepoints, format, _acc) do
    entry
    |> GB18030Codec.encode_substitute(codepoints, substitution_replacer(format))
    |> substitution_result()
  end

  defp encode_substitute(%{kind: :stateful} = entry, codepoints, format, _acc) do
    entry
    |> StatefulCodec.encode_substitute(codepoints, substitution_replacer(format))
    |> substitution_result()
  end

  defp encode_substitute(%{kind: :external, codec: codec}, codepoints, format, _acc) do
    case codec.encode_substitute(codepoints, substitution_replacer(format)) do
      {:ok, output} when is_binary(output) ->
        {:ok, output}

      {:error, :unrepresentable_character, codepoint}
      when is_integer(codepoint) and codepoint >= 0 ->
        {:encode_error, :unrepresentable_character, codepoint}

      malformed ->
        {:request_error,
         {:invalid_codec_callback_return, codec, {:encode_substitute, 2}, malformed}}
    end
  end

  defp substitution_replacer(format) do
    parts = substitution_parts(format)
    fn codepoint -> parts |> format_substitution_parts(codepoint) |> String.to_charlist() end
  end

  defp substitution_result({:error, kind, codepoint}),
    do: {:encode_error, kind, codepoint}

  defp substitution_result(result), do: result

  defp encode_discard(entry, codepoints, acc) do
    result =
      case entry.kind do
        :table -> TableCodec.encode_discard(entry, codepoints)
        :unicode -> UnicodeCodec.encode_discard(entry, codepoints)
        :escape -> EscapeCodec.encode_discard(entry, codepoints)
        :gb18030 -> GB18030Codec.encode_discard(entry, codepoints)
        :stateful -> StatefulCodec.encode_discard(entry, codepoints)
        :external -> entry.codec.encode_discard(codepoints)
      end

    case result do
      {:ok, output} -> {:ok, acc |> :lists.reverse([output]) |> IO.iodata_to_binary()}
      {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
      error -> error
    end
  end

  defp transliterate(codepoints, entry),
    do: Enum.flat_map(codepoints, &transliterate_codepoint(&1, entry, 0))

  defp transliterate_codepoint(codepoint, entry, depth) when depth < 16 do
    case encode(entry, [codepoint]) do
      {:ok, _output} ->
        [codepoint]

      {:error, _kind, _codepoint} ->
        case transliteration_for(codepoint, entry) do
          {:ok, replacement} ->
            Enum.flat_map(replacement, &transliterate_codepoint(&1, entry, depth + 1))

          :error ->
            [codepoint]
        end
    end
  end

  defp transliterate_codepoint(codepoint, _entry, _depth), do: [codepoint]

  defp transliteration_for(codepoint, entry) when codepoint in 0x2018..0x201A do
    cond do
      encodable?(entry, 0x2018) and encodable?(entry, 0x2019) ->
        {:ok, [if(codepoint == 0x201A, do: 0x2018, else: codepoint)]}

      encodable?(entry, 0x0060) and encodable?(entry, 0x00B4) ->
        {:ok, [if(codepoint == 0x2019, do: 0x00B4, else: 0x0060)]}

      true ->
        {:ok, [0x0027]}
    end
  end

  defp transliteration_for(codepoint, _entry) do
    case Transliterator.fetch(codepoint) do
      {:ok, []} -> :error
      result -> result
    end
  end

  defp encodable?(entry, codepoint), do: match?({:ok, _}, encode(entry, [codepoint]))

  defp invalid_byte_replacement(entry, kind, offset, sequence, byte, options),
    do: invalid_byte_replacement(entry, kind, offset, sequence, byte, <<byte>>, options)

  defp invalid_byte_replacement(entry, kind, offset, sequence, byte, consumed, options) do
    event = %InvalidByte{
      encoding: entry.canonical,
      kind: kind,
      offset: offset,
      byte: byte,
      sequence: sequence
    }

    decision =
      case options[:on_invalid_byte] do
        nil -> :default
        handler -> handler.(event)
      end

    case decision do
      :default ->
        default_invalid_byte_replacement(kind, offset, sequence, consumed, options)

      :error ->
        {:decode_error, kind, offset, sequence}

      :discard ->
        {:ok, []}

      {:replace, replacement} ->
        normalize_invalid_replacement(replacement)

      other ->
        {:request_error, {:invalid_callback_return, :on_invalid_byte, other}}
    end
  end

  defp default_invalid_byte_replacement(kind, offset, sequence, consumed, options) do
    cond do
      options[:invalid] == :discard ->
        {:ok, []}

      is_binary(options[:byte_substitute]) ->
        {:ok, format_byte_substitutions(options[:byte_substitute], consumed)}

      true ->
        {:decode_error, kind, offset, sequence}
    end
  end

  defp normalize_invalid_replacement(replacement) when is_binary(replacement) do
    if String.valid?(replacement),
      do: {:ok, String.to_charlist(replacement)},
      else: {:request_error, {:invalid_callback_return, :on_invalid_byte, replacement}}
  end

  defp normalize_invalid_replacement(replacement) when is_integer(replacement) do
    if valid_scalar?(replacement),
      do: {:ok, [replacement]},
      else: {:request_error, {:invalid_callback_return, :on_invalid_byte, replacement}}
  end

  defp normalize_invalid_replacement(replacement) when is_list(replacement) do
    if Enum.all?(replacement, &valid_scalar?/1),
      do: {:ok, replacement},
      else: {:request_error, {:invalid_callback_return, :on_invalid_byte, replacement}}
  end

  defp normalize_invalid_replacement(replacement),
    do: {:request_error, {:invalid_callback_return, :on_invalid_byte, replacement}}

  defp format_byte_substitutions(format, bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.flat_map(fn byte -> format |> format_substitution(byte) |> String.to_charlist() end)
  end

  defp valid_scalar?(value),
    do: is_integer(value) and value in 0..0x10FFFF and value not in 0xD800..0xDFFF

  @doc false
  def __stream_decode_strict__(entry, input), do: decode(entry, input)

  @doc false
  def __stream_invalid_bytes__(entry, kind, offset, sequence, consumed, options) do
    <<byte, _rest::binary>> = consumed
    invalid_byte_replacement(entry, kind, offset, sequence, byte, consumed, options)
  end

  @doc false
  def __decode_error_consumption__(%{kind: :unicode, id: id}, _kind, sequence)
      when id in @multibyte_unicode_ids and is_binary(sequence),
      do: max(byte_size(sequence), 1)

  def __decode_error_consumption__(%{kind: :gb18030}, :incomplete_sequence, sequence)
      when is_binary(sequence),
      do: max(byte_size(sequence), 1)

  def __decode_error_consumption__(%{kind: :stateful, id: id}, :incomplete_sequence, sequence)
      when id != :utf7 and is_binary(sequence),
      do: max(byte_size(sequence), 1)

  def __decode_error_consumption__(%{kind: :escape}, kind, sequence),
    do: EscapeCodec.decode_error_consumption(kind, sequence)

  def __decode_error_consumption__(%{kind: :table}, kind, sequence),
    do: TableCodec.decode_error_consumption(kind, sequence)

  def __decode_error_consumption__(%{kind: :external, codec: codec}, kind, sequence) do
    case ExternalCallbacks.call(codec, :decode_error_consumption, [kind, sequence]) do
      {:called, consumption} -> consumption
      :missing -> 1
    end
  end

  def __decode_error_consumption__(_entry, _kind, _sequence), do: 1

  @doc false
  def __stream_source_input__(entry, input, options),
    do: source_surface_input(entry, input, options[:from_surface])

  @doc false
  def __stream_prepare_target__(_from_entry, entry, codepoints, options) do
    codepoints = target_surface_codepoints(entry, codepoints, options[:to_surface])
    codepoints = drop_unencodable_tags(entry, codepoints)

    codepoints =
      if options[:transliterate], do: transliterate(codepoints, entry), else: codepoints

    prepare_default_fallback(entry, codepoints, options)
  end

  @doc false
  def __stream_encode_prepared__(entry, codepoints, options),
    do:
      encode_with_unrepresentable_policy(
        entry,
        codepoints,
        options[:unrepresentable],
        options
      )

  @doc false
  def __stream_encode_policy__(options) do
    case {options[:unrepresentable], options[:unicode_substitute]} do
      {:discard, _format} -> :discard
      {_mode, nil} -> :error
      {_mode, format} -> {:replace, substitution_replacer(format)}
    end
  end

  @doc false
  def __stream_strict_options__?(options), do: strict_options?(options)

  defp parse_source(source), do: parse_encoding(source, :source)
  defp parse_target(target), do: parse_encoding(target, :target)

  defp parse_encoding(encoding, direction) when is_binary(encoding) do
    [base | suffixes] = String.split(encoding, "/")

    case suffix_options(suffixes, direction) do
      {:ok, options} -> {:ok, base, options}
      error -> error
    end
  end

  defp parse_encoding(encoding, _direction), do: {:ok, encoding, []}

  defp suffix_options(suffixes, direction) do
    Enum.reduce_while(suffixes, {:ok, []}, fn suffix, {:ok, options} ->
      case String.upcase(suffix, :ascii) do
        "" ->
          {:cont, {:ok, options}}

        "IGNORE" ->
          {:cont, {:ok, Keyword.merge(options, invalid: :discard, unrepresentable: :discard)}}

        "NON_IDENTICAL_DISCARD" ->
          {:cont, {:ok, Keyword.put(options, :unrepresentable, :discard)}}

        "TRANSLIT" ->
          {:cont, {:ok, Keyword.put(options, :transliterate, true)}}

        "ZOS_UNIX" ->
          {:cont, {:ok, Keyword.put(options, surface_key(direction), :zos_unix)}}

        _ ->
          {:halt, {:error, {:invalid_suffix, suffix}}}
      end
    end)
  end

  defp surface_key(:source), do: :from_surface
  defp surface_key(:target), do: :to_surface

  defp normalize_options(source, target, explicit) do
    @default_options
    |> Keyword.merge(source)
    |> Keyword.merge(target)
    |> Keyword.merge(explicit)
  end

  defp validate_options(options) do
    cond do
      not is_list(options) or not Keyword.keyword?(options) ->
        {:error, {:invalid_options, :expected_keyword}}

      duplicate = duplicate_option(options) ->
        {:error, {:invalid_option, duplicate, :duplicate}}

      unknown = Enum.find(Keyword.keys(options), &(&1 not in @option_keys)) ->
        {:error, {:invalid_option, unknown, :unknown}}

      true ->
        validate_option_values(options)
    end
  end

  defp duplicate_option(options) do
    options
    |> Keyword.keys()
    |> Enum.frequencies()
    |> Enum.find_value(fn {key, count} -> if count > 1, do: key end)
  end

  defp validate_option_values(options) do
    Enum.reduce_while(options, :ok, fn
      {key, value}, :ok
      when key in [:invalid, :unrepresentable] and value in [:error, :discard] ->
        {:cont, :ok}

      {:transliterate, value}, :ok when is_boolean(value) ->
        {:cont, :ok}

      {key, value}, :ok when key in [:from_surface, :to_surface] and value in [nil, :zos_unix] ->
        {:cont, :ok}

      {key, nil}, :ok when key in [:byte_substitute, :unicode_substitute] ->
        {:cont, :ok}

      {:on_invalid_byte, nil}, :ok ->
        {:cont, :ok}

      {:on_invalid_byte, value}, :ok when is_function(value, 1) ->
        {:cont, :ok}

      {key, value}, :ok
      when key in [:byte_substitute, :unicode_substitute] and is_binary(value) ->
        case validate_substitution_format(value) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, {:invalid_option, key, reason}}}
        end

      {key, value}, :ok ->
        {:halt, {:error, {:invalid_option, key, {:invalid_value, value}}}}
    end)
  end

  defp validate_substitution_format(format) do
    if String.valid?(format) do
      case Regex.run(~r/^(.*?)%(0?)(\d*)([xX])(.*)$/s, format) do
        [_, _prefix, _zero, width_text, _conversion, _suffix] ->
          width = if width_text == "", do: 0, else: String.to_integer(width_text)
          if width <= @max_substitution_width, do: :ok, else: {:error, :width_too_large}

        nil ->
          {:error, :missing_hex_field}
      end
    else
      {:error, :invalid_utf8}
    end
  end

  defp source_surface_input(%{id: :ebcdic1047}, input, :zos_unix),
    do: swap_ebcdic_newlines(input)

  defp source_surface_input(_entry, input, _surface), do: input

  defp target_surface_codepoints(%{id: :ebcdic1047}, codepoints, :zos_unix),
    do: Enum.map(codepoints, &swap_ebcdic_codepoint/1)

  defp target_surface_codepoints(_entry, codepoints, _surface), do: codepoints

  defp swap_ebcdic_newlines(input) do
    for <<byte <- input>>, into: <<>>, do: <<swap_ebcdic_byte(byte)>>
  end

  defp swap_ebcdic_byte(0x15), do: 0x25
  defp swap_ebcdic_byte(0x25), do: 0x15
  defp swap_ebcdic_byte(value), do: value
  defp swap_ebcdic_codepoint(0x0A), do: 0x85
  defp swap_ebcdic_codepoint(0x85), do: 0x0A
  defp swap_ebcdic_codepoint(value), do: value

  defp format_substitution(format, value) do
    format
    |> substitution_parts()
    |> format_substitution_parts(value)
  end

  defp substitution_parts(format) do
    case Regex.run(~r/^(.*?)%(0?)(\d*)([xX])(.*)$/s, format) do
      [_, prefix, zero, width_text, conversion, suffix] ->
        width = if width_text == "", do: 0, else: String.to_integer(width_text)
        {prefix, zero, width, conversion, suffix}

      nil ->
        raise ArgumentError, "substitution format must contain a printf-style %x or %X field"
    end
  end

  defp format_substitution_parts({prefix, zero, width, conversion, suffix}, value) do
    digits = Integer.to_string(value, 16)

    digits =
      if conversion == "X",
        do: String.upcase(digits, :ascii),
        else: String.downcase(digits, :ascii)

    padding = if zero == "0", do: "0", else: " "
    prefix <> String.pad_leading(digits, width, padding) <> suffix
  end

  defp decode(%{kind: :table} = entry, input), do: TableCodec.decode(entry, input)
  defp decode(%{kind: :unicode} = entry, input), do: UnicodeCodec.decode(entry, input)
  defp decode(%{kind: :escape} = entry, input), do: EscapeCodec.decode(entry, input)
  defp decode(%{kind: :gb18030} = entry, input), do: GB18030Codec.decode(entry, input)
  defp decode(%{kind: :stateful} = entry, input), do: StatefulCodec.decode(entry, input)
  defp decode(%{kind: :external, codec: codec}, input), do: codec.decode(input)

  defp encode(%{kind: :table} = entry, codepoints), do: TableCodec.encode(entry, codepoints)
  defp encode(%{kind: :unicode} = entry, codepoints), do: UnicodeCodec.encode(entry, codepoints)
  defp encode(%{kind: :escape} = entry, codepoints), do: EscapeCodec.encode(entry, codepoints)
  defp encode(%{kind: :gb18030} = entry, codepoints), do: GB18030Codec.encode(entry, codepoints)
  defp encode(%{kind: :stateful} = entry, codepoints), do: StatefulCodec.encode(entry, codepoints)
  defp encode(%{kind: :external, codec: codec}, codepoints), do: codec.encode(codepoints)
end
