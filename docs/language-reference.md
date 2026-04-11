# SNOBOL4 language reference

This is the language as actually implemented by the interpreter in
this repository, not the full historical SNOBOL4. It documents which
statement forms, builtins, pattern primitives, and limits the
interpreter currently supports. Use it as a cheat sheet when writing
or porting `.sno` programs.

The interpreter is built from four PL/SW modules:

- `src/sno_main.plsw` -- driver: `MAIN`, calls `READ_SRC` /
  `PARSE` / `LOWER_ALL` / `AM_EXEC`.
- `src/sno_util.plsw` -- I/O helpers: `READ_SRC`, `READ_INPUT`.
- `src/sno_lex.plsw` -- lexer + parser + AM emit.
- `src/sno_exec.plsw` -- lowering + executor + pattern matching +
  builtins.

Plus opcode definitions in `include/am.msw`, shared globals and
limits in `include/snoglob.msw`, and runtime headers in
`include/{descr,heap,pat}.msw`. Built by `scripts/build-modular.sh`
into `build/snobol4.bin`. When you suspect something isn't supported,
grep `src/sno_*.plsw` and `include/*.msw` first.

## Lexical rules

- Source is loaded into a fixed buffer (8 KB cap, see SRC limit
  below). Each line is one statement; comments are lines whose first
  non-blank character is `*`.
- A line that starts in column 1 with an identifier defines a label
  whose name is that identifier. Statements not at column 1 have no
  label.
- String literals use single or double quotes (`'...'` or `"..."`).
  No escape sequences. Max literal length is 127 characters.
- Identifiers are uppercase letters and digits, max 7 effective
  characters (longer identifiers are accepted by the lexer but
  truncated to 7 in the symbol-table slot, so they will collide).
- Lowercase letters in identifiers are folded to uppercase.
- `INPUT` reads a line from a data file (batch mode) or live UART
  (interactive mode). Either way, the read line is **uppercased
  in place** before being returned -- this is by design so that
  pattern matching with literal keywords stays case-insensitive.

## Statements

### Assignment

```
        VAR = expr
LBL     VAR = expr
```

`expr` may be:

- A string literal: `'hello'`
- An integer literal: `42`
- A variable reference: `S`
- A binary expression: `A + B`, `A - B`, `A * B` (also unary minus
  via `0 - X`)
- `REMDR(A, B)` -- integer modulo (the only multi-arg arithmetic
  builtin)
- `INPUT` -- reads one line; fails (`:F`) at end of input
- A concatenation: `'P: ' S` -- juxtaposed parts (max 8 parts per
  statement, same `EPSLOTS` budget as pattern parts). Concat operands
  may mix strings and ints; ints are rendered as decimal.
- `ARRAY('1:N')` -- allocate an array with integer indices 1..N
- An array element: `NAMES<I>` or `NAMES<3>`
- A user function call: `FOO(X)` (after `DEFINE('FOO(X)')`)

### Pattern match

```
        SUBJ pattern... :S(YES) :F(NO)
LBL     SUBJ pattern... :S(YES) :F(NO)
```

A statement whose first token after the (optional) label is a
variable, immediately followed by another token (not `=`), is a
pattern match. The pattern is built from the parts listed in
[Pattern parts](#pattern-parts) below. Up to 8 parts per statement.

There is **no pattern-replacement assignment**. Standard SNOBOL4
allows `S pattern = replacement` to mutate the subject in place;
this interpreter only matches, never replaces. To rewrite a string
you must build a new one.

### Goto

Any statement may end with a goto suffix:

- `:(LBL)` -- unconditional jump
- `:S(LBL)` -- jump if the previous match (or test predicate)
  succeeded
- `:F(LBL)` -- jump if it failed

The `END` keyword on its own line marks the end of the program.

### REFLECT

```
        REFLECT VAR
LBL     REFLECT VAR
```

In-place pronoun swap on a string variable. See
[REFLECT](#reflect-pronoun-swap) below for the table of swaps.

### DUMP

```
        DUMP
```

Print the current values of all integer variables (debug aid).

## Pattern parts

| part            | meaning                                                |
|-----------------|--------------------------------------------------------|
| `'literal'`     | match an exact substring                               |
| `SPAN(class)`   | consume a maximal run of chars drawn from `class`      |
| `BREAK(class)`  | consume up to (not including) any char in `class`      |
| `LEN(N)`        | consume exactly N chars (`N` may be int or variable)  |
| `REM`           | consume the rest of the subject                        |
| `var`           | match the run-time value of `var` as a literal         |
| `. VAR`         | capture the most recently matched span into `VAR`      |

`class` is a string literal whose characters form the alphabet for
that part. Pattern matching is unanchored: the engine tries each
starting position in the subject until one of them matches the
whole pattern, or every position has been tried (then it fails).

There is no `LEN(0)` issue; matching zero chars succeeds at the
current cursor.

Patterns currently **not** supported (would require interpreter
extension):

- `ANY(class)` (single char from a class)
- `NOTANY(class)`
- Pattern alternation `|`
- Conditional / immediate value assignment `$ VAR`
- Recursion via `*PATTERN`
- The `ARB`, `BAL`, `POS`, `RPOS`, `TAB`, `RTAB`, `SUCCEED`, `FAIL`
  primitives

## Builtins (predicate-style)

These return success or failure for `:S` / `:F` branching. They
are 2-arg only.

| builtin       | meaning                                |
|---------------|----------------------------------------|
| `IDENT(A,B)`  | succeeds if A and B are identical      |
| `DIFFER(A,B)` | succeeds if A and B differ             |
| `GT(A,B)`     | A > B                                  |
| `EQ(A,B)`     | A = B                                  |
| `LE(A,B)`     | A <= B                                 |

There is no `LT`, `GE`, or `NE`. Use `:F` on `LE`/`GT`/etc. to get
the opposite.

## Builtins (value-returning)

| builtin              | meaning                                  |
|----------------------|------------------------------------------|
| `REMDR(A,B)`         | integer A mod B                          |
| `ARRAY('lo:hi')`     | allocate a 1-D array                     |
| `SPAN(class)`        | (also a pattern part; assignable to var) |
| `BREAK(class)`       | (also a pattern part)                    |

`SPAN`/`BREAK` can be assigned to a variable to make a reusable
pattern: `DIGITS = SPAN('0123456789')`, then `S DIGITS . N`.

## REFLECT (pronoun swap)

The `REFLECT VAR` statement walks the string in `VAR` word by word
and rewrites each known word in place. Built for ELIZA-style
demos but useful anywhere you want first/second-person inversion.

| input    | output  |
|----------|---------|
| `I`      | `YOU`   |
| `ME`     | `YOU`   |
| `MY`     | `YOUR`  |
| `MINE`   | `YOURS` |
| `AM`     | `ARE`   |
| `YOU`    | `I`     |
| `YOUR`   | `MY`    |
| `YOURS`  | `MINE`  |
| `ARE`    | `AM`    |
| `WAS`    | `WERE`  |
| `WERE`   | `WAS`   |

Words are runs of non-space characters; matching is exact (the input
is already uppercased by `READ_INPUT`). Unrecognized words pass
through unchanged.

## DEFINE'd functions

```
        DEFINE('FOO(X)')
        ...
FOO     FOO = '...result...' :(RETURN)
```

A user function is declared with `DEFINE('NAME(PARAM)')`. The
interpreter currently supports **single-argument** user functions
only, and at most 4 of them per program. The function body starts
at the label whose name matches `NAME`. Inside the body the
function name is also a variable: assigning to it sets the return
value. Use `:(RETURN)` to return successfully or `:(FRETURN)` to
return as a failure.

The call stack is 16 frames deep, so recursion is allowed up to
that depth.

## I/O

- `OUTPUT = expr` prints `expr` followed by a newline. Concatenated
  expressions print as a single line.
- `LINE = INPUT` reads one line from the current input source:
  - Batch mode: data file loaded at memory `0x090000`. Use
    `./scripts/run-snobol4.sh prog.sno data.dat`.
  - Interactive mode: live UART RX (typed input). Use
    `./scripts/run-snobol4-tty.sh prog.sno`. Backspace and Ctrl-D
    work; `INPUT` fails at EOF.
- The interpreter chooses between batch and interactive at startup:
  if no data file is loaded (first byte at `0x090000` is null) it
  switches to TTY mode automatically.
- Both paths uppercase ASCII a-z to A-Z as the line is read. There
  is currently no way to preserve case.

## Limits

These are the static sizes you'll bump up against on a complex
program. Defined in `include/snoglob.msw` (and in `include/am.msw`
for opcode numbers). Bump them as needed and rebuild; nothing is
runtime-allocated.

| limit                       | value     | notes                          |
|-----------------------------|-----------|--------------------------------|
| Source buffer (`SRC`)       | 8192 B    | one program file               |
| String literal length       | 127       | per literal                    |
| Identifier length           | 7         | effective; longer = collision  |
| Statements (`STMAX`)        | 256       | each comment line uses 1 slot  |
| Labels (`LBL_MAX`)          | 64        |                                |
| Symbol table (`SYMMAX`)     | 64        | named variables in scope       |
| String buffer (`SB`)        | 4096 B    | grows during execution         |
| Token buffer (`TB`)         | 128       | per-token scratch              |
| Eval stack (`ESTK_DEPTH`)   | 256       | expression evaluation          |
| AM bytecode (`AM_CODE_SIZE`)| 4096 B    | compiled code buffer           |
| Pattern parts per stmt      | 8         | `PP_TYP/PP_VAL` slots (`EPSLOTS`) |
| Concat parts per stmt       | 8         | `EP_TYP/EP_VAL` slots (`EPSLOTS`) |
| User functions (`FN_*`)     | 4         | total `DEFINE`'d               |
| Call stack (`CSTK_*`)       | 16        | recursion depth                |
| Arrays (`ARR_MAX`)          | 8         | total `ARRAY()` allocations    |
| Array element capacity      | 50/array  | `ARR_DATA(arr_id*50 + idx)`    |
| Array pool (`ARR_POOL`)     | 400       | `ARR_MAX * ARR_ELEMS`          |
| Pattern stack (`PSTK`)      | 16        | depth during one match         |

## What's missing vs. classic SNOBOL4

In rough priority order, things real SNOBOL4 has that this
interpreter does not. Some are easy adds, some would be substantial
work; treat this as a wish list.

- **Pattern-replacement assignment** (`S pat = repl`). The single
  biggest missing feature; lots of canonical SNOBOL4 idioms (string
  edit, tokenize-and-rebuild, recursive pattern application) need
  it.
- **Conditional/immediate value assignment** (`$ VAR` after a
  pattern part).
- **`ANY` / `NOTANY` / `ARB` / `POS` / `RPOS` / `TAB` / `RTAB`**
  pattern primitives.
- **Pattern alternation** (`|`).
- **Recursive patterns** (`*PATTERN`).
- **`TABLE`** (associative array). Only fixed-size integer-indexed
  `ARRAY` is supported.
- **Multi-arg user functions.** `DEFINE('FOO(X,Y)')` parses but only
  the first arg is wired up.
- **String operations.** No `SIZE`, `REVERSE`, `REPLACE`, `TRIM`,
  `DUPL`, `SUBSTR`, `CONVERT`. (`REVERSE` can be done in user
  code with `LEN`; see `demos/reverse.sno`.)
- **`&` system variables.** No `&ALPHABET`, `&LCASE`, `&UCASE`,
  `&ANCHOR`, `&TRIM`, etc.
- **Real numbers.** Integers only.
- **Indirect goto** `:($VAR)`.
- **Backtracking** within a single statement beyond what
  `PAT_MATCH2` already does.
- **No way to preserve input case.** `READ_INPUT` always
  uppercases.

## Demos and examples to read

- `examples/hello.sno` -- simplest possible
- `examples/pattern-tutorial.sno` -- guided tour of pattern parts
- `examples/array.sno` -- string-valued arrays
- `examples/dating.sno` -- `DEFINE`'d functions, BREAK + REM,
  data file input
- `demos/sieve.sno` -- arrays + arithmetic loop
- `demos/gcd.sno` -- `REMDR`, integer concat in OUTPUT
- `demos/reverse.sno` -- character reversal via `LEN(I) LEN(1) . C`
- `demos/nqueens.sno` -- backtracking via three "used" arrays
- `demos/eliza.sno` -- the big one: pattern matching, capture,
  `REFLECT`, history ring, response rotation

For tutorials and demos still to be written see
`docs/planned-demos.md`.
