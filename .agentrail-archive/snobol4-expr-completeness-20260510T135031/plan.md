# SNOBOL4 expression-completeness fixes

Three bugs surfaced by dcftn's `feat/m1-resume` saga (and the broader
exercise of the dialect by real programs) that share the theme of
"expressions and their output not handling cases SNOBOL4 programs
naturally write." Sequenced from shippable-now (no upstream
dependency) to gated-on-dcpls (need EMIT_BUF headroom in
`sno_exec.s`).

## Background

The recently-shipped `pr/funcall-arithmetic` (2026-05-09) fixed
top-level `N = SIZE(A) - 1`-style arithmetic but explicitly left
three connected gaps -- documented in that PR's commit message and
confirmed by dcftn's normalize.sno regression suite:

1. **SUBSTR/SIZE/CHAR with an arith argument** -- e.g.
   `SUBSTR(X, 1, SIZE(X) - 1)`. The builtin's argument parser only
   accepts a single primitive `IDENT` / `INT` / `STR`; nested calls
   plus arithmetic on those calls is not recognised.
2. **Parens around expressions** -- e.g. `K = (SIZE(A))`. The
   assignment-context expression parser's primary-token DO WHILE
   does not accept `TK_LPAREN`, so any parenthesised subexpression
   silently produces 0.
3. **Negative-int OUTPUT** -- e.g. `K = 1 - 5; OUTPUT = K` prints
   empty. `EMIT_DEC` (in the I/O helpers) loops `DO WHILE (N > 0)`,
   which never enters for negative N. Pre-existing bug, unrelated
   to the parser/lowering work but surfaced by the same testing.

## Steps

### Step 1 -- negative-int OUTPUT formatter

Smallest, no upstream dependency. Fix `EMIT_DEC` (in `sno_util.plsw`)
and `PUT_DEC` (sibling helper) to handle negative integers: detect
`N < 0`, emit `-`, negate, then run the existing positive-decimal
loop. Add a regression demo `examples/negative_output.sno` and wire
to `just demos`.

`sno_util.s` is at 27% of EMIT_BUF (~70 KB / 256 KB) so there's
plenty of room.

**Exit criteria.** `OUTPUT = -5` prints `-5`; `OUTPUT = 1 - 5` prints
`-4`; positive integers and zero print unchanged. `just demos` and
`just test` stay green.

### Step 2 -- parens around expressions

Medium: parser change in `sno_lex.plsw`. The assignment-context
primary-token parser needs to accept `TK_LPAREN`, recurse into a
sub-expression that fills EP slots, then expect `TK_RPAREN`. The
already-existing OE_BINOP postfix lowering (after step 1 of the
runtime-split saga's `pr/funcall-arithmetic`) handles whatever the
nested expression produces -- the work here is purely parser
plumbing.

`sno_lex.s` is at 84% of EMIT_BUF (~221 KB / 256 KB) so there's
~40 KB of headroom; this should fit.

**Exit criteria.** `K = (SIZE(A))` returns 5; nested
`K = ((SIZE(A) - 1) + 1)` returns 5; `just demos` / `just test`
green; `examples/funcall_arith.sno` (the funcall-arith regression)
gets a "T8 parens" case showing the fix.

### Step 3 -- SUBSTR / SIZE / CHAR with arith argument

Largest. The builtin-argument parser in `sno_lex.plsw` (the
primitive-only blocks at the SUBSTR / SIZE / CHAR sites, and the
parallel `PARSE_NESTED_FN` helper used by the predicate parser)
needs to accept full expressions in arg positions, not just
primitives. The lowering in `sno_exec.plsw` then needs to walk
those expression slots in postfix order and emit ops -- analogous
to the `OE_BINOP` postfix walk added by `pr/funcall-arithmetic`,
but inline within an arg list.

This is the change that requires EMIT_BUF headroom in `sno_exec.s`
(currently 262,030 / 262,144 bytes -- 114 bytes free). **Gated on
dcpls's `pr/emit-zero-fill` shipping** -- once the new pl-sw is
installed and SNOBOL4 is rebuilt against it (`dcsno-rebuild-snobol4-artifacts`),
`sno_exec.s` drops to ~7 KB and the consolidation has ~250 KB of
working room.

**Exit criteria.** dcftn's blocked rstrip / lstrip pattern works
inline:

```
TXT = SUBSTR(TXT, 1, SIZE(TXT) - 1)    ; rstrip one char
TXT = SUBSTR(TXT, 2, SIZE(TXT) - 1)    ; lstrip one char
```

`Y = SUBSTR('HELLO', 1, SIZE('AB') + 2)` returns `'HELL'`.
`examples/funcall_arith.sno` extends with the SUBSTR-with-arith
cases. `just demos` / `just test` green. dcftn's `feat/m1-resume`
unblocks for normalize.sno without the temp-variable workaround.

## Out of scope for this saga

- The `pr/funcall-arithmetic` (top-level `N = SIZE(A) - 1`) work --
  already shipped 2026-05-09. This saga builds on it.
- The `snobol4-runtime-split` saga (snolib / sno-engine consolidation
  / new driver) -- archived to `.agentrail-archive/`; resumes as its
  own continuation saga once EMIT_BUF unblocks step 2.
- Pattern-replacement assignment (`S pat = repl`), pattern alternation
  (`p | q`), `ANY` / `NOTANY` / `ARB` / `BAL` / `POS` / `RPOS` -- all
  separate dialect-completeness work tracked elsewhere.
- Any non-arithmetic expression-completeness gap (e.g. unary minus
  outside `0 - X`, mixed-precedence `A + B * C`).

## Exit criteria for the whole saga

All three bugs fixed, regression demos in `examples/`, full
`just demos` and `just test` green, and dcftn's `normalize.sno`
runs against the rebuilt `snobol4.lgo` without temp-variable
workarounds for length-arithmetic. Steps 1 and 2 ship before step
3 (which is gated on dcpls). Step 1 can ship today; step 2 fits in
sno_lex's 40 KB headroom and can also ship before dcpls.
