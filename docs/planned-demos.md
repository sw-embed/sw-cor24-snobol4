# Planned demos and tutorials

A backlog of `.sno` programs and docs that would round out the demo set.
None of these are implemented yet. Each entry notes scope, what
interpreter feature it exercises, and any blockers.

## Core-feature walkthroughs

Short, single-feature files (~20–40 lines) with comments explaining
each construct as it appears.

- **`examples/pattern-tutorial.sno`** — literal patterns, `SPAN`,
  `BREAK`, `REM`, capture with `. var`, and `:S/:F` branching, all in
  one annotated file. Replaces the current `examples/pattern.sno`,
  which is a 4-line stub marked "NOT YET SUPPORTED."
- **`examples/reflect-tutorial.sno`** — exercises the `REFLECT`
  statement on a few canned strings, highlighting which words swap
  (I↔YOU, MY↔YOUR, AM↔ARE, ME→YOU, MINE↔YOURS, WAS↔WERE).
- **`examples/define-tutorial.sno`** — `DEFINE('FOO(X)')` user
  functions. Only `examples/dating.sno` uses them today and it's
  terse.
- **`examples/array-tutorial.sno`** — string-keyed and integer-keyed
  arrays, indexed assignment, iteration. **Blocked** on the
  `NAMES<i>`-prints-int-instead-of-string bug (see Known bugs).
- **`examples/io-tutorial.sno`** — `INPUT` from a data file *and* the
  live-UART path, plus the `:F(EOF)` end-of-input idiom. Cross-links
  to `scripts/run-snobol4-tty.sh`.

## Algorithm demos

Showcasing what the language can already do.

- **`demos/reverse.sno`** — string reversal via recursion or BREAK
  loop. Classic intro.
- **`demos/palindrome.sno`** — checks whether a line is a palindrome.
- **`demos/wordcount.sno`** — counts words in a line. Probably needs
  pattern-replacement assignment (`S BREAK(' ') ' ' = ''`) which the
  interpreter doesn't yet support; until then, do it the hard way
  with REM captures and a manual cursor.
- **`demos/tower.sno`** — Towers of Hanoi via recursive DEFINE'd
  function. Tests recursion and call-stack depth.
- **`demos/fibonacci.sno`** — iterative + recursive comparison.
- **`demos/gcd.sno`** — Euclid's algorithm using `REMDR`.

## Bigger showpieces

- **`demos/adventure.sno`** — a tiny text-adventure room navigator.
  Reads `INPUT`, matches `GO NORTH` / `LOOK` / `INVENTORY`, prints
  room descriptions. Complements ELIZA as another interactive demo.
- **`demos/calc.sno`** — single-line expression evaluator: read a
  line, parse `N OP N`, print the result. Shows the language doing
  real parsing.
- **`demos/life.sno`** — Conway's Game of Life on a 10×10 grid using
  a 2D array (or two 1D arrays). Exercises `ARRAY` heavily.

## Documentation pages

- **`docs/language-reference.md`** — what this interpreter actually
  implements: statement forms, builtins (`IDENT`, `DIFFER`, `GT`,
  `EQ`, `LE`, `REMDR`, `SPAN`, `BREAK`, `REM`, `ARRAY`, `REFLECT`,
  `DUMP`), and the current limits (string-literal cap 127,
  identifier cap 7, `STMAX` 128, `SYMMAX` 24, `LBLMAX` 32, `SB` 4096,
  `SRC` 8192). Should also list which classic SNOBOL4 features are
  *not* supported (e.g., pattern-replacement assignment).
- **`docs/quickstart.md`** — "write your first SNOBOL4 program in 5
  minutes": `hello.sno` → adding a loop → adding `INPUT` → switching
  to interactive mode via `run-snobol4-tty.sh`.
- **`docs/feature-matrix.md`** — table of standard SNOBOL4 features
  vs. what this interpreter supports vs. planned. Right now
  newcomers can't tell, e.g., that `S 'X' = 'Y'` pattern-replacement
  isn't supported.

## Known bugs to fix before / alongside the demos above

- **`NAMES<i>` prints integer instead of string content.** When a
  string is stored in an array element and then loaded for printing,
  `OP_ARR_LOAD` returns the raw stored value without setting the
  destination's `VTYP`, so `OP_PRINT_VAR` formats it as a decimal SB
  offset instead of dereferencing it as a string. Blocks
  `array-tutorial.sno` and any algorithm that wants to store and
  print strings in an array.

## Suggested first batch (highest immediate value)

1. `examples/pattern-tutorial.sno`
2. `demos/reverse.sno`
3. `demos/gcd.sno`
4. `docs/language-reference.md`
