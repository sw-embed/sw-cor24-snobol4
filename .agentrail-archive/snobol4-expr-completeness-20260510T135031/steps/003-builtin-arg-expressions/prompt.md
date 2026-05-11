# Step 3 -- accept full expressions in builtin call arguments

dcftn's blocked patterns include both:

```snobol4
        TXT = SUBSTR(TXT, 1, SIZE(TXT) - 1)        ; arith on call result
        TXT = SUBSTR(TXT, 2, SIZE(TXT) - 1)
```

**and** -- per dcftn's 2026-05-09 update to the funcall-arithmetic
brief -- the broader scope without arith:

```snobol4
        Y = SUBSTR(A, SIZE(A), 1)         ; nested call as raw arg, returns ''
        N = SIZE(SUBSTR(A, 1, 3))         ; doubly-nested call, returns 1 (wrong)
```

Today the builtin's argument parser only accepts a single primitive
`TK_INT` / `TK_IDENT` / `TK_STR` per arg slot. **Any** nested
function call in a non-predicate-with-goto context produces a
silently-wrong result -- the inner call's IDENT is stored as a
plain symbol-table reference (typically 0), and any trailing tokens
(args of the nested call, arithmetic operators, etc.) get consumed
by the outer parser as if they were part of the builtin's arg list.

The earlier `pr/nested-call-drops-gotos` fix (2026-05-08) handles
the predicate-with-goto path specifically (`IDENT(SUBSTR(...), ...)`
followed by `:S` / `:F`) -- it added `PARSE_NESTED_FN` for those
arg sites. The builtin-call-as-expression path (assignment context,
SUBSTR/SIZE/CHAR called inside SUBSTR/SIZE/CHAR) is the gap this
step closes.

## Prerequisite (gating)

`sno_exec.s` is currently 262,030 / 262,144 bytes of PL/SW's
`EMIT_BUF_SIZE`, with ~100 bytes of headroom. The dcpls
`pr/emit-zero-fill` shipped on 2026-05-09 and shrank the entry
module (`sno_main.s` 261 KB → 8 KB) but did **not** shrink library
modules (`sno_exec` has `%DEFINE LIBRARY` which already suppressed
its DCLs; its 261 KB is all code, not zero-init data).

**This step is gated on freeing up sno_exec.s headroom.** Two
viable paths:

A. **Refactor sno_exec to reduce code size** -- find dead code,
   simplify cascades, share helpers between paths. Real but
   limited -- maybe 5-10 KB recoverable; the codegen patterns are
   already fairly tight.

B. **Move some of sno_exec into a new module** -- e.g. extract the
   pattern-matching engine into `src/sno_pat.plsw`, or push more
   of the AM executor into a follow-on extension to `snolib`. This
   is what the archived `snobol4-runtime-split` saga's step 2
   would have done in a different shape; can be revisited as a
   sibling saga.

C. **Ask dcpls to bump EMIT_BUF** -- the brief I retracted in
   favour of `dcxas-zero-fill-directive` + `dcpls-emit-zero-fill`.
   Could revisit if A and B prove harder than a one-line
   `EMIT_BUF_SIZE` change.

Confirm headroom before starting:

```sh
$ wc -c build/mod/sno_exec.s         # should be << 262144
```

If `sno_exec.s` is still > 250 KB, stop -- this step's coding
work won't fit. Pick one of the three paths above first.

## What to change

Two coordinated changes once headroom is available:

### Parser (`src/sno_lex.plsw`)

The SUBSTR / SIZE / CHAR argument blocks in the assignment-context
expression parser (and the parallel `PARSE_NESTED_FN` helper used
by the builtin-predicate parser) need to accept full expressions
in arg positions, not just primitives. The existing primary-token
DO WHILE pattern (with the postfix EP slot layout from
`pr/funcall-arithmetic` plus the parens support from saga step 2)
is the right model.

Either:

1. Recursively share the assignment-context primary-loop helper
   for each arg position -- requires lifting the loop body into a
   PROC.
2. Or duplicate the primary + binop loop inline at each arg site.

Option 1 is cleaner; option 2 costs more `.s` text but is fewer
moving parts. Pick whichever fits the actual code shape.

Because builtin args can themselves nest (e.g.
`SUBSTR(X, 1, SUBSTR(Y, 1, 2))` becomes legal), the parser needs
to accept the same token shapes the assignment-context parser
does, including parens.

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

The OE_BINOP statement-level path can be unified with the
slot-stream form once both work: the statement-level binop
becomes "walk slots, emit op markers wherever they appear" and
the trailing op of an arithmetic statement becomes a final marker
rather than a separate S_OEOP field. As a bonus this would also
fix the multi-op-chain limitation (`A + B + C`, `((SIZE(A) - 1) +
1)`) currently noted as out-of-scope in the negative_output and
parens_expr regression demos.

## Tests / regression

Extend an existing demo or add `examples/builtin_arg_expr.sno`:

```snobol4
        A = 'HELLO'

* B1 - bare nested call as arg (no arith)
        Y = SUBSTR(A, SIZE(A), 1)            ; expect: 'O'
        OUTPUT = 'B1 Y = ' Y

* B2 - doubly-nested call in SIZE arg
        N = SIZE(SUBSTR(A, 1, 3))            ; expect: 3
        OUTPUT = 'B2 N = ' N

* B3 - rstrip pattern (the dcftn-blocking case)
        Y = SUBSTR(A, 1, SIZE(A) - 1)        ; expect: 'HELL'
        OUTPUT = 'B3 Y = ' Y

* B4 - lstrip pattern
        Y = SUBSTR(A, 2, SIZE(A) - 1)        ; expect: 'ELLO'
        OUTPUT = 'B4 Y = ' Y

* B5 - arith with nested calls on both sides
        Y = SUBSTR(A, 1, SIZE('AB') + 2)     ; expect: 'HELL'
        OUTPUT = 'B5 Y = ' Y

END
```

Wire to the `justfile`. Run dcftn's normalize.sno fixtures (per
`tools/briefs/dcsno-funcall-arithmetic.md`) -- they should now
pass without temp-variable workarounds.

## Out of scope

- No new builtin functions.
- No changes to pattern-matching argument forms (those use a
  different parser).
- No precedence changes -- `SIZE(A) - SIZE(B) * 2` evaluates
  left-to-right as `(SIZE(A) - SIZE(B)) * 2` same as before.
- No support for arbitrarily-deep arith expressions in args
  beyond what the EP slot capacity (`EPSLOTS = 8` per statement)
  permits. If a workload hits that cap, that's a separate
  capacity-tightening saga.

## Exit criteria

- `SUBSTR(A, SIZE(A), 1)` returns the last character of A.
- `SIZE(SUBSTR(A, 1, 3))` returns 3.
- `SUBSTR(X, 1, SIZE(X) - 1)` produces the all-but-last-char
  substring (rstrip).
- `SUBSTR(X, 2, SIZE(X) - 1)` produces the all-but-first-char
  substring (lstrip).
- `Y = SUBSTR('HELLO', 1, SIZE('AB') + 2)` returns 'HELL'.
- dcftn's normalize.sno fixtures pass without temp-variable
  workarounds -- confirms the dogfood loop is unblocked.
- `just demos` / `just test` stay green.
- All previously-shipped funcall-arith / parens-expr / negative-
  output cases unaffected.

When done, commit, `agentrail complete --done` (saga finished).
