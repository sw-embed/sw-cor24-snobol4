# Step 1 -- underscore-label

Brief: `tools/briefs/dcsno-underscore-label.md`.

`:(L_FOO)` and label declaration `L_FOO` don't match: the lexer
treats `_` as a non-identifier character somewhere in the path.
Result: every program with underscore labels loop-falls-through
the prologue.

## Changes

`src/sno_lex.plsw`:
- Find the LEX function's identifier-char predicate.
- Ensure `_` (ASCII 95) is accepted both when scanning a label
  declaration AND when scanning a goto-target identifier.

## Tests

Add `examples/underscore_labels.sno`:
- Single underscore label, goto resolves.
- Mixed underscore + plain labels, distinct targets.
- Two-tier underscore: `L_A_B` declared and `:(L_A_B)` gotoed.

## Exit

- Brief repro program halts cleanly with the expected output.
- New regression in `examples/`, wired into `demos:`.
- `just demos` + `just test` green.
- Rebuilt `build/snobol4.{bin,lgo}` committed.
- commit + `agentrail complete --next-slug output-trailing-tail`.
