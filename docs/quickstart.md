# SNOBOL4 quickstart

Five minutes from zero to a running interactive program.

## Prerequisites

You need a working build of the SNOBOL4 interpreter. From the
project root:

```
./scripts/build-modular.sh
```

This produces `build/snobol4.bin`. The run scripts auto-rebuild it
when source changes, so you don't normally need to invoke this
yourself.

## Step 1: Hello, world

Save this as `hello.sno` (or use the existing
`examples/hello.sno`):

```
        OUTPUT = 'Hello, SNOBOL4!'
END
```

Run it:

```
./scripts/run-snobol4.sh hello.sno
```

Things to notice:

- `OUTPUT = expr` prints `expr` followed by a newline. `OUTPUT` is
  a special variable; assigning to it is how you write to the
  terminal.
- String literals use single (or double) quotes.
- The `END` keyword on its own line marks the end of the program.
- Statements are not column-sensitive *except* for labels: an
  identifier in column 1 is the label of that statement. Anything
  else (whitespace at the start) means the statement has no label.

## Step 2: A loop

```
        OUTPUT = 'counting:'
        I = 1
LOOP    OUTPUT = '  ' I
        I = I + 1
        LE(I,5) :S(LOOP)
END
```

New things:

- Variables don't need declaration. Assignment creates them.
- `LOOP` is a label (column 1). Other statements jump to it via
  `:S(LOOP)` (success branch).
- `LE(I,5)` is a 2-arg builtin predicate. It "succeeds" if `I <= 5`
  and "fails" otherwise. The `:S(LBL)` suffix says "if the test
  succeeded, jump to LBL".
- Available predicates: `IDENT`, `DIFFER`, `GT`, `EQ`, `LE`. There
  is no `LT` -- use `:F` on `LE` to get the opposite.
- `OUTPUT = '  ' I` concatenates a literal and an integer; concat
  prints ints as decimal.

Run it the same way: `./scripts/run-snobol4.sh yourfile.sno`.

## Step 3: Reading input from a data file

Save as `greet.sno`:

```
LOOP    LINE = INPUT :F(BYE)
        OUTPUT = 'hello, ' LINE
        :(LOOP)
BYE     OUTPUT = 'goodbye.'
END
```

And `greet.dat`:

```
alice
bob
carol
```

Run with the data file as the second argument:

```
./scripts/run-snobol4.sh greet.sno greet.dat
```

You should see:

```
hello, ALICE
hello, BOB
hello, CAROL
goodbye.
```

Notice that the names came back uppercased -- `INPUT` always
uppercases its result, by design, so that pattern matching with
literal keywords stays case-insensitive. This is unusual for a
modern language but matches classic SNOBOL4 conventions.

`LINE = INPUT :F(BYE)` is the standard end-of-input idiom: when
there's nothing more to read, the assignment fails and the `:F`
branch fires.

## Step 4: Going interactive

The same `greet.sno` works as a live REPL with no changes -- just
launch it without a data file:

```
./scripts/run-snobol4-tty.sh greet.sno
```

Type lines and press Enter; each one comes back greeted. Hit
Ctrl-D on an empty line to exit, or Ctrl-] to bail out of the
emulator entirely.

The interpreter probes the data-file region at startup; if it's
empty, it switches `INPUT` to read live UART characters instead.
No source change required. (See `src/sno_main.plsw` and
`src/sno_util.plsw`'s `READ_INPUT` for the mechanism.)

## What to read next

- **`docs/language-reference.md`** -- the full cheat sheet:
  every statement form, every builtin, every pattern part, and the
  static limits.
- **`examples/pattern-tutorial.sno`** -- guided tour of pattern
  matching (literal / SPAN / BREAK / REM / LEN / capture).
- **`examples/define-tutorial.sno`** -- writing your own functions.
- **`examples/io-tutorial.sno`** -- the same input loop as above,
  but more verbose, with both modes annotated.
- **`demos/eliza.sno`** -- a 90-line interactive ELIZA showing
  most of the language at once: pattern capture, `REFLECT` for
  pronoun swap, history recall via an `ARRAY`, and response
  rotation via `REMDR`.
- **`docs/planned-demos.md`** -- backlog of demos and tutorials
  not yet written, plus the language features that would unblock
  them.
