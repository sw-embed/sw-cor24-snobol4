# Step 2 -- ANY(class) pattern fails silently

Brief: `tools/briefs/dcsno-any-pattern-fails.md`.

`ANY(class)` -- "match exactly one character from `class`" --
fails the match even when the subject starts with a char in
`class`. SPAN(class) works correctly. dcftn worked around it by
using SPAN everywhere, but that over-consumes when the input
has runs of class chars.

## Repro

```sno
        S = 'X'
        S ANY('X') :S(MATCH)F(NOMATCH)
MATCH   OUTPUT = 'matched'                                                            :(DONE)
NOMATCH OUTPUT = 'no match'                                                           :(DONE)
DONE    OUTPUT = 'end'
END
```

Expected: `matched\nend`. Today: `no match\nend`.

## What to investigate

1. Locate the ANY opcode handler. Probable site: `src/sno_exec.plsw`
   pattern evaluator (PMATCH or similar). Compare against the
   SPAN handler for the same class-decode + cursor-advance shape.
2. Discriminator: try `S ANY('') :S(YES)F(NO)`. If YES fires,
   the bug is an ANY/NOTANY swap (ANY is evaluating NOTANY).
   If NO fires correctly but `ANY('X')` against `'X'` still fails,
   the bug is in success-path bookkeeping (cursor advance,
   success flag, post-match consume).
3. Common patterns for "match-one-char primitive that fails":
   - Loop body never executes because the cap check is off-by-one
     (`while count < 1` vs `count <= 1`).
   - Match succeeds but cursor doesn't advance, so the outer
     pattern engine treats it as a zero-width match and rejects.
   - Match succeeds but the success flag is set on the wrong
     branch.

## Tests

Add `examples/any_pattern.sno` with the brief's test table:

| pattern                                  | expected |
|------------------------------------------|----------|
| `S = 'X'; S ANY('X') :S(YES)F(NO)`       | YES      |
| `S = 'X'; S ANY('Y') :S(YES)F(NO)`       | NO       |
| `S = 'X'; S ANY('XY') :S(YES)F(NO)`      | YES      |
| `S = 'X'; S ANY('AB') :S(YES)F(NO)`      | NO       |
| `S = ''; S ANY('X') :S(YES)F(NO)`        | NO       |
| `S = 'ABC'; S ANY('A') . CH :S(YES)F(NO)`| YES, CH='A' |
| `S = 'ABC'; S ANY('Z') . CH :S(YES)F(NO)`| NO       |

Plus a `NOTANY('') :S(YES)F(NO)` against empty subject as a
sanity check that NOTANY isn't broken in mirror.

## Exit

- ANY repro from the brief produces `matched\nend`
- `examples/any_pattern.sno` green with all expected outputs
- No regression in just demos / just test
- Rebuilt `build/snobol4.{bin,lgo}` committed
- commit + `agentrail complete --next-slug concat-truncation`
