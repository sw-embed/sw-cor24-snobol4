# Step 3 -- accept full expressions in builtin call arguments

dcftn's blocked rstrip / lstrip pattern is

```snobol4
        TXT = SUBSTR(TXT, 1, SIZE(TXT) - 1)
        TXT = SUBSTR(TXT, 2, SIZE(TXT) - 1)
```

and similar arith-on-call-result usages inside SUBSTR / SIZE / CHAR
arguments. Today the builtin's argument parser only accepts a
single primitive `TK_INT` / `TK_IDENT` / `TK_STR` per arg slot.
A nested call (e.g. `SIZE(TXT)`) followed by an arithmetic op
(`- 1`) in the SUBSTR third arg slot is silently truncated to the
single IDENT `SIZE`, leaving the actual arg as 0 and producing an
empty result.

## Prerequisite (gating)

`sno_exec.s` is currently 262,030 / 262,144 bytes of PL/SW's
`EMIT_BUF_SIZE`, with ~100 bytes of headroom. The codegen
extension this step needs (postfix walking of in-arg expression
slots, with a new in-stream binary-op marker) does not fit.

**This step starts only after `dcsno-rebuild-snobol4-artifacts`
ships** -- that brief rebuilds the SNOBOL4 binary against PL/SW
post-`pr/emit-zero-fill`, dropping `sno_exec.s` from ~261 KB to
~7 KB and giving this step ~250 KB of working room. Confirm by:

```sh
$ wc -c build/mod/sno_exec.s         # should be << 262144
$ grep -c "\.zero" build/mod/sno_exec.s   # should be > 0
```

If either check fails, wait — the rebuild hasn't landed yet.

## What to change

Two coordinated changes:

### Parser (`src/sno_lex.plsw`)

The SUBSTR / SIZE / CHAR argument blocks (and the parallel
`PARSE_NESTED_FN` helper used by the builtin-predicate parser)
need to accept full expressions in arg positions, not just
primitives. The existing primary-token DO WHILE pattern (with the
postfix EP slot layout) is the right model.

Either:

1. Recursively share the assignment-context `PARSE_EXPR_PRIMARY`
   helper (extracted in step 2) — call it for each arg position.
2. Or duplicate the primary + binop loop inline at each arg site.

Option 1 is cleaner; option 2 costs more `.s` text but is fewer
moving parts. Pick whichever fits the actual code shape after
step 2 lands.

Because builtin args can themselves nest (e.g.
`SUBSTR(X, 1, SUBSTR(Y, 1, 2))` becomes legal), the parser needs
to accept the same token shapes the assignment-context parser
does.

### Lowering (`src/sno_exec.plsw`)

In-stream binary ops need a new EP_TYP marker so the lowering can
see "value, value, OP_ADD/SUB/MUL/MOD" mid-arg-stream. Suggested
encoding:

- Add `OE_OP_ADD` / `OE_OP_SUB` / `OE_OP_MUL` / `OE_OP_MOD` (or
  one `OE_BINOP_INLINE` slot whose `EP_VAL` is the op token id).
- The lowering walks slots; on a binop marker, emit the op (which
  pops two stack values and pushes one).
- Existing `OE_SIZE` / `OE_SUBSTR` / `OE_CHAR` markers stay; their
  stack-popping arity is documented per builtin.

The OE_BINOP statement-level path can be unified with the slot-stream
form once both work: the statement-level binop becomes "walk slots,
emit op markers wherever they appear" and the trailing op of an
arithmetic statement becomes a final marker rather than a separate
S_OEOP field.

## Tests / regression

Extend `examples/funcall_arith.sno` or add a sibling
`examples/builtin_arg_expr.sno`:

```snobol4
        A = 'HELLO'

        Y = SUBSTR(A, 1, SIZE(A) - 1)        ; 'HELL'
        OUTPUT = 'B1 Y = ' Y

        Y = SUBSTR(A, 2, SIZE(A) - 1)        ; 'ELLO'
        OUTPUT = 'B2 Y = ' Y

        Y = SUBSTR('HELLO', 1, SIZE('AB') + 2)   ; 'HELL'
        OUTPUT = 'B3 Y = ' Y

        N = SIZE(SUBSTR('HELLO', 1, 3))      ; 3
        OUTPUT = 'B4 N = ' N

END
```

Wire to the `justfile`. Run dcftn's normalize.sno fixtures (per
`tools/briefs/dcsno-funcall-arithmetic.md`) — they should now pass
without temp-variable workarounds.

## Out of scope

- No new builtin functions.
- No changes to pattern-matching argument forms (those use a
  different parser).
- No precedence changes — `SIZE(A) - SIZE(B) * 2` evaluates
  left-to-right same as before (`(SIZE(A) - SIZE(B)) * 2`).
- No support for arbitrarily-deep arith expressions in args
  beyond what the EP slot capacity (`EPSLOTS = 8` per statement)
  permits. If a workload hits that cap, that's a separate
  capacity-tightening saga.

## Exit criteria

- `SUBSTR(X, 1, SIZE(X) - 1)` produces the all-but-last-char
  substring.
- `SUBSTR(X, 2, SIZE(X) - 1)` produces the all-but-first-char
  substring.
- `SIZE(SUBSTR('HELLO', 1, 3))` returns 3.
- `Y = SUBSTR('HELLO', 1, SIZE('AB') + 2)` returns 'HELL'.
- dcftn's normalize.sno fixtures (rstrip / lstrip / classify all
  pass without temp-variable workarounds) — confirms the dogfood
  loop is unblocked.
- `just demos` / `just test` stay green.
- All previously-shipped funcall-arith and parens-expr cases
  unaffected.

When done, commit, `agentrail complete --done` (saga finished).
