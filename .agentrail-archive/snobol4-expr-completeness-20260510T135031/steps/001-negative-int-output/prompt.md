# Step 1 -- fix EMIT_DEC / PUT_DEC for negative integers

`EMIT_DEC` and `PUT_DEC` (in `src/sno_util.plsw`) render an integer
as decimal characters. The render loop is:

```
N = V;
IF (N = 0) THEN DO; emit '0'; RETURN; END;
POS = 0;
DO WHILE (N > 0);
    /* extract a digit */
END;
... emit collected digits in reverse ...
```

For negative N, the `DO WHILE (N > 0)` never enters; POS stays 0;
no digits are emitted; OUTPUT prints empty. `K = 1 - 5; OUTPUT = K`
produces an empty line.

## What to change

In both `EMIT_DEC` and `PUT_DEC` (they share the same render
loop), before the existing logic:

1. If `V < 0`, emit a literal `-` character (43 for SBPUT, or
   `UART_PUTCHAR(45)` for the UART variant).
2. Negate: `N = 0 - N`.
3. Run the existing positive-decimal loop.

Don't touch the `IF (N = 0)` early-out — it's still correct.

`sno_util.s` is at ~70 KB / 256 KB EMIT_BUF — plenty of room for
the additional handling.

## Tests / regression

Add `examples/negative_output.sno`:

```snobol4
        OUTPUT = -5
        K = 1 - 5
        OUTPUT = K
        OUTPUT = 0
        OUTPUT = 100
        N = 0 - 1
        OUTPUT = N
END
```

Expected output:

```
-5
-4
0
100
-1
```

Wire to the `justfile` (`negative-output`) and to `just demos`.

## Out of scope

- No changes to integer arithmetic ops — those already produce
  correct negative values; only the formatter is broken.
- No changes to the parser or to expression handling — this is
  purely an output-formatting fix.
- The `OUTPUT = 'foo = ' EXPR` precedence quirk noted in the
  funcall-arithmetic brief is a separate concern about
  concatenation-vs-arithmetic precedence; not addressed here.

## Exit criteria

- `OUTPUT = -5` prints `-5`.
- `OUTPUT = 1 - 5` prints `-4` (now that the formatter handles
  negatives).
- `OUTPUT = 0` still prints `0`.
- Positive integers print unchanged.
- `just demos` and `just test` stay green.
- `examples/negative_output.sno` shows the expected output above.

When done, commit, `agentrail complete`, and propose step 2 as the
next slug (`parens-around-expressions`).
