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

## 12. Current state

Completed: M0, M1, M2, M3
Next: M4 (richer runtime)
Target demo: M5 (dating app)

Working examples (just demos):
- hello.sno -- OUTPUT = 'Hello, World!'
- hello_goto.sno -- goto :(END) skips code
- count.sno -- variables and arithmetic
- span.sno -- SPAN('0123456789') captures digits
- span_fail.sno -- :F() failure branch
