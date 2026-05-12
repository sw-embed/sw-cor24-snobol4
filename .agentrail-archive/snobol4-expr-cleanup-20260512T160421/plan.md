# SNOBOL4 expression cleanup -- multi-op chains and unary minus

Two parser-level gaps documented as out-of-scope when the
`snobol4-expr-completeness` saga shipped its three steps:

1. **Multi-op chains** (`A + B + C`, `((SIZE(A)-1)+1)`) -- the
   statement-level `S_OEOP` field is single-valued, so only the
   last op survives. Earlier saga step 3 introduced in-stream
   `OE_OP_*` markers for builtin args; this saga extends the same
   scheme to the outer assignment expression so multi-op chains
   work naturally.

2. **Leading unary minus** (`OUTPUT = -5`, `K = -SIZE(A)`) -- the
   assignment-context primary-token DO WHILE doesn't accept
   `TK_MINUS` as a leading token, so the loop never enters and
   the assignment falls back to 0.

Both fixes are in `sno_lex.plsw`'s assignment-context expression
parser. They share the same in-stream marker scheme.

## Steps

### Step 1 -- in-stream binop markers (foundational)

Replace the single-`S_OEOP` scheme with `OE_OP_*` markers in the
EP slot stream for assignment-context binary ops. Same encoding
the saga-expr-completeness step 3 fix already introduced for
builtin-arg expressions; extending it to the outer level makes
multi-op chains work naturally as a postfix walk.

Also drops the trailing-op SELECT from the OE_BINOP lowering
path -- markers cover all ops; no final op needs to be emitted.

**Exit:** `K = A + B + C` returns A+B+C (was B+C). All previously-
shipped expr-completeness regressions stay green.

### Step 2 -- leading unary minus

Pre-loop: if the first token after `=` is `TK_MINUS`, synthesize a
leading `OE_INT(0)` slot and set `pending_op = TK_MINUS`. The
existing loop then parses the next primitive and the marker
machinery from step 1 emits `OE_OP_SUB` after it -- equivalent to
rewriting `K = -5` as `K = 0 - 5`.

**Exit:** `OUTPUT = -5` prints `-5`, `K = -SIZE(A)` returns
`-len(A)`, `K = -A` returns the negative of A's int value.

## Out of scope

- Right-to-left or operator precedence: SNOBOL4 is left-to-right
  associative without precedence (concat tighter than infix
  arith); this saga preserves that.
- Comparison operators (`<`, `>`, `=`) in expressions: not added.
- Bitwise / shift operators: not in the SNOBOL4 dialect.
- Concat-vs-arith precedence quirk
  (`OUTPUT = 'foo = ' SIZE(A) - 1` parses as
  `('foo = ' SIZE(A)) - 1`): documented in
  `dcsno-funcall-arithmetic.md` as separate concern.
