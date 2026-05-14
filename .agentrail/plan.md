# SNOBOL4 more-fixes (underscore labels + OUTPUT trailing-tail)

Two compounding correctness issues after the cap-and-pattern-fixes
saga. Both surfaced from dcftn's FTI-0 work or from regression
testing during the prior saga.

## Steps

### Step 1 -- underscore-label

Brief: `tools/briefs/dcsno-underscore-label.md`.

`_` (underscore) is rejected as part of a SNOBOL4 label name.
Declaring `L_FOO` and gotoing `:(L_FOO)` silently mis-resolves
(label not found -> fall through). The bug is in the lexer's
char class: either the label-declaration tokenizer or the
goto-target tokenizer (or both) treats `_` as a non-identifier
character.

Fix: accept `_` in identifier-char class consistently. Add a
small regression program with mixed underscore / no-underscore
labels.

### Step 2 -- output-trailing-tail

Latent bug surfaced during step 3 of the cap-and-pattern-fixes
saga (regression test for concat-truncation). When an OUTPUT
statement interleaves a builtin (SIZE/SUBSTR/CHAR) with trailing
string/var operands:

    OUTPUT = 'pre ' SIZE(A) ' post'

only `pre 1` is emitted -- the trailing `' post'` is dropped.

Hypothesis: the HAS_BLT path in `src/sno_exec.plsw` lowering walks
operands [0..BLT_ARG), emits the builtin args, emits the builtin
op, then emits a single OP_CONCAT -- but does NOT walk operands
[BLT_IDX+1..S_EPCNT) that follow the builtin marker.

Fix: extend the HAS_BLT path to also emit operands after the
builtin and add CONCATs for them. Regression: build a statement
with literal/var-before, builtin in middle, literal/var-after,
and verify the full output emits.

## Out of scope

- 12+ capture stretch from the prior saga's brief
  (`dcsno-pattern-captures-truncation.md`). Needs pattern
  restructuring -- separate saga.
- The `dcftn-emit-asm-pattern-anchoring.md` brief (addressed to
  dcftn, not dcsno).
- Any new feature work; that's after this fix saga.

## Exit (saga)

- Both fixes shipped; reproductions clean.
- New regressions in `examples/` wired into `just demos`.
- Existing `just demos` + `just test` green.
- Branch renamed `feat/more-fixes` -> `pr/more-fixes` for
  `dg-reap`.
