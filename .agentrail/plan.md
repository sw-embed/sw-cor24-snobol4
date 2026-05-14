# SNOBOL4 cap + pattern fixes (dcftn FTI-0 follow-on briefs)

dcftn's FTI-0 milestone-4-print-int work surfaced four independent
SNOBOL4 bugs after the parent `dcsno-static-program-size-limit`
brief landed. Each has a self-contained repro and a SPAN/split
workaround in place; this saga ships proper fixes.

## Steps

### Step 1 -- source-byte-cap

Brief: `tools/briefs/dcsno-source-byte-cap.md`.

Raise SRC_LIMIT (currently `12280`, backed by `DCL SRC(12288) BYTE`
in `include/snoglob.msw`) to a comfortable cap (~48-64 KiB), keep
the overflow diagnostic that shipped in `pr/stmt-table-cap`. Add a
byte-cap regression: padded SNOBOL4 sources at multiple sizes.
Unblocks dcftn's `emit_asm.sno` comment budget.

### Step 2 -- any-pattern-fails

Brief: `tools/briefs/dcsno-any-pattern-fails.md`.

`ANY(class)` silently fails; `SPAN(class)` works correctly. Fix
the ANY opcode handler (probably in `src/sno_exec.plsw`) -- likely
a cursor-advance, ANY/NOTANY swap, or class-decode bug. Add a
small ANY test table.

### Step 3 -- concat-truncation

Brief: `tools/briefs/dcsno-concat-truncation.md`.

5+ operand concat silently drops trailing bytes. Investigate the
parser flattening vs evaluator scratch buffer. Discriminator test
(2-byte operands) tells which layer is the truncator. Raise the
cap (with diagnostic) or restructure to left-leaning binary.

### Step 4 -- pattern-captures-truncation

Brief: `tools/briefs/dcsno-pattern-captures-truncation.md`.

4+ `.` captures per pattern drop the trailing capture values
(pattern still matches; only the variable bindings break).
Probably a 3-slot CAP register tuple in the pattern matcher.
Switch to an array (size 8-16) with diagnostic on overflow.

## Exit criteria (saga)

- All four briefs' repros pass cleanly.
- `just demos` (now 16 + any new regressions) green.
- `just test` 14 "All tests done" green.
- New regression examples committed under `examples/` and wired
  into `demos:`.
- `build/snobol4.{bin,lgo}` rebuilt and committed.
- One commit per step, each `agentrail complete`'d, then
  branch renamed `feat/cap-and-pattern-fixes` ->
  `pr/cap-and-pattern-fixes` for `dg-reap`.

## Out of scope

- The `feat/runtime-split-resume` engine consolidation; still
  parked on dcpls SRC_BUF (separate brief).
- Storage-runtime impl; gated on dcpls getmain/freemain.
- Pattern features beyond ANY: ARB, NOTANY, alternation,
  recursion. If the ANY fix happens to improve them, fine; the
  saga's exit gate is the four briefs above.
