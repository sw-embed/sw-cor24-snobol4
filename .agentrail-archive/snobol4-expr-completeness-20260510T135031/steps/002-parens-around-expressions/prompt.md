# Step 2 -- accept parens around expressions in assignment context

The assignment-context expression parser in `src/sno_lex.plsw`
collects EP slots in a `DO WHILE` loop whose primary-token guard
is `TT = TK_INT OR TT = TK_STR OR TT = TK_IDENT`. It does not
accept `TK_LPAREN`. When a user writes:

```snobol4
        K = (SIZE(A))
```

the parser sees `=`, then `(` (TK_LPAREN), and the DO WHILE never
enters. EPI stays 0; nothing populates the EP slots; the assignment
stores 0.

## What to change

Extend the primary-token loop in the assignment-context expression
parser to accept `TK_LPAREN`. On opening paren:

1. `CALL LEX` past the `(`.
2. Recurse into a sub-expression that fills EP slots in postfix
   order (primitives + `OE_SIZE` / `OE_SUBSTR` / `OE_CHAR` markers
   — the same shape the existing nested-call path produces).
3. Expect `TK_RPAREN`; on match, `CALL LEX` past it.

The simplest approach is to extract the existing primary-token
loop body into a helper PROC (e.g. `PARSE_EXPR_PRIMARY`) and call
it recursively for the parenthesised case. The recursion must
share the same EP slot base (`EPB`) and slot counter so the
postfix layout stays linear.

The OE_BINOP postfix lowering shipped in `pr/funcall-arithmetic`
already handles whatever the parser produces; **no `sno_exec.plsw`
changes required**, which is good because that module has only ~100
bytes of EMIT_BUF headroom. All work is in `sno_lex.plsw`, which
has ~40 KB free.

## Tests / regression

Extend `examples/funcall_arith.sno` (or add a sibling
`examples/parens_expr.sno`) with cases:

```snobol4
        A = 'HELLO'

        K = (SIZE(A))
        OUTPUT = 'P1 K = ' K          ; 5

        K = (SIZE(A) - 1)
        OUTPUT = 'P2 K = ' K          ; 4

        K = (1)
        OUTPUT = 'P3 K = ' K          ; 1

        K = ((SIZE(A) - 1) + 1)
        OUTPUT = 'P4 K = ' K          ; 5

END
```

Wire to the `justfile`. Confirm `just demos` and `just test` stay
green.

## Out of scope

- No changes to the lowering / executor — the postfix walk works
  regardless of how the slots were populated.
- No precedence changes for `<concat> <op>` (the
  `OUTPUT = 'foo = ' SIZE(A) - 1` quirk noted in the
  funcall-arithmetic brief). Separate concern.
- No support for parens around the *assignment LHS* — that's not a
  meaningful SNOBOL4 form.
- No general operator-precedence overhaul. Just allowing parens
  around what's already a parsable expression body.

## Exit criteria

- `K = (SIZE(A))` returns 5.
- `K = (SIZE(A) - 1)` returns 4.
- `K = ((SIZE(A) - 1) + 1)` returns 5 (nested parens).
- `K = (1)` returns 1 (parens around a single primitive).
- `just demos` / `just test` green.
- All previously-shipped funcall-arith cases unaffected.

When done, commit, `agentrail complete`, and propose step 3 as the
next slug (`builtin-arg-expressions`). Step 3 is gated on dcpls's
`pr/emit-zero-fill`; document the gating in the agentrail
trajectory so the next session doesn't bump into the same wall.
