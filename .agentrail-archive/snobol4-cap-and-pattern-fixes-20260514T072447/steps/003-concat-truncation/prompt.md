# Step 3 -- concat-truncation (5+ operand silent drop)

Brief: `tools/briefs/dcsno-concat-truncation.md`.

A SNOBOL4 concat expression with 5+ operands silently drops the
tail (`'a' NL 'b' NL 'c' NL 'd' NL 'e'` produces an 8-char string
instead of 9). The 4-operand cap is suspiciously near `EPSLOTS=8`
(this saga's EPMAX is `STMAX*EPSLOTS = 1024*8`), but the operand
count per concat node may have its own tighter ceiling.

## Investigation

1. Run the discriminator from the brief: `S = 'aa' NL 'bb' NL 'cc'
   NL 'dd' NL 'ee'`. SIZE 13 -> parser flattens to N-ary and the
   operand list truncates. SIZE 12 -> parser keeps the list but
   the evaluator stops walking.
2. Find the concat parsing in `src/sno_lex.plsw`. Likely the
   expression parser builds EP slots and `OP_CONCAT` gets emitted
   pair-wise; the cap is the per-statement EP slot count
   (`EPSLOTS=8`). Five literals + four NL idents = 9 slots. With
   8-slot cap, slot 9 (the last `'e'`) overflows.
3. Confirm in `src/sno_exec.plsw` how OP_CONCAT and the EP walk
   work.

## Fix

Two paths:
- **Restructure parse** to emit left-leaning binary CONCAT
  (`((((a . b) . c) . d) . e)`) -- the cap becomes a non-issue
  for any operand count. Implementation: each new operand emits
  its OE_* slot AND an immediate OP_CONCAT, so the eval stack
  carries a single rolling result. This is the right long-term
  shape, matches the existing PEND_OP machinery for arithmetic.
- **Grow EPSLOTS** to 16 with a diagnostic on overflow. Cheaper
  but cap-bound; would also balloon EPMAX (= STMAX * EPSLOTS) to
  16384 which costs ~24 KB of statics.

Lean toward the restructure if it fits in the time budget; if it
turns out to need broader parser surgery, grow EPSLOTS with the
overflow diagnostic and file a follow-on for the restructure.

## Tests

`examples/concat_chain.sno`:

| expression                                          | expected SIZE |
|-----------------------------------------------------|---------------|
| `'a' 'b'`                                           | 2             |
| `'a' 'b' 'c'`                                       | 3             |
| `'a' 'b' 'c' 'd'`                                   | 4             |
| `'a' 'b' 'c' 'd' 'e'`                               | 5             |
| `'a' NL 'b' NL 'c' NL 'd' NL 'e'`                   | 9             |
| `'aa' NL 'bb' NL 'cc' NL 'dd' NL 'ee'`              | 14            |
| `'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l'`   | 12            |

Plus a varied-length cross-check and an N=16 cap-boundary if we
keep the EPSLOTS approach.

## Out of scope

- Pattern-side concat (PATTERN sequence). Different shape.
- Result-size limits (giant strings). This is operand-count,
  not byte-size truncation.

## Exit

- Brief repro produces SIZE 9 (was 8).
- All test-table sizes correct.
- No regression in just demos / just test.
- Rebuilt `build/snobol4.{bin,lgo}` committed.
- commit + `agentrail complete --next-slug pattern-captures-truncation`.

When done, propose step 4 (`pattern-captures-truncation`).
