# Step 1 -- in-stream binop markers for assignment-context arith

## Problem

The assignment-context expression parser in `src/sno_lex.plsw`
uses a single `S_OEOP` field per statement to record binary ops.
For multi-op chains like `K = A + B + C`, each iteration of the
parser loop overwrites `S_OEOP` (each op is `TK_PLUS` so it ends
up the same value), but the slot stream is just `[A, B, C]` --
the lowering emits `OP_ADD` once at the end, popping two operands.
Result: stack ends up with `[A, B+C]`, STORE pops `B+C`, K = B+C.

Wrong; should be A+B+C.

The `snobol4-expr-completeness` step 3 fix introduced in-stream
`OE_OP_*` markers for builtin-arg expressions. Apply the same
scheme to the outer assignment expression and the multi-op
problem dissolves.

## What to change

`src/sno_lex.plsw` -- the assignment-context primary-token DO
WHILE (around line 1013, post-paren-fix). Currently:

```pl/i
DO WHILE (primary OR TK_LPAREN);
    parse primary into slots
    IF (TK_PLUS OR TK_MINUS OR TK_STAR) THEN DO;
        S_OEOP(S) = TT;        /* single-valued! */
        CALL LEX;
    END;
    consume trailing TK_RPAREN
    /* second binop check after paren close */
    IF (op) THEN { S_OEOP(S) = TT; CALL LEX; }
END;
```

Add a `pending_op` local that defers the marker emission until
after the second operand has been parsed:

```pl/i
DCL pending_op INT;
pending_op = 0;

DO WHILE (primary OR TK_LPAREN);
    parse primary into slots

    /* Flush pending op AFTER the second operand is in the slots. */
    IF (pending_op != 0) THEN DO;
        IF (EPI < EPSLOTS) THEN DO;
            IF (pending_op = TK_PLUS) EP_TYP(EPB+EPI) = OE_OP_ADD;
            ELSE IF (pending_op = TK_MINUS) EP_TYP(EPB+EPI) = OE_OP_SUB;
            ELSE EP_TYP(EPB+EPI) = OE_OP_MUL;
            EP_VAL(EPB+EPI) = 0;
            EPI = EPI + 1;
        END;
        pending_op = 0;
    END;

    /* Now check for the NEXT binop and remember it for next iter. */
    IF (TK_PLUS OR TK_MINUS OR TK_STAR) THEN DO;
        pending_op = TT;
        S_OEOP(S) = TT;   /* keep for OE_BINOP detection */
        CALL LEX;
    END;
    consume trailing TK_RPAREN
    IF (op) THEN { pending_op = TT; S_OEOP(S) = TT; LEX; }
END;
```

`src/sno_exec.plsw` -- the OE_BINOP postfix walk (around line 354)
already dispatches on `EP_TYP` and emits `OP_ADD`/`SUB`/`MUL`/`MOD`
for `OE_OP_*` markers (added in saga-expr-completeness step 3).
**Drop the trailing SELECT** that emits an extra op based on
`S_OEOP` -- markers now cover all ops:

```pl/i
ELSE IF (S_OETY(S) = OE_BINOP) THEN DO;
    EPB = S * EPSLOTS;
    EPI = 0;
    DO WHILE (EPI < S_EPCNT(S));
        ... dispatch SELECT (unchanged) ...
        EPI = EPI + 1;
    END;
    /* No trailing op -- markers cover all ops in the stream. */
END;
```

## Tests

### Regression -- previously-shipped cases stay green

1. `K = K - 1` -- K-1
2. `K = SIZE(A) - 1` -- 4
3. `K = SIZE(A) + 1` -- 6
4. `K = (SIZE(A))` -- 5
5. `K = (SIZE(A) - 1)` -- 4
6. `Y = SUBSTR(A, 1, SIZE(A) - 1)` -- 'HELL'

### New -- multi-op chains

7. `K = A + B + C` (with A=1, B=2, C=3) -- 6
8. `K = 10 - 3 - 2` -- 5
9. `K = 2 * 3 + 1` -- 7 (left-to-right: (2*3)+1)
10. `K = (SIZE(A) - 1) + 1` -- 5 (the nested-parens case from
    saga step 2's "out of scope" list)
11. `K = 1 + 2 + 3 + 4` -- 10

### Edge

12. `K = A` (no op) -- A (no regression on the no-op path)

## Out of scope

- No operator precedence change (left-to-right preserved).
- No unary minus (that's step 2).
- No concat changes.

## Exit criteria

- All 12 cases above produce the expected output.
- `just demos`, `just test` stay green.
- `sno_lex.s` and `sno_exec.s` stay under EMIT_BUF (streaming-emit
  is in place; expected to be a non-issue but worth confirming).

When done, commit, `agentrail complete`, propose step 2 as
`unary-minus-literal`.
