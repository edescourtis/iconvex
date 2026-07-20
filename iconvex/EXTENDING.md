# External codecs

The sibling `iconvex_extras` package is the reference large external codec
library. It auto-registers 86 codecs, keeps their 85 packed mapping tables in
its own OTP application, and uses stable `codec_id/0` values to share Iconvex's
native table/state-machine engines without copying those engines.

External Hex libraries can add codecs without changing or recompiling Iconvex.
Each codec is an Elixir module implementing `Iconvex.Codec`, then registered by
application configuration or at runtime.

## Codec contract

`use Iconvex.Codec` supplies default `aliases/0` and `stateful?/0` callbacks.
The four conversion callbacks remain required:

```elixir
defmodule MyCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-MY-CODEC"

  @impl true
  def aliases, do: ["MYCODEC"]

  @impl true
  def decode(encoded_binary) do
    # Success: {:ok, [unicode_codepoint]}
    # Failure: {:error, :invalid_sequence | :incomplete_sequence,
    #           byte_offset, offending_binary}
  end

  @impl true
  def decode_discard(encoded_binary) do
    # Decode in one pass while discarding malformed encoded input.
  end

  @impl true
  def encode(unicode_codepoints) do
    # Success: {:ok, encoded_binary}
    # Failure: {:error, :unrepresentable_character, unicode_codepoint}
  end

  @impl true
  def encode_discard(unicode_codepoints) do
    # Encode in one pass while discarding unrepresentable code points.
  end
end
```

Discard callbacks are required. This keeps discard conversion linear and lets
stateful or multi-code-point codecs preserve their own state and longest-match
rules. A stateful codec should override `stateful?/0` with `true` as metadata.
The `new/feed/finish` API buffers every source until finalization. `stream/4`
instead requires the optional incremental callbacks below; it never silently
turns an unsupported external codec into a whole-input buffer.
Setting `stateful?/0` does not make those optional callbacks mandatory for
one-shot conversion: substitution and invalid-byte handlers continue through
the required whole-input callbacks when the incremental pair is absent.

Names must be non-empty printable ASCII without `/`. Lookup is case-insensitive.
Built-in names and aliases cannot be replaced.

When two specifications declare the same canonical name, `:canonical` replaces
the module-declared name for one registration without overriding the other
codec. The replaced name is not implicitly retained as an alias. Module aliases
and explicit `:aliases` remain active, and every resulting name still passes
the same built-in and external conflict checks:

```elixir
:ok =
  Iconvex.register_codec(MyCodec,
    canonical: "MY-SOURCE-X-MY-CODEC",
    aliases: ["MY-SOURCE-MYCODEC"]
  )
```

`codec_id/0` is optional and defaults to the codec module. A package sharing a
generated engine across many wrapper modules may return a stable existing atom,
as `iconvex_extras` does. Never create codec IDs from runtime input.

## Registration

Consumer configuration loads codecs when Iconvex starts:

```elixir
# config/config.exs
config :iconvex,
  external_codecs: [
    MyLibrary.MyCodec,
    {AnotherLibrary.Codec,
     canonical: "ANOTHER-SOURCE-CODEC", aliases: ["LOCAL-ALIAS"]}
  ]
```

An external library can instead register from its own application startup,
after its `:iconvex` dependency has started:

```elixir
case Iconvex.register_codec_if_absent(MyLibrary.MyCodec) do
  {:ok, :existing} -> :caller_owned
  {:ok, token} -> {:library_owned, token}
end
```

Keep a newly returned token in the application's state and call
`Iconvex.unregister_codec(MyLibrary.MyCodec, token)` on shutdown. Conditional
unregistration is a no-op if another caller has since replaced the
registration. `register_codec_owned/2` also returns a token but intentionally
retains the replacement semantics of `register_codec/2`; use it only when the
caller explicitly intends to replace the module's current registration.
Versioned recovery snapshots preserve registrations and exact tokens across
consecutive supervised registry-worker crashes while the `:iconvex`
application remains running. A clean application stop erases the snapshot, so
registrations do not cross a deliberate stop/start boundary. Replacement has
one visible commit point, so concurrent lookups see a complete old or complete
new entry.

Registration is serialized and rare. Conversion lookup reads a protected ETS
table configured for concurrent reads; no registry process call occurs on the
conversion path. Registration validates callbacks and metadata and returns a
descriptive error for invalid codecs or name collisions. The ownership API
avoids replacing or removing registrations created by another application;
unconditional `register_codec/2` and `unregister_codec/1` remain available for
explicit administrative replacement and cleanup.

Strict per-commit durability is deliberate. Every successful registry
mutation writes a synchronous recovery snapshot of the complete registry to
`:persistent_term`; replacing that term can schedule VM-wide garbage
collection. Registration therefore belongs on the control plane, not a
request hot path. A package with many codecs should use the internal
`register_set` path, which publishes the set atomically and amortizes the
snapshot to one checkpoint. Debouncing the write would weaken the documented
consecutive worker-crash guarantee.

The distributed Extras, Telecom, and Specs applications use an internal
package-set registration path because their independently sourced inventories
have 227 intentional Specs/Extras name overlaps. A complete set is published
or removed at one commit point. Claims are ranked canonical before alias, then
by fixed package priority; removing the winner exposes the retained fallback
without an intermediate miss. All six extension start orders produce the same
2,093 canonical-name registry. This mechanism is deliberately not the public
extension contract: third-party codecs continue to use the strict APIs above,
and a distinct module claiming any visible or retained managed name receives a
name-conflict error.

After registration, canonical name, aliases, or the module itself can identify
the codec:

```elixir
{:ok, output} = Iconvex.convert(input, "MYCODEC", "UTF-8")
{:ok, output} = Iconvex.convert(input, MyLibrary.MyCodec, "UTF-8")
{:ok, "X-MY-CODEC"} = Iconvex.canonical_name("mycodec")
true = "X-MY-CODEC" in Iconvex.encodings()
```

## Required linear substitution

Every external codec implements the substitution callback:

```elixir
@impl true
def encode_substitute(codepoints, replacer) do
  # Encode in one pass. At an unrepresentable source code point, encode
  # replacer.(codepoint) at that exact stream position.
end
```

`replacer` returns a Unicode code-point list produced from the user's
`unicode_substitute` format. The callback must preserve normal longest-match and
state rules, must not recursively substitute an unrepresentable character in
the replacement, and must return
`{:error, :unrepresentable_character, replacement_codepoint}` in that case.
Built-in engines implement this path in one pass. An external codec without
the callback is rejected at registration. A malformed
callback result returns the typed request error
`{:invalid_codec_callback_return, module, {:encode_substitute, 2}, result}`.
This explicit contract avoids repeated prefix probes, which cannot preserve
both stateful and longest-match semantics with a generic linear algorithm.

## Optional decode-recovery metadata

Generic source recovery decodes a valid prefix, consumes one invalid byte, and
continues. A fixed-width codec whose invalid unit spans more than one byte must
preserve framing by declaring its consumption width:

```elixir
@impl true
def decode_error_consumption(_kind, sequence) do
  if byte_size(sequence) >= 2, do: 2, else: 1
end
```

`sequence` remains the complete error sequence in `Iconvex.InvalidByte`; its
`byte` field is the first consumed byte for `%02x` and callback compatibility.

A whole-string transform such as Punycode cannot decode its byte prefix and
then restart at the next byte: generalized-integer state would be lost. Such a
codec must instead declare:

```elixir
@impl true
def decode_error_recovery, do: :stop
```

On the first strict error, Iconvex uses the codec's native `decode_discard/1`
result as the retained prefix, invokes one invalid-byte callback or appends one
byte substitution, and does not reinterpret the desynchronized tail. The
default is `:resynchronize`; registration rejects any other metadata value.
Lazy `stream/4` rejects a `:stop` source even if it exports a chunk callback,
because restart-free recovery requires a whole-string transaction. Buffered
`new/feed/finish` remains supported and exactly follows the one-shot result.

## Invalid-byte callback ordering

One-shot conversion reports the first failure in stream order. Before Iconvex
invokes `on_invalid_byte` for a malformed source unit, it arbitrates the valid
Unicode prefix against the target. An earlier unrepresentable target character
therefore wins and the later invalid-byte callback is not invoked. Replacements
returned by an earlier callback participate in arbitration before any later
invalid-byte callback.

Built-in targets keep bounded incremental encoder state for this arbitration.
An external target that exports `encode_chunk/3`, or a stateful target that
exports `stream_encoder_init/0` and `encode_chunk/4`, gets the same linear path;
`final?` is `false`, and longest-match pending code points and encoder state are
carried between malformed-source boundaries. Before invoking the handler,
Iconvex also validates a copy of that pending state with `final?` set to `true`.
Only the non-final state is retained after validation succeeds. Consequently a
callback replacement cannot rescue a target prefix that is already
unrepresentable at the earlier source position.

Without those incremental target callbacks, Iconvex preserves ordering by
calling the required encoder on cumulative valid prefixes at invalid-source
boundaries. It can then call the required encoder once more for the final
one-shot result. With many malformed units this fallback can be quadratic, so
external encoder callbacks must be deterministic and safe to invoke more than
once. They should not use observable side effects as conversion semantics.
Implement the incremental target callbacks to avoid cumulative-prefix probes.
A valid source does not cause an arbitration probe.

This is not a lazy Stream fallback: `stream/4` rejects such a target. Since
`encode/1` is an opaque whole-list transform, state or longest-match context can
make a delta valid alone but invalid after the retained prefix, or vice versa.
Iconvex reuses a successful probe when no Unicode was added; probes after new
code points require the incremental callback contract to become linear.

## Optional UTF-8 fast paths

Most traffic has UTF-8 at one side. Codecs can avoid an intermediate Unicode
code-point list by implementing either callback:

```elixir
@impl true
def decode_to_utf8(encoded_binary), do: ...

@impl true
def encode_from_utf8(utf8_binary), do: ...
```

`decode_to_utf8/1` uses the same result contract as `decode/1`, except successful
output is a UTF-8 binary. `encode_from_utf8/1` uses the same success and
unrepresentable-character errors as `encode/1`; malformed UTF-8 returns
`{:decode_error, kind, offset, sequence}`. Iconvex invokes these callbacks only
for strict, policy-free conversions. Discard, substitution, transliteration,
and surface options continue through the policy callbacks. Malformed optional
fast-path return values safely fall back to the required generic callback.

Existing codecs may return the legacy destination-tagged
`{:encode_error, :unrepresentable_character, codepoint}` tuple from
`encode_from_utf8/1`. Iconvex accepts and normalizes that form without invoking
`encode/1` again. New codecs should use the ordinary
`{:error, :unrepresentable_character, codepoint}` form shared with `encode/1`.

The bundled benchmark demonstrates the effect with an external ASCII codec:

```sh
MIX_ENV=prod mix run bench/external_codec_benchmark.exs
```

On the recorded Apple M1/OTP 28 run, zero-copy callbacks reached 591 MiB/s into
UTF-8 and 586 MiB/s from UTF-8, versus 31 and 20 MiB/s through generic
code-point lists. Results vary by codec and machine; only add a fast callback
when its implementation is actually faster.

## Optional Stream callbacks

A stateless external codec opts into lazy conversion with:

```elixir
@impl true
def decode_chunk(input, final?) do
  # {:ok, decoded_codepoints, pending_source_binary} | decode_error
end

@impl true
def encode_chunk(codepoints, final?, policy) do
  # {:ok, encoded_binary, pending_codepoints} | encode_error
end
```

When `final?` is false, retain only the suffix that cannot yet be decided. For
example, a decoder keeps an incomplete multibyte prefix; a longest-match encoder
keeps a Unicode suffix that could join a later code point. When `final?` is true,
pending input must be resolved or reported as incomplete. `policy` is `:error`,
`:discard`, or `{:replace, replacer}`.

A stateful external codec additionally owns explicit decoder and encoder state:

```elixir
@impl true
def stream_decoder_init, do: MyDecoder.initial_state()

@impl true
def decode_chunk(input, state, final?) do
  # {:ok, codepoints, next_state, pending_source_binary} | decode_error
end

# Optional: advance counters or framing after Iconvex consumes an invalid unit.
@impl true
def decode_recovery_state(state, kind, sequence, consumed) do
  MyDecoder.consume_invalid(state, kind, sequence, consumed)
end

@impl true
def stream_encoder_init, do: MyEncoder.initial_state()

@impl true
def encode_chunk(codepoints, state, final?, policy) do
  # {:ok, binary, next_state, pending_codepoints} | encode_error
end
```

Decoder error offsets are relative to the `input` passed to the callback;
Iconvex turns them into absolute stream offsets. Encoder finalization bytes must
only be emitted when `final?` is true. State and pending suffixes must stay
bounded independently of total input size. Recovery normally retains the state
produced by the valid prefix. A codec with a bounded payload length, unit
counter, or similar framing value implements `decode_recovery_state/4` so the
declared consumed bytes advance that value without being decoded as ordinary
input. The callback receives the exact strict error `sequence` and the complete
`consumed` unit; it must return the next decoder state.

A counted frame that reaches physical EOF while still declaring a source unit
reports `:incomplete_sequence` at the EOF offset with `<<>>` as its sequence.
Plain `invalid: :discard` retains the stable decoded prefix because no physical
byte exists to consume. Strict, byte-substitution, and invalid-byte callback
policies retain the incomplete error, and no callback is invoked for an absent
byte.

## External-library test checklist

- Every canonical name and alias resolves case-insensitively.
- Every valid byte sequence decodes, re-encodes, and round-trips as intended.
- Invalid and incomplete inputs report exact byte offsets and sequences.
- Fixed-width malformed units declare their complete recovery consumption.
- Stateful counters and bounded frames advance through invalid units with
  `decode_recovery_state/4`.
- `on_invalid_byte` never runs after an earlier target error; encoder callbacks
  tolerate arbitration probes, or incremental encoder callbacks are supplied.
- Whole-string transforms declare `decode_error_recovery/0` as `:stop` and
  prove that callback/substitution recovery never restarts a desynchronized
  suffix.
- Strict encoding reports the first unrepresentable code point.
- Both discard callbacks handle long rejected runs in linear time.
- `encode_substitute/2` handles repeated rejected code points in
  linear time and preserves multi-code-point and state-machine boundaries.
- Every split of representative multibyte input passes chunked conversion.
- Chunked output is byte-identical to one-shot output; `feed/2` emits no prefix.
- Every split passes lazy `stream/4`; output is consumed before source EOF.
- Stream state and pending suffixes remain bounded for long inputs.
- Final error offsets are relative to the beginning of the complete stream.
- Stateful designations and shifts survive discard paths and chunk boundaries.
- Optional UTF-8 callbacks match generic callback results and typed failures.
- Registration rejects collisions and does not create atoms from input names.

External modules execute as trusted application code. Iconvex validates callback
presence and registration metadata and rejects malformed optional fast-path
results, but it does not sandbox callbacks or rewrite required-callback results;
exceptions and malformed generic results may propagate. Apply normal dependency
review and isolate untrusted codec implementations outside the BEAM.
