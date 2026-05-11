# Step 2 -- leading unary minus in assignment context

## Problem

The assignment-context primary-token DO WHILE in
`src/sno_lex.plsw` accepts `TK_INT` / `TK_STR` / `TK_IDENT` /
`TK_LPAREN`. It does NOT accept `TK_MINUS` as a primary -- so
statements like:

```snobol4
        OUTPUT = -5
        K = -SIZE(A)
        N = -A
```

never enter the loop (TT is TK_MINUS, doesn't match the guard),
`EPI` stays at 0, and the assignment falls back to 0.

## What to change

`src/sno_lex.plsw` -- BEFORE the primary-token DO WHILE, check
if `TT = TK_MINUS`. If so, synthesize a leading `OE_INT(0)` slot
and set `pending_op = TK_MINUS` (the mechanism from step 1):

```pl/i
EPI = 0;
pending_op = 0;

/* Leading unary minus: rewrite  -X  as  0 - X . The pending_op
 * mechanism from step 1 then emits OE_OP_SUB after the next
 * primary parses. */
IF (TT = TK_MINUS) THEN DO;
    IF (EPI < EPSLOTS) THEN DO;
        EP_TYP(EPB + EPI) = OE_INT;
        EP_VAL(EPB + EPI) = 0;
        EPI = EPI + 1;
    END;
    pending_op = TK_MINUS;
    S_OEOP(S) = TK_MINUS;
    CALL LEX;
END;

DO WHILE (primary OR TK_LPAREN);
    ...
END;
```

That's all. The existing parser loop handles the rest -- it sees
`TK_INT(5)` (or whatever the user wrote), parses it as primary,
sees `pending_op != 0`, emits `OE_OP_SUB` marker after the slot.
Final slot stream is `[OE_INT(0), <user-expr>, OE_OP_SUB]`. The
postfix walk evaluates to `0 - <user-expr> = -<user-expr>`.

No `sno_exec.plsw` change needed -- step 1's lowering changes
already handle the marker stream.

## Tests

1. `K = -5; OUTPUT = K` -- prints `-5`
2. `OUTPUT = -5` -- prints `-5` (no temp var)
3. `K = -SIZE(A)` (A='HELLO') -- K is -5
4. `K = -A` (A=42) -- K is -42
5. `K = -5 + 10` -- 5 (= (-5) + 10)
6. `K = -1 - 1` -- -2 (= (-1) - 1)
7. `K = -A + B` (A=2, B=5) -- 3 (= (-2) + 5)

### Regression

8. `K = 1 - 5` -- -4 (existing computed-negative, must stay green)
9. `K = 0 - 5` -- -5 (existing, stay green)
10. `K = A - 1` -- A-1 (existing, stay green)

## Out of scope

- Trailing unary minus inside a sub-expression (e.g.
  `K = A + -B`) -- the parser doesn't currently support that
  shape and the SNOBOL4 dialect typically wraps in parens or
  uses an explicit `0 - B`. Could be a follow-up if a workload
  surfaces it.
- Unary plus (`+5`) -- nobody writes this.
- Unary minus on string -- semantically meaningless; no need
  to handle.

## Exit criteria

- All 7 new cases produce the expected negative values.
- All 3 regression cases unchanged.
- `just demos`, `just test` stay green.
- Update `examples/negative_output.sno` to add the literal
  `OUTPUT = -5` line that was documented as a known limitation;
  it should now work.

When done, commit, `agentrail complete --done` (saga finished).
