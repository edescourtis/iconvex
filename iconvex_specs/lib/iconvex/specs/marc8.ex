defmodule Iconvex.Specs.MARC8 do
  @moduledoc "MARC-8 and its complete LOC component-set repertoire."

  use Iconvex.Codec
  import Bitwise

  alias Iconvex.Specs.MARC8.Data

  defguardp scalar?(codepoint)
            when codepoint in 0..0xD7FF or codepoint in 0xE000..0x10FFFF

  @impl true
  def canonical_name, do: "MARC-8"

  @impl true
  def aliases, do: ["MARC8", "MARC_8", "csMARC8"]

  @impl true
  def codec_id, do: :marc8

  @impl true
  def stateful?, do: true

  def source, do: Data.fetch().source
  def coverage_summary, do: Data.fetch().coverage
  def mapping_entries, do: Data.fetch().entries

  @impl true
  def decode(input) when is_binary(input), do: decode_mode(input, :marc8)

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_mode(input, :marc8)

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_mode(codepoints, :marc8)

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_mode(codepoints, :marc8)

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_mode(codepoints, :marc8, replacer)

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  def sample_stream(%{kind: :primary} = entry) do
    data = Data.fetch()
    prefix = sample_prefix(entry, data)

    if entry.codepoint in [0x0360, 0x0361] do
      second_half = if entry.codepoint == 0x0361, do: <<0xEC>>, else: <<0xFB>>
      IO.iodata_to_binary([prefix, entry.bytes, "A", second_half, "B"])
    else
      if entry.combining do
        reset =
          if entry.invocation == :g0 and entry.set not in [:ascii, :ansel],
            do: designation(:ascii, :g0, data),
            else: <<>>

        IO.iodata_to_binary([prefix, entry.bytes, reset, "A"])
      else
        IO.iodata_to_binary([prefix, entry.bytes])
      end
    end
  end

  def decode_mode(input, mode) do
    state = initial_state(mode)

    case decode_loop(input, input, 0, state, [], Data.fetch(), mode) do
      {:ok, acc, state} -> finish_decode(input, acc, state)
      error -> error
    end
  end

  def decode_discard_mode(input, mode), do: decode_discard_chunks(input, mode, [])

  def encode_mode(codepoints, mode) do
    data = Data.fetch()

    with {:ok, expanded} <- expand_codepoints(codepoints, data, mode, []),
         {:ok, output, state} <- encode_groups(expanded, initial_state(mode), [], data, mode),
         {:ok, reset} <- finish_encode(state, mode) do
      {:ok, output |> :lists.reverse([reset]) |> IO.iodata_to_binary()}
    end
  end

  def encode_discard_mode(codepoints, mode) do
    filtered = Enum.filter(codepoints, &representable?(&1, Data.fetch(), mode))
    encode_discard_retry(filtered, mode)
  end

  def encode_substitute_mode(codepoints, mode, replacer)
      when mode in [:marc8, :ansel] and is_list(codepoints) and is_function(replacer, 1) do
    data = Data.fetch()

    with {:ok, expanded} <-
           expand_substitute_codepoints(codepoints, [], false, data, mode, [], replacer),
         {:ok, output, state} <-
           encode_substitute_groups(expanded, initial_state(mode), [], data, mode, replacer),
         {:ok, reset} <- finish_encode(state, mode) do
      {:ok, output |> :lists.reverse([reset]) |> IO.iodata_to_binary()}
    end
  end

  defp decode_loop(<<>>, _original, _offset, state, acc, _data, _mode),
    do: {:ok, acc, state}

  defp decode_loop(<<0x1B, _::binary>> = input, original, offset, state, acc, data, :marc8) do
    case parse_escape(input, data) do
      {:ok, plane, set, consumed} ->
        <<_escape::binary-size(consumed), rest::binary>> = input
        state = Map.put(state, plane, set)
        decode_loop(rest, original, offset + consumed, state, acc, data, :marc8)

      {:error, kind, sequence} ->
        {:error, kind, offset, sequence}
    end
  end

  defp decode_loop(input, original, offset, state, acc, data, mode) do
    case decode_token(input, state, data, mode) do
      {:ok, value, consumed, rest} ->
        case accept_decoded(value, offset, state, acc) do
          {:ok, next_state, next_acc} ->
            decode_loop(
              rest,
              original,
              offset + consumed,
              next_state,
              next_acc,
              data,
              mode
            )

          {:error, sequence} ->
            {:error, :invalid_sequence, offset, sequence}
        end

      {:error, kind, sequence} ->
        {:error, kind, offset, sequence}
    end
  end

  defp decode_token(<<byte, rest::binary>>, _state, data, _mode)
       when byte < 0x20 or byte in 0x80..0x9F do
    case Map.fetch(data.controls, byte) do
      {:ok, codepoint} -> {:ok, {:primary, codepoint, false}, 1, rest}
      :error -> {:error, :invalid_sequence, <<byte>>}
    end
  end

  defp decode_token(<<0x20, rest::binary>>, _state, _data, _mode),
    do: {:ok, {:primary, 0x20, false}, 1, rest}

  defp decode_token(<<byte, _::binary>>, _state, _data, _mode) when byte in [0x7F, 0xA0, 0xFF],
    do: {:error, :invalid_sequence, <<byte>>}

  defp decode_token(<<byte, _::binary>> = input, state, data, mode) do
    plane = if byte < 0x80, do: :g0, else: :g1
    set_id = if mode == :ansel, do: default_set(plane), else: Map.fetch!(state, plane)
    set = Map.fetch!(data.sets, set_id)
    width = set.width

    cond do
      byte_size(input) < width ->
        {:error, :incomplete_sequence, input}

      true ->
        <<encoded::binary-size(width), rest::binary>> = input

        if valid_plane_bytes?(encoded, plane, width) do
          key = normalize_plane_bytes(encoded, plane)

          case Map.fetch(set.decode, key) do
            {:ok, value} -> {:ok, value, width, rest}
            :error -> {:error, :invalid_sequence, encoded}
          end
        else
          {:error, :invalid_sequence, encoded}
        end
    end
  end

  defp decode_token(<<>>, _state, _data, _mode),
    do: {:error, :incomplete_sequence, <<>>}

  defp accept_decoded(
         {:second_half, codepoint},
         _offset,
         %{span: {:need_marker, codepoint, at}} = state,
         acc
       ),
       do: {:ok, %{state | span: {:need_base, codepoint, at}}, acc}

  defp accept_decoded({:second_half, _codepoint}, _offset, _state, _acc), do: {:error, <<>>}

  defp accept_decoded({:primary, codepoint, true}, offset, state, acc) do
    cond do
      match?({:need_marker, _, _}, state.span) ->
        {:error, <<>>}

      codepoint in [0x0360, 0x0361] and
          Enum.any?(state.pending, fn {pending, _} -> pending in [0x0360, 0x0361] end) ->
        {:error, <<>>}

      true ->
        {:ok, %{state | pending: [{codepoint, offset} | state.pending]}, acc}
    end
  end

  defp accept_decoded({:primary, codepoint, false}, _offset, state, acc) do
    cond do
      match?({:need_marker, _, _}, state.span) ->
        {:error, <<codepoint::utf8>>}

      true ->
        marks = state.pending |> Enum.reverse() |> Enum.map(&elem(&1, 0))
        output = [codepoint | marks]

        span =
          cond do
            match?({:need_base, _, _}, state.span) ->
              nil

            spanning =
                Enum.find(state.pending, fn {pending, _} -> pending in [0x0360, 0x0361] end) ->
              {span_codepoint, at} = spanning
              {:need_marker, span_codepoint, at}

            true ->
              nil
          end

        {:ok, %{state | pending: [], span: span}, :lists.reverse(output, acc)}
    end
  end

  defp finish_decode(_input, acc, %{pending: [], span: nil}), do: {:ok, :lists.reverse(acc)}

  defp finish_decode(input, _acc, %{pending: pending}) when pending != [] do
    {_codepoint, offset} = List.last(pending)
    sequence = binary_part(input, offset, byte_size(input) - offset)
    {:error, :incomplete_sequence, offset, sequence}
  end

  defp finish_decode(input, _acc, %{span: {_phase, _codepoint, offset}}) do
    sequence = binary_part(input, offset, byte_size(input) - offset)
    {:error, :incomplete_sequence, offset, sequence}
  end

  defp parse_escape(<<0x1B>>, _data), do: {:error, :incomplete_sequence, <<0x1B>>}

  defp parse_escape(<<0x1B, custom, _::binary>>, data) when custom in [?g, ?b, ?p, ?s] do
    set = if custom == ?s, do: :ascii, else: set_for_final(<<custom>>, data)

    if set == nil,
      do: {:error, :invalid_sequence, <<0x1B, custom>>},
      else: {:ok, :g0, set, 2}
  end

  defp parse_escape(<<0x1B, intermediate, rest::binary>> = input, data)
       when intermediate in [?(, ?,, ?), ?-] do
    plane = if intermediate in [?(, ?,], do: :g0, else: :g1
    parse_designation_final(input, rest, plane, 1, 2, data)
  end

  defp parse_escape(<<0x1B, ?$>>, _data),
    do: {:error, :incomplete_sequence, <<0x1B, ?$>>}

  defp parse_escape(<<0x1B, ?$, intermediate, rest::binary>> = input, data)
       when intermediate in [?), ?-, ?,] do
    plane = if intermediate in [?), ?-], do: :g1, else: :g0
    parse_designation_final(input, rest, plane, 3, 3, data)
  end

  defp parse_escape(<<0x1B, ?$, rest::binary>> = input, data),
    do: parse_designation_final(input, rest, :g0, 3, 2, data)

  defp parse_escape(<<0x1B, byte, _::binary>>, _data),
    do: {:error, :invalid_sequence, <<0x1B, byte>>}

  defp parse_designation_final(input, <<>>, _plane, _width, consumed, _data),
    do: {:error, :incomplete_sequence, binary_part(input, 0, consumed)}

  defp parse_designation_final(input, <<?!>>, _plane, _width, consumed, _data),
    do: {:error, :incomplete_sequence, binary_part(input, 0, consumed + 1)}

  defp parse_designation_final(input, rest, plane, width, consumed, data) do
    {final, final_size} =
      if String.starts_with?(rest, "!E"), do: {"!E", 2}, else: {binary_part(rest, 0, 1), 1}

    set_id = set_for_final(final, data)
    sequence = binary_part(input, 0, consumed + final_size)

    case set_id && Map.fetch!(data.sets, set_id) do
      %{width: ^width, custom: false} -> {:ok, plane, set_id, consumed + final_size}
      _ -> {:error, :invalid_sequence, sequence}
    end
  end

  defp set_for_final(final, data) do
    Enum.find_value(data.sets, fn {id, set} -> if set.final == final, do: id end)
  end

  defp valid_plane_bytes?(bytes, :g0, 1),
    do: Enum.all?(:binary.bin_to_list(bytes), &(&1 in 0x21..0x7E))

  defp valid_plane_bytes?(bytes, :g1, 1),
    do: Enum.all?(:binary.bin_to_list(bytes), &(&1 in 0xA1..0xFE))

  defp valid_plane_bytes?(bytes, :g0, 3),
    do: Enum.all?(:binary.bin_to_list(bytes), &(&1 in 0x20..0x7E))

  defp valid_plane_bytes?(bytes, :g1, 3),
    do: Enum.all?(:binary.bin_to_list(bytes), &(&1 in 0xA0..0xFE))

  defp normalize_plane_bytes(bytes, :g0), do: bytes

  defp normalize_plane_bytes(bytes, :g1),
    do: for(<<byte <- bytes>>, into: <<>>, do: <<byte &&& 0x7F>>)

  defp expand_codepoints([], _data, _mode, acc), do: {:ok, :lists.reverse(acc)}

  defp expand_codepoints([codepoint | rest], data, mode, acc) when is_integer(codepoint) do
    cond do
      not scalar?(codepoint) ->
        {:error, :unrepresentable_character, codepoint}

      candidate?(codepoint, data, mode) ->
        expand_codepoints(rest, data, mode, [codepoint | acc])

      true ->
        decomposition = :unicode.characters_to_nfd_list([codepoint])

        if decomposition != [codepoint] and Enum.all?(decomposition, &candidate?(&1, data, mode)) do
          expand_codepoints(rest, data, mode, :lists.reverse(decomposition, acc))
        else
          {:error, :unrepresentable_character, codepoint}
        end
    end
  end

  defp expand_codepoints([codepoint | _rest], _data, _mode, _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp expand_substitute_codepoints([], resume, true, data, mode, acc, replacer),
    do: expand_substitute_codepoints(resume, [], false, data, mode, acc, replacer)

  defp expand_substitute_codepoints([], [], false, _data, _mode, acc, _replacer),
    do: {:ok, :lists.reverse(acc)}

  defp expand_substitute_codepoints(
         [codepoint | rest],
         resume,
         replacement?,
         data,
         mode,
         acc,
         replacer
       )
       when is_integer(codepoint) do
    cond do
      scalar?(codepoint) and candidate?(codepoint, data, mode) ->
        expand_substitute_codepoints(
          rest,
          resume,
          replacement?,
          data,
          mode,
          [{codepoint, replacement?} | acc],
          replacer
        )

      scalar?(codepoint) ->
        decomposition = :unicode.characters_to_nfd_list([codepoint])

        if decomposition != [codepoint] and Enum.all?(decomposition, &candidate?(&1, data, mode)) do
          tagged = Enum.map(decomposition, &{&1, replacement?})

          expand_substitute_codepoints(
            rest,
            resume,
            replacement?,
            data,
            mode,
            :lists.reverse(tagged, acc),
            replacer
          )
        else
          substitute_expansion_error(
            codepoint,
            rest,
            resume,
            replacement?,
            data,
            mode,
            acc,
            replacer
          )
        end

      true ->
        substitute_expansion_error(
          codepoint,
          rest,
          resume,
          replacement?,
          data,
          mode,
          acc,
          replacer
        )
    end
  end

  defp expand_substitute_codepoints(
         [codepoint | rest],
         resume,
         replacement?,
         data,
         mode,
         acc,
         replacer
       ),
       do:
         substitute_expansion_error(
           codepoint,
           rest,
           resume,
           replacement?,
           data,
           mode,
           acc,
           replacer
         )

  defp substitute_expansion_error(
         codepoint,
         _rest,
         _resume,
         true,
         _data,
         _mode,
         _acc,
         _replacer
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp substitute_expansion_error(
         codepoint,
         rest,
         _resume,
         false,
         data,
         mode,
         acc,
         replacer
       ),
       do:
         expand_substitute_codepoints(
           replacer.(codepoint),
           rest,
           true,
           data,
           mode,
           acc,
           replacer
         )

  defp encode_groups([], %{encode_span: nil} = state, acc, _data, _mode),
    do: {:ok, acc, state}

  defp encode_groups([], %{encode_span: codepoint}, _acc, _data, _mode),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_groups([base | rest], state, acc, data, mode) do
    if MapSet.member?(data.combining, base) do
      {:error, :unrepresentable_character, base}
    else
      {marks, tail} = Enum.split_while(rest, &MapSet.member?(data.combining, &1))
      span_marks = Enum.filter(marks, &(&1 in [0x0360, 0x0361]))

      cond do
        length(span_marks) > 1 ->
          {:error, :unrepresentable_character, hd(span_marks)}

        span_marks != [] and tail == [] ->
          {:error, :unrepresentable_character, hd(span_marks)}

        true ->
          with {:ok, state, acc} <- emit_pending_second_half(state, acc, data, mode),
               {:ok, state, acc} <- emit_many(marks, state, acc, data, mode),
               {:ok, state, acc} <- emit_codepoint(base, state, acc, data, mode) do
            next_span = List.first(span_marks)
            encode_groups(tail, %{state | encode_span: next_span}, acc, data, mode)
          end
      end
    end
  end

  defp encode_substitute_groups(
         [],
         %{encode_span: nil} = state,
         acc,
         _data,
         _mode,
         _replacer
       ),
       do: {:ok, acc, state}

  defp encode_substitute_groups(
         [],
         %{encode_span: {codepoint, true}},
         _acc,
         _data,
         _mode,
         _replacer
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute_groups(
         [],
         %{encode_span: {codepoint, false}} = state,
         acc,
         data,
         mode,
         replacer
       ) do
    retry_substitution_token([], {codepoint, false}, state, acc, data, mode, replacer)
  end

  defp encode_substitute_groups(
         [{base, _replacement?} = base_token | rest] = input,
         state,
         acc,
         data,
         mode,
         replacer
       ) do
    if MapSet.member?(data.combining, base) do
      retry_substitution_token(input, base_token, state, acc, data, mode, replacer)
    else
      {marks, tail} =
        Enum.split_while(rest, fn {codepoint, _replacement?} ->
          MapSet.member?(data.combining, codepoint)
        end)

      span_marks =
        Enum.filter(marks, fn {codepoint, _replacement?} -> codepoint in [0x0360, 0x0361] end)

      cond do
        match?([_, _ | _], span_marks) ->
          retry_substitution_token(
            input,
            hd(span_marks),
            state,
            acc,
            data,
            mode,
            replacer
          )

        span_marks != [] and tail == [] ->
          retry_substitution_token(
            input,
            hd(span_marks),
            state,
            acc,
            data,
            mode,
            replacer
          )

        true ->
          mark_codepoints = Enum.map(marks, &elem(&1, 0))

          with {:ok, state, acc} <- emit_substitution_pending_second_half(state, acc, data, mode),
               {:ok, state, acc} <- emit_many(mark_codepoints, state, acc, data, mode),
               {:ok, state, acc} <- emit_codepoint(base, state, acc, data, mode) do
            next_span = List.first(span_marks)

            encode_substitute_groups(
              tail,
              %{state | encode_span: next_span},
              acc,
              data,
              mode,
              replacer
            )
          else
            {:error, :unrepresentable_character, codepoint} ->
              case Enum.find(input, &(elem(&1, 0) == codepoint)) do
                nil -> {:error, :unrepresentable_character, codepoint}
                token -> retry_substitution_token(input, token, state, acc, data, mode, replacer)
              end
          end
      end
    end
  end

  defp retry_substitution_token(
         _input,
         {codepoint, true},
         _state,
         _acc,
         _data,
         _mode,
         _replacer
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp retry_substitution_token(
         input,
         {codepoint, false} = token,
         state,
         acc,
         data,
         mode,
         replacer
       ) do
    case Enum.split_while(input, &(&1 != token)) do
      {_prefix, []} ->
        {:error, :unrepresentable_character, codepoint}

      {prefix, [_token | suffix]} ->
        with {:ok, replacement} <-
               expand_substitute_codepoints(
                 replacer.(codepoint),
                 [],
                 true,
                 data,
                 mode,
                 [],
                 replacer
               ) do
          encode_substitute_groups(
            prefix ++ replacement ++ suffix,
            %{state | encode_span: nil},
            acc,
            data,
            mode,
            replacer
          )
        end
    end
  end

  defp emit_many(codepoints, state, acc, data, mode) do
    Enum.reduce_while(codepoints, {:ok, state, acc}, fn codepoint, {:ok, state, acc} ->
      case emit_codepoint(codepoint, state, acc, data, mode) do
        {:ok, state, acc} -> {:cont, {:ok, state, acc}}
        error -> {:halt, error}
      end
    end)
  end

  defp emit_pending_second_half(%{encode_span: nil} = state, acc, _data, _mode),
    do: {:ok, state, acc}

  defp emit_pending_second_half(%{encode_span: codepoint} = state, acc, data, mode) do
    marker = if codepoint == 0x0361, do: <<0xEC>>, else: <<0xFB>>

    with {:ok, state, acc} <- ensure_set(:ansel, :g1, state, acc, data, mode) do
      {:ok, %{state | encode_span: nil}, [marker | acc]}
    end
  end

  defp emit_substitution_pending_second_half(%{encode_span: nil} = state, acc, _data, _mode),
    do: {:ok, state, acc}

  defp emit_substitution_pending_second_half(
         %{encode_span: {codepoint, _replacement?}} = state,
         acc,
         data,
         mode
       ) do
    marker = if codepoint == 0x0361, do: <<0xEC>>, else: <<0xFB>>

    with {:ok, state, acc} <- ensure_set(:ansel, :g1, state, acc, data, mode) do
      {:ok, %{state | encode_span: nil}, [marker | acc]}
    end
  end

  defp emit_codepoint(codepoint, state, acc, data, mode) do
    candidates = candidates(codepoint, data, mode)

    candidate =
      Enum.find(candidates, fn candidate ->
        candidate.invocation == :control or
          (candidate.invocation == :g0 and state.g0 == candidate.set) or
          (candidate.invocation == :g1 and state.g1 == candidate.set)
      end) || List.first(candidates)

    if candidate == nil do
      {:error, :unrepresentable_character, codepoint}
    else
      with {:ok, state, acc} <-
             ensure_set(candidate.set, candidate.invocation, state, acc, data, mode) do
        {:ok, state, [candidate.bytes | acc]}
      end
    end
  end

  defp ensure_set(_set, :control, state, acc, _data, _mode), do: {:ok, state, acc}

  defp ensure_set(set, plane, state, acc, _data, _mode) when :erlang.map_get(plane, state) == set,
    do: {:ok, state, acc}

  defp ensure_set(_set, _plane, _state, _acc, _data, :ansel),
    do: {:error, :unrepresentable_character, :designation}

  defp ensure_set(set, plane, state, acc, data, :marc8) do
    escape = designation(set, plane, data)
    {:ok, Map.put(state, plane, set), [escape | acc]}
  end

  defp designation(:ascii, :g0, _data), do: <<0x1B, ?(, ?B>>
  defp designation(:ansel, :g1, _data), do: <<0x1B, ?), ?!, ?E>>

  defp designation(set_id, plane, data) do
    set = Map.fetch!(data.sets, set_id)

    cond do
      set.custom and plane == :g0 -> <<0x1B>> <> set.final
      set.width == 1 and plane == :g0 -> <<0x1B, ?(>> <> set.final
      set.width == 1 and plane == :g1 -> <<0x1B, ?)>> <> set.final
      set.width == 3 and plane == :g0 -> <<0x1B, ?$>> <> set.final
      set.width == 3 and plane == :g1 -> <<0x1B, ?$, ?)>> <> set.final
    end
  end

  defp finish_encode(state, :marc8) do
    if state.g0 == :ascii, do: {:ok, <<>>}, else: {:ok, designation(:ascii, :g0, Data.fetch())}
  end

  defp finish_encode(_state, :ansel), do: {:ok, <<>>}

  defp candidates(codepoint, data, :marc8), do: Map.get(data.candidates, codepoint, [])

  defp candidates(codepoint, data, :ansel) do
    data.candidates
    |> Map.get(codepoint, [])
    |> Enum.filter(&(&1.set in [:ascii, :ansel]))
  end

  defp candidate?(codepoint, data, mode), do: candidates(codepoint, data, mode) != []

  defp representable?(codepoint, data, mode) when is_integer(codepoint) and scalar?(codepoint) do
    candidate?(codepoint, data, mode) or
      case :unicode.characters_to_nfd_list([codepoint]) do
        [^codepoint] -> false
        values -> Enum.all?(values, &candidate?(&1, data, mode))
      end
  end

  defp representable?(_codepoint, _data, _mode), do: false

  defp encode_discard_retry(codepoints, mode) do
    case encode_mode(codepoints, mode) do
      {:ok, _bytes} = ok ->
        ok

      {:error, :unrepresentable_character, codepoint} ->
        case Enum.split_while(codepoints, &(&1 != codepoint)) do
          {_prefix, []} -> {:ok, <<>>}
          {prefix, [_ | rest]} -> encode_discard_retry(prefix ++ rest, mode)
        end
    end
  end

  defp decode_discard_chunks(<<>>, _mode, acc),
    do: {:ok, acc |> :lists.reverse() |> List.flatten()}

  defp decode_discard_chunks(input, mode, acc) do
    case decode_mode(input, mode) do
      {:ok, codepoints} ->
        {:ok, acc |> :lists.reverse([codepoints]) |> List.flatten()}

      {:error, _kind, offset, sequence} ->
        prefix = binary_part(input, 0, offset)

        prefix_output =
          case decode_mode(prefix, mode) do
            {:ok, values} -> values
            _ -> []
          end

        discard = max(byte_size(sequence), 1)
        start = min(offset + discard, byte_size(input))
        rest = binary_part(input, start, byte_size(input) - start)
        decode_discard_chunks(rest, mode, [prefix_output | acc])
    end
  end

  defp sample_prefix(%{invocation: :control}, _data), do: <<>>
  defp sample_prefix(%{set: :ascii}, _data), do: <<>>
  defp sample_prefix(%{set: :ansel}, _data), do: <<>>
  defp sample_prefix(entry, data), do: designation(entry.set, entry.invocation, data)

  defp initial_state(mode) do
    %{
      encode_span: nil,
      g0: :ascii,
      g1: :ansel,
      mode: mode,
      pending: [],
      span: nil
    }
  end

  defp default_set(:g0), do: :ascii
  defp default_set(:g1), do: :ansel
end
