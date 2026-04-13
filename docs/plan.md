# Plan -- SNOBOL4 on PL/SW for COR24

## 1. Plan summary

This plan sequences the work so that each phase:

1. validates a risky architectural assumption early
2. produces tooling before complexity multiplies
3. keeps semantic and machine concerns separated
4. results in usable dogfooding infrastructure in PL/SW

## 2. Development strategy

The overall strategy is:

1. build the runtime substrate first
2. build diagnostics immediately
3. bring up a small evaluator before broad syntax
4. add pattern execution as a first-class subsystem
5. lower into AM-oriented forms rather than hard-wiring direct tree walking forever
6. expand the runtime to support real programs before optimizing internals
7. delay GC and architectural cleanup until real workloads justify them

## 3. Milestone sequence

```
M0  Runtime substrate and diagnostics          [DONE]
M1  Minimal execution core                     [DONE]
M2  Abstract machine boundary                  [DONE]
M3  First pattern subsystem (SPAN, capture)    [DONE]
M4  Richer runtime (arrays, functions, I/O)    <-- next
M5  Dating app demo                            <-- target demo
M6  Pattern engine improvements (BREAK, etc.)
M7  Pattern lowering and graph form
M8  Garbage collection maturity
M9  Self-dogfooding improvement tools
```

Rationale for resequencing (vs original plan):

- M4 (richer runtime, was M6) moves up because real programs need
  arrays, functions, builtins, and I/O before the pattern engine needs
  refactoring. Features before architecture.

- M5 (dating app) is the exit test for M4. It exercises parsing,
  arrays, functions, arithmetic, string matching, multi-pass
  processing, and I/O. See docs/student-dating-app.txt.

- M6 (pattern improvements) adds BREAK, REM, and other primitives
  needed for the dating app's record parser. Could merge into M4 if
  small enough.

- M7 (pattern graph form, was M4) deferred because the current
  pattern engine works. Refactor when there is something worth
  refactoring.

- M8 (GC, was M5) deferred because short-lived demo programs do not
  need garbage collection. Only matters with long-running or
  loop-heavy workloads.

- M9 (self-dogfooding, was M7) last, as before.

## 4. Milestones

## Milestone 0 -- runtime substrate and diagnostics [DONE]

### Goals

- Prove that PL/SW can comfortably host the low-level runtime substrate.
- Establish regular descriptor and heap object conventions.
- Build tooling before semantics grow.

### Deliverables

1. descriptor definitions
2. descriptor helpers/macros
3. heap block header definitions
4. allocator interface
5. descriptor dumper
6. heap walker
7. heap consistency checker
8. stack dump support
9. assertion/trap/logging hooks

### Exit criteria

- Can allocate and free or recycle basic blocks.
- Can dump every known object kind.
- Can detect basic heap corruption.
- Can trace allocator activity.

## Milestone 1 -- minimal execution core [DONE]

### Goals

- Run simple non-pattern programs.
- Validate the success/failure execution model.

### Deliverables

1. source reader
2. lexer for minimal language subset
3. parser for assignments, labels, transfers, literals
4. symbol table
5. descriptor-based value storage
6. simple statement executor
7. success/failure result propagation
8. statement trace support

### Exit criteria

- Small programs with variables and labels run correctly.
- Runtime traces show deterministic execution.
- Heap remains valid under test load.

## Milestone 2 -- abstract machine boundary [DONE]

### Goals

- Introduce an explicit AM-oriented internal form.
- Prevent parser and executor from becoming permanently entangled.

### Deliverables

1. symbolic AM representation
2. lowering pass from parsed forms to AM
3. AM dump/disassembly tool
4. executor for core AM operations

### Exit criteria

- Core programs run via AM rather than directly from source tree structures.
- AM traces are readable and useful.

## Milestone 3 -- first pattern subsystem [DONE]

### Goals

- Introduce real SNOBOL-like behavior.
- Validate explicit backtracking and rollback.

### Deliverables

1. subject cursor model
2. literal pattern matching
3. SPAN primitive (character class scanning)
4. capture via . operator
5. unanchored matching (scan at successive positions)
6. success/failure result driving :S()/:F() gotos

### Exit criteria

- SPAN('0123456789') captures digits from a string.
- :F() failure branch works when pattern does not match.
- Pattern match statement parses and executes correctly.

## Milestone 4 -- richer runtime

### Goals

- Expand the interpreter to support real SNOBOL4 programs.
- Add the features needed for the dating app demo.

### Deliverables

1. ARRAY() primitive and <> indexed access
2. TABLE() primitive (associative lookup)
3. DEFINE() for user-defined functions
4. RETURN and FRETURN (success/failure function return)
5. local variables in functions
6. builtin functions: IDENT, DIFFER, GT, EQ, LE, ABS
7. string concatenation in expressions
8. multiplication operator (*)
9. INPUT variable (read lines from data, EOF detection)
10. continuation lines (+ in column 1)
11. BREAK pattern primitive
12. REM pattern primitive

### Exit criteria

- User-defined functions with RETURN/FRETURN work.
- Arrays and tables store and retrieve values.
- BREAK('|') parses pipe-delimited records.
- INPUT reads lines until EOF.
- The dating app (M5) can be attempted.

## Milestone 5 -- dating app demo

### Goals

- Run a complete, historically-inspired SNOBOL4 application.
- Exercise the full interpreter feature set.
- Produce demo-worthy output for blogging/vlogging.

### Target program

Late-70s style campus dating profile matcher (see docs/student-dating-app.txt):

- reads pipe-delimited student records from a data file
- parses records using BREAK('|') and . capture
- stores fields in parallel arrays
- computes pairwise compatibility scores (major, interests, eye/hair)
- prints matches with contact info from a directory lookup table
- uses user-defined functions (HAS, COMMON, SCORE)
- demonstrates success/failure control flow throughout

### Sample data

```
Alice|F|English|brown|brown|music,books,art
Bob|M|Physics|blue|blonde|chess,movies,hiking
```

### Expected output shape

```
--- Matches for Alice ---
  Alan  score=55  Evans Hall, room 110  mailbox MH-501
```

### Exit criteria

- Dating app runs end-to-end on COR24 emulator.
- Output is correct and readable.
- LED/switch I/O demo works (unit 242, text "0"/"1" protocol).

### Optional enhancements

- sorted output (top N matches per person)
- unit-number I/O for LED/switch panel device
- printable fixed-width report mode

## Milestone 6 -- pattern engine improvements

### Goals

- Add remaining pattern primitives needed for robust parsing.
- Improve backtracking for complex patterns.

### Candidate deliverables

1. BREAK(class) -- match up to first char in class
2. REM -- match remainder of subject
3. ANY(class) -- match single char from class
4. LEN(n) -- match exactly n characters
5. ARB -- match arbitrary characters (with backtracking)
6. alternation (pattern | pattern)
7. pattern concatenation (pattern pattern)
8. improved backtrack stack with rollback

### Exit criteria

- Complex multi-field record parsing works.
- Alternation and backtracking produce correct results.
- Pattern trace shows backtrack/restore activity.

### Note

Some of these (BREAK, REM) may be pulled into M4 if the dating app
needs them before the full pattern improvements are ready. The boundary
between M4 and M6 is flexible.

## Milestone 7 -- pattern lowering and graph form

### Goals

- Make patterns inspectable and structured.
- Avoid ad hoc pattern execution logic.

### Deliverables

1. pattern node or graph object design
2. lowering from parsed patterns to pattern graph
3. pattern graph dumper
4. graph-based execution driver

### Exit criteria

- Pattern graphs can be dumped and executed.
- Structural bugs are easier to isolate than with direct tree-walk logic.

## Milestone 8 -- garbage collection maturity

### Goals

- Support longer runs and more dynamic behavior.
- Make heap state robust under pattern-heavy workloads.

### Deliverables

1. mark-sweep collector
2. explicit root enumeration interfaces
3. per-object-kind scanners
4. GC trace mode
5. post-GC validation mode

### Exit criteria

- Long-running tests recover space.
- No live reachable objects are lost in standard test cases.
- Diagnostic tools remain trustworthy after collections.

## Milestone 9 -- self-dogfooding improvement tools

### Goals

- Use PL/SW to assist development of the implementation itself.

### Candidate tools

1. AM lister/disassembler enhancements
2. heap/object cross-reference views
3. trace filtering tools
4. test harness helpers in PL/SW
5. source/checker utilities
6. profiler counters or simple execution statistics

### Exit criteria

- At least some development tasks are materially easier because of PL/SW-hosted tools.

## 5. Work breakdown structure

## 5.1 Foundation work [DONE]

1. choose descriptor physical layout
2. choose heap header layout
3. define clobber/calling conventions for low-level macros
4. define root registration model
5. define logging and assertion conventions

## 5.2 Frontend work [DONE]

1. token model
2. parser skeleton
3. AST or source-structure definitions
4. normalization/lowering path

## 5.3 Runtime work [partially done]

1. symbol environment [done]
2. descriptor conversion rules [done]
3. assignment and transfer model [done]
4. builtin dispatch model [M4]
5. pattern subject/cursor model [done]
6. array/table support [M4]
7. function definition and call [M4]
8. I/O subsystem [M4]

## 5.4 Tooling work [DONE]

1. dump format conventions
2. consistency checker conventions
3. trace category flags
4. test harness conventions

## 6. Testing strategy

## 6.1 Unit-level tests

Use focused tests for:

- descriptor construction
- heap header validation
- object scanning
- symbol updates
- rollback entries
- backtrack frame restoration

## 6.2 Scenario tests

Use end-to-end scenario tests for:

- assignment/label flow
- success/failure transfers
- basic pattern matching
- alternation and rollback
- GC under load

## 6.3 Diagnostic validation tests

Ensure that tools themselves are tested:

- descriptor dumper on every kind
- heap walker on crafted heaps
- corruption checker on intentionally malformed heaps where possible
- pattern graph dump on representative forms

## 6.4 Demo programs as integration tests

Each milestone should produce a runnable .sno example:

- M1: hello.sno, count.sno
- M3: span.sno, span_fail.sno
- M4: array_demo.sno, function_demo.sno
- M5: dating_demo.sno (full app)

## 7. Tooling priorities

Build these early and keep them current:

1. descriptor dumper
2. heap walker
3. heap consistency checker
4. pattern trace
5. statement trace
6. AM dump/disassembly

These are not optional extras; they reduce the cost of every later milestone.

## 8. Key decisions to freeze early

Freeze early to avoid churn:

1. descriptor baseline shape
2. heap header baseline shape
3. semantic stack split
4. AM category boundaries
5. trace category naming

## 9. Deferrable decisions

Safe to defer:

1. dense AM encoding
2. threaded dispatch
3. aggressive inline assembler optimization
4. full arrays/tables [now M4]
5. future S/370-ish physical layout
6. later 31-bit evolution details

## 10. Risks and mitigation tasks

## Risk: macro complexity explosion

### Mitigations

- document each macro layer separately
- keep names systematic
- include expansion examples in comments/docs

## Risk: register starvation in hot code

### Mitigations

- design scratch-slot conventions in memory
- isolate hot primitives for optional inline assembler
- measure before optimizing

## Risk: pattern engine instability

### Mitigations

- explicit backtrack frames
- explicit rollback checkpoints
- detailed trace output
- small pattern corpus first

## Risk: GC bugs hidden behind semantic complexity

### Mitigations

- build heap walker first
- force frequent GC in debug mode
- test root enumeration independently

## Risk: PL/SW compiler limits

### Mitigations

- file issues promptly when limits are hit
- keep source files compact
- use %DEFINE for constants, not DCL STATIC where possible
- test compilation frequently during development

24 PL/SW compiler issues filed and resolved during M0-M3.

## 11. I/O architecture (from docs/mmio.md)

The interpreter uses a layered I/O model:

```
SNOBOL4 symbol (INPUT, OUTPUT)
    |
logical channel / unit number
    |
device binding (UART, GPIO, file)
```

- INPUT reads from memory-loaded data (--load-binary at 0x080000)
- OUTPUT writes via UART TX
- Future: unit-number I/O for LED/switch (unit 242, text "0"/"1")
- Future: multi-file input (directory + profiles for dating app)

## 12. Current state (April 2026)

Completed: M0 - M5 plus a substantial post-M5 expansion (sieve, n-queens,
ELIZA, palindrome, fibonacci, factorial, gcd, reverse, plus tutorials).
SIZE / SUBSTR / CHAR builtins added (issue #1), SYMMAX / STMAX /
LBL_MAX / ESTK / ARR_POOL bumped, silent-memory-corruption regression
fixed (issues #2 / #3), SPAN/BREAK pattern variable corruption of REM
matching with arrays fixed (issue #4), executor refactored to
SELECT/WHEN dispatch, interactive UART INPUT, REFLECT, DUMP, all
shipping in the modular interpreter.

The interpreter is **modular**. It is built from four PL/SW source
modules:

```
src/sno_main.plsw   -- driver: MAIN, calls READ_SRC, PARSE, LOWER_ALL, AM_EXEC
src/sno_util.plsw   -- I/O helpers, READ_SRC, READ_INPUT
src/sno_lex.plsw    -- lexer + parser + AM emit
src/sno_exec.plsw   -- lowering + executor + pattern matching + builtins
```

Plus the shared globals header `include/snoglob.msw` and the
runtime headers `include/{descr,heap,am,pat}.msw`. The build pipeline
is `scripts/build-modular.sh` which produces `build/snobol4.bin`.
Every demo, every tutorial, the TTY runner, `scripts/run-snobol4.sh`,
and `just build` all use this modular binary.

There are no monolithic single-file interpreter sources in the repo
going forward. See section 13 for the cleanup that established this.

## 13. Modular cleanup and runtime-split plan (April 2026)

### 13.1 Background

A series of agent sessions in early-to-mid April 2026 left the working
tree with confusing state: an untracked stale single-file interpreter
copy `src/snobol4.plsw` (predates SIZE/SUBSTR/CHAR), an unfinished
3-module refactor draft `src/sno_engine.plsw` + `src/snolib.plsw`,
and a `justfile build:` target pointing at the dead monolith. None of
these were used by the actual demos -- the tracked 4-module split has
always been the working interpreter. But the arrangement was misleading
enough that a fresh reader could reasonably conclude the working
interpreter was the monolith.

In addition, agentrail saga records for the snobol4-demos saga
(sieve / nqueens / ELIZA, Apr 8) and the post-demos work
(planned-demos doc + two demo batches + issues #1-#4 + executor
refactor) had been deleted. The saga.toml + plan.md for snobol4-demos
were recovered from a git stash; the rest was reconstructed from
commit history via `agentrail audit`.

### 13.2 Reconstruction (already done)

Three retroactive sagas were rebuilt by `agentrail audit` and the
new `agentrail add --commit` flag, and archived:

- `snobol4-fizzbuzz` (m5): m5-remdr, m5-fizzbuzz, m5-polish
- `snobol4-demos`: sieve, nqueens, eliza
- `snobol4-cleanup`: demos, bugfixes, executor-refactor

`agentrail audit` reports zero gaps between git history and saga history.

### 13.3 Cleanup phases

Each phase commits separately so tests pass at every commit. The
intent is that any phase can be reverted or cherry-picked individually.

**Phase 0 -- snapshot.** Commit everything currently in the working
tree (including the dead untracked `snobol4.plsw`, the unfinished
`sno_engine.plsw` + `snolib.plsw`, the new `.agentrail-archive`
directories, and this plan.md update) so nothing is at risk of being
lost. Tag the resulting commit `fallback pre-cleanup`. This commit is
the only place those dead files will live going forward; later phases
remove them from the tip.

**Phase A -- remove dead code.** `git rm src/snobol4.plsw
src/sno_engine.plsw src/snolib.plsw`. The files are preserved in the
`fallback pre-cleanup` tag for resurrection or cherry-pick. Tests
re-run; they pass because nothing in the build pipeline ever depended
on these files.

**Phase B -- repair `just build`.** The current `justfile build:`
target invokes `scripts/build.sh` against the dead monolith. Replace
with the modular build so `just build` produces the actual interpreter.
The user-facing surface stays `just build`; no need to add a separate
`just build-modular` target.

**Phase C -- make modular explicit and irreversible.** Update
`CLAUDE.md` with a prominent note that the interpreter is modular and
that agents must not create monolithic single-file interpreter sources.
Add `src/snobol4.plsw`, `src/sno_engine.plsw`, `src/snolib.plsw` to
`.gitignore` so they cannot accidentally re-enter the tree as
untracked files. Refresh the stale limits table in
`docs/language-reference.md` (STMAX 128->256, SYMMAX 24->64, LBL_MAX
32->64, ESTK 128->256, ARR_POOL 200->400) and replace the
"interpreter source lives in `src/sno_*.plsw`" sentence with an
explicit list of the four files and what each holds. Fix the stale
`docs/quickstart.md` reference if needed.

**Phase D -- tag stable point.** Tag the post-Phase-C commit
`v0-modular-stable`. This is the known-good reference for the modular
interpreter before any further refactoring. The runtime-split saga
(section 13.4) starts from here.

**Phase E -- start the runtime-split saga.** Initialize a new active
agentrail saga, `snobol4-runtime-split`, to begin the next architectural
work.

### 13.4 The snobol4-runtime-split saga (next)

**Motivation.** The current 4-module split is layered by *function*:
util, lex, exec, main. The next architectural improvement is to
re-split along a different axis -- *runtime helpers vs compiler
engine vs driver* -- so that the runtime portion (descriptor and
heap helpers, basic primitives) can be linked into compiled SNOBOL4
programs without dragging in the lexer, parser, and executor. This
prepares the ground for standalone compiled .sno -> .bin output.

**Target shape.**

```
src/snolib.plsw     -- runtime library: descriptors, heap, helpers
                       (linkable into compiled SNOBOL4 programs)
src/sno_engine.plsw -- compiler + executor library: lexer, parser,
                       AM emit, lowering, executor, pattern matching
src/snobol4.plsw    -- driver: MAIN, wires snolib + sno_engine
```

The names match the dormant unfinished drafts that lived in the working
tree before Phase A removed them, and the `fallback pre-cleanup` tag
preserves those drafts as a starting reference. The runtime-split saga
may cherry-pick from them or start fresh.

**Plan (sketch -- will be refined when the saga is initialized).**

1. snolib -- extract runtime library from `sno_util.plsw` + the
   helpers in `sno_exec.plsw`. Tests via existing test_snolib /
   test_snolib2 suites.
2. sno-engine -- consolidate `sno_lex.plsw` + the executor portion of
   `sno_exec.plsw` into a single linkable engine module that compiles
   cleanly stripped of the runtime library.
3. snobol4-main -- new top-level `snobol4.plsw` driver that wires
   snolib + sno_engine; existing demos still run end-to-end via
   `scripts/run-snobol4.sh`.
4. linker -- update `scripts/build-modular.sh` (or successor) for the
   new module layout; verify the strip step.
5. validate -- run the full demo suite (fizzbuzz, sieve, nqueens,
   eliza, palindrome, factorial, etc.) against the new build.

**Exit criteria.** All existing tests and demos pass against the
re-split layout. `scripts/build-modular.sh` produces a working
interpreter from the new three-file layout. The runtime library
(`snolib.plsw`) compiles cleanly as a standalone library that could
be linked into a compiled .sno -> .bin output.

### 13.5 Deferred: FORTRAN compiler prerequisites

A FORTRAN compiler written in SNOBOL4 is an active stated direction
(see `sw-embed/sw-cor24-fortran`, currently in the FTI-0 milestone).
The runtime-split saga is not blocking it. Four interpreter features
are prerequisites for a non-trivial FORTRAN compiler:

1. Pattern-replacement assignment (`S pat = repl`) -- the canonical
   SNOBOL4 idiom for source rewriting.
2. `TABLE` (associative arrays) -- to build a symbol table of
   FORTRAN identifiers without parallel-array workarounds.
3. Multi-arg user functions -- so a code generator can write
   `EMIT(opcode, operand)` cleanly.
4. Higher SNOBOL4-program-side limits (the FORTRAN compiler itself
   would currently get only 64 named variables and 256 statements
   to work with).

These features are not prerequisites for the runtime-split saga.
Schedule them as their own saga after the split lands, or earlier if
sw-cor24-fortran needs them.

### 13.6 Cleanup status (2026-04-11)

All six cleanup phases complete.

- Phase 0 snapshot commit: `c6f8ac4`, tagged `fallback-pre-cleanup`.
- Phases A - D executed as separate commits with tests green at each.
- Phase C commit `ba0ebaf` tagged `v0-modular-stable` -- the
  architectural baseline.
- Phase E started the `snobol4-runtime-split` saga in commit
  `74caf80`; step 1 (`snolib` extraction) defined, not yet started.
- The eight cleanup commits were retroactively claimed by a
  `snobol4-modular-cleanup` saga (amended in commit `c96a16c` after
  the first attempt recorded short commit hashes that didn't
  audit-match; see section 14.3).
- `agentrail audit` reports a single irreducible orphan: the
  amendment commit itself.

The interpreter now has a single canonical build path (`just build`
-> `scripts/build-modular.sh` -> `build/snobol4.bin`), a tracked
modular source layout (`src/sno_main` / `sno_util` / `sno_lex` /
`sno_exec.plsw`), blocked monolith filenames in `.gitignore`, and
prominent CLAUDE.md sections covering the modular rule and the
agentrail safety protocol.

## 14. Open issues and near-term fixes

Three bugs and one upstream issue were filed during or uncovered by
the April 2026 cleanup. None block the runtime-split saga itself, but
#6 and #7 block `sw-embed/sw-cor24-fortran` FTI-0 work.

### 14.1 Issue #6 -- REM . REST silently empty (array + statement-count interaction)

**Filed**: sw-embed/sw-cor24-snobol4#6 (open).

**Symptom**. In a program with multiple `ARRAY()` declarations + SPAN
variables + a `LEN/REM . REST` capture pattern, adding ANY extra
statement above the array block causes `REM . REST` to silently
return empty on every successful match. The pattern still matches
(no `:F`), but the captured remainder is lost.

**Clue**. "Count-sensitive rather than statement-specific" -- the
reporter tried multiple variants of the extra statement and all
triggered it; deleting any one init statement restored correctness.

**Likely cause**. Some buffer index or offset computed from the
statement count is off-by-one or wrapping. Candidates, ordered by
likelihood:

1. Pattern-part (PP) slot indexing in the executor. `PP_TYP` and
   `PP_VAL` are sized `STMAX * EPSLOTS`; the per-statement base is
   `S * EPSLOTS`. If a recent change changed the meaning of that
   index without updating all call sites, adding a statement shifts
   every subsequent statement's PP base.
2. Array-pool indexing. `ARR_DATA(arr_id * ARR_ELEMS + idx)` -- if
   `arr_id` is computed from something count-dependent, adding a
   statement could shuffle which array a variable resolves to.
3. String-buffer offset capture. `REM . REST` stores the captured
   span as (SB offset, length). If the SB offset is captured before
   being saved and the SB advances in between, the stored offset
   points at stale or reused storage.

**Suggested approach**.

1. Reproduce on the current `main` with the minimal `diag_bad.sno`
   from the issue body.
2. Add executor trace output around the pattern capture path to
   print the captured SB offset and length at the moment of the
   `.` binding, and again at the moment `REST` is read.
3. If those differ, you have an SB-aliasing bug -- look at `SBSAVE`
   in `sno_util.plsw` for whether it copies or just records an
   offset.
4. If they agree but `REST` still prints empty, the bug is in the
   OUTPUT concat path -- suspect overlap with issue #7.

**Related**. Issue #4 (`000381f`) fixed a related SPAN/BREAK-vs-REM
corruption. The reporter suspects #6 is a residual of the same area.

### 14.2 Issue #7 -- OUTPUT drops literal prefix when concatenated with array subscript

**Filed**: sw-embed/sw-cor24-snobol4#7 (open).

**Symptom**. `OUTPUT = 'prefix: ' A<1>` prints only `HELLO` (the
array contents). `OUTPUT = 'prefix [' A<1> '] suffix'` prints
`HELLO] suffix` -- leading literal dropped, trailing literal kept.
Workaround: `X = A<1>` then `OUTPUT = 'prefix: ' X` works correctly.

**Likely cause**. In `sno_exec.plsw`, the concat lowering path for
`'literal' <array-ref>` (`OE_STR` followed by `OE_ARRREF`) mis-emits
the first literal. The working path `'literal' <var>` (`OE_STR`
followed by `OE_IDENT`) is fine. Grep for `OE_ARRREF` in the
lowering/emit routines:

```
grep -n "OE_ARRREF\|ARR_REF\|OP_ARR_GET" src/sno_exec.plsw
```

Suspect an early-return or special-case branch in the concat-emit
loop that was added for the case where an array reference is the
only operand, and that branch fires when an array reference appears
anywhere -- even as the second operand. The fix is probably a
one-line condition.

**Suggested approach**.

1. Write a minimal `examples/test_concat_arr.sno` reproducing the
   issue.
2. Dump the emitted AM opcode stream for the
   `OUTPUT = 'prefix: ' A<1>` statement, compare to
   `OUTPUT = 'prefix: ' X` (the working workaround).
3. The divergence point is the bug.

**Related**. #6 may share an upstream cause -- both involve array
element access in the executor, both landed after issue #4. Worth
investigating together.

### 14.3 Upstream: agentrail short commit hash audit mismatch

**Filed**: sw-vibe-coding/agentrail-rs#1 (open, first issue on that
repo).

**Symptom**. `agentrail add --commit <short-hash>` accepts short
commit hashes (7 - 9 chars) without error but writes them verbatim
into `step.toml`. `agentrail audit` does strict full-SHA comparison
against git history, so those short hashes never match -- claimed
commits appear as "orphan commits" anyway.

**Fix options** (documented in upstream issue body):

1. Normalize at `add` time via `git rev-parse` -- cleanest, fail-fast.
2. Prefix-match at `audit` time -- tolerant of legacy data.
3. Both.

**Local workaround until fixed**. Always pass full 40-char SHAs when
using `agentrail add --commit`:

```bash
git log --format=%H <range>  # copy the 40-char hashes directly
```

Never use `git log --oneline` as the source of commit hashes for
`agentrail add --commit` -- the truncated output format will produce
ghost steps that silently don't audit.

**Related**. The cleanup saga in section 13.6 hit this bug on its
first retroactive reconstruction attempt (commit `db7492b`) before
being amended with full hashes in `c96a16c`. The broken first-attempt
archive `snobol4-modular-cleanup-20260411T111246` remains as a
historical artifact -- do NOT hand-edit it to match the amendment.

### 14.4 Issue #8 -- Case-preserving INPUT for case-sensitive languages

**Filed**: sw-embed/sw-cor24-snobol4#8 (closed).

**Fix**: Added `RAWINPUT` builtin that reads input without uppercasing.
New opcode `OP_READ_RAW_INPUT` (45), new proc `READ_RAW_INPUT` in
`sno_util.plsw`. Required widening the symbol table from 8 to 12 bytes
per name (`SYM_WIDTH`) since "RAWINPUT" is 8 characters. Also required
a PL/SW compiler fix (AST node pool increase) to handle the additional
WHEN branch in EXEC_IO.

### 14.5 Issue #9 -- Pattern-replacement assignment (S pattern = replacement)

**Filed**: sw-embed/sw-cor24-snobol4#9 (closed).

**Fix**: Added `ST_REPL` statement type (7) and `OP_PAT_REPLACE` opcode
(46). Parser detects `=` after pattern parts and switches to replacement
mode. Executor matches the pattern, then rebuilds the subject as
`prefix + replacement + suffix`. Works with SPAN, BREAK, LEN, REM,
literal patterns, captures, and empty replacement (deletion). Required
adding `TK_EQ` as a terminator for the pattern collection loop.

See `docs/lowercase-problems.md` for full implementation notes.

Working examples (just demos):
- hello.sno -- OUTPUT = 'Hello, World!'
- hello_goto.sno -- goto :(END) skips code
- count.sno -- variables and arithmetic
- span.sno -- SPAN('0123456789') captures digits
- span_fail.sno -- :F() failure branch
