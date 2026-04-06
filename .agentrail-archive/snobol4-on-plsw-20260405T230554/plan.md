# Plan — SNOBOL4 on PL/SW for COR24

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
6. delay completeness until the runtime skeleton is trustworthy

## 3. Milestones

## Milestone 0 — runtime substrate and diagnostics

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

## Milestone 1 — minimal execution core

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

## Milestone 2 — abstract machine boundary

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

## Milestone 3 — first pattern subsystem

### Goals

- Introduce real SNOBOL-like behavior.
- Validate explicit backtracking and rollback.

### Deliverables

1. subject cursor model
2. heap-backed backtrack stack
3. rollback log/checkpoint model
4. literal pattern matching
5. concatenation
6. alternation
7. simple capture or assignment-with-rollback behavior
8. pattern trace support

### Exit criteria

- Pattern examples succeed/fail correctly.
- Backtracking is visible in trace output.
- Rollback restores speculative state reliably.

## Milestone 4 — pattern lowering and graph form

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

## Milestone 5 — garbage collection maturity

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

## Milestone 6 — richer runtime

### Goals

- Expand usefulness without losing architectural clarity.

### Candidate deliverables

1. broader builtin set
2. user function support
3. more conversions/coercions
4. richer string operations
5. initial arrays/tables if desired
6. file/device I/O if needed for use cases

### Exit criteria

- The implementation can run nontrivial sample workloads.
- Tooling still explains runtime behavior clearly.

## Milestone 7 — self-dogfooding improvement tools

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

## 4. Work breakdown structure

## 4.1 Foundation work

1. choose descriptor physical layout
2. choose heap header layout
3. define clobber/calling conventions for low-level macros
4. define root registration model
5. define logging and assertion conventions

## 4.2 Frontend work

1. token model
2. parser skeleton
3. AST or source-structure definitions
4. normalization/lowering path

## 4.3 Runtime work

1. symbol environment
2. descriptor conversion rules
3. assignment and transfer model
4. builtin dispatch model
5. pattern subject/cursor model

## 4.4 Tooling work

1. dump format conventions
2. consistency checker conventions
3. trace category flags
4. test harness conventions

## 5. Testing strategy

## 5.1 Unit-level tests

Use focused tests for:

- descriptor construction
- heap header validation
- object scanning
- symbol updates
- rollback entries
- backtrack frame restoration

## 5.2 Scenario tests

Use end-to-end scenario tests for:

- assignment/label flow
- success/failure transfers
- basic pattern matching
- alternation and rollback
- GC under load

## 5.3 Diagnostic validation tests

Ensure that tools themselves are tested:

- descriptor dumper on every kind
- heap walker on crafted heaps
- corruption checker on intentionally malformed heaps where possible
- pattern graph dump on representative forms

## 6. Tooling priorities

Build these early and keep them current:

1. descriptor dumper
2. heap walker
3. heap consistency checker
4. pattern trace
5. statement trace
6. AM dump/disassembly

These are not optional extras; they reduce the cost of every later milestone.

## 7. Key decisions to freeze early

Freeze early to avoid churn:

1. descriptor baseline shape
2. heap header baseline shape
3. semantic stack split
4. AM category boundaries
5. trace category naming

## 8. Deferrable decisions

Safe to defer:

1. dense AM encoding
2. threaded dispatch
3. aggressive inline assembler optimization
4. full arrays/tables
5. future S/370-ish physical layout
6. later 31-bit evolution details

## 9. Risks and mitigation tasks

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

## 10. Initial recommended file set

Suggested first implementation artifacts:

1. runtime substrate file(s)
2. diagnostics file(s)
3. AM definition file(s)
4. frontend skeleton file(s)
5. minimal executor file(s)
6. milestone-specific tests/examples

## 11. Immediate next steps

1. Finalize descriptor and object header layouts.
2. Write the low-level PL/SW structural macros.
3. Build descriptor dump and heap walk tools.
4. Define the first AM categories and naming conventions.
5. Implement minimal symbol/value execution flow.
6. Add trace hooks before adding pattern complexity.
