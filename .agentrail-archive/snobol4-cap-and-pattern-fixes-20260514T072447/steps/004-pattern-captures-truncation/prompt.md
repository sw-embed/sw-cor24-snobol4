# Step 4 -- pattern-captures-truncation

Brief: `tools/briefs/dcsno-pattern-captures-truncation.md`.

A pattern with 4+ `.` (capture) clauses still matches, but the
trailing capture variables (slots 4+) retain their default value
instead of binding to the matched substring. The 3-capture
threshold is well below the ~16 cap of other fixed arrays, so
the brief expects a 3-slot register tuple in the pattern matcher.

## Investigation

1. Find the `.` (capture-bind) parser in `src/sno_lex.plsw`.
   PP_TYP slot type = OE_CAP (per snoglob.msw). The slot count is
   bounded by EPSLOTS (=16 after step 3) -- so 16 captures fit
   structurally. But the brief says 3 work and 4+ silently fail.
2. Find the capture-flush machinery in the matcher
   (`src/sno_exec.plsw`): the PMATCH PK_CAP case stores into
   the destination variable. There may be a per-pattern capture
   slot count cap.

The discriminator: with EPSLOTS now 16, do 4-capture patterns
work or still fail? If they still fail after step 3, the cap is
in the matcher/runtime path, not the parser slots. Note: the
brief said EPSLOTS was 8 (and the cap was 3 captures) -- a 3:8
ratio is suspicious. With EPSLOTS=16 the parser allows more
slots but the matcher may still cap at 3.

## Fix

If the cap is in PMATCH (likely):
- Find the per-pattern CAP register tuple (CAP0/CAP1/CAP2 or
  similar) in `src/sno_exec.plsw`.
- Replace with an array sized to EPSLOTS (or a comfortable cap
  like 16).
- Make sure the capture walk after a successful match writes all
  collected captures, not just the first N.

If it's in the parser, follow the EPSLOTS gate at the OE_CAP
emit site.

## Tests

`examples/pattern_captures.sno`:

| pattern (subject `L`)                                        | expected captures |
|--------------------------------------------------------------|-------------------|
| `L = 'x=1'; L 'x=' REM . X`                                  | X='1'             |
| `L = 'a=1 b=2'; <2-capture>`                                 | A='1', B='2'      |
| `L = 'a=1 b=2 c=3'; <3-capture>`                             | A,B,C bound       |
| `L = 'a=1 b=2 c=3 d=4'; <4-capture>` (brief's repro)         | A..D bound        |
| `L = 'a=1 b=2 c=3 d=4 e=5'; <5-capture>`                     | A..E bound        |
| `L = 'a=1 b=2 c=3 d=4 e=5 f=6'; <6-capture>`                 | A..F bound        |

Brief's BAD-marker pattern: surrounding `:F(BAD)` should fire on
clear no-match, not silently succeed-with-empty-captures.

## Exit

- 4..6 capture patterns bind all variables correctly.
- Brief's repro produces 'A=1', 'B=2', 'C=3', 'D=4'.
- No regression in just demos / just test.
- Rebuilt `build/snobol4.{bin,lgo}` committed.
- commit + `agentrail complete --done` (final step of saga).

When done: rename branch feat/cap-and-pattern-fixes ->
pr/cap-and-pattern-fixes for dg-reap.
