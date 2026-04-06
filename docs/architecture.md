# Architecture — SNOBOL4 on PL/SW for COR24

## 1. Architectural summary

The system is a **layered implementation of a SNOBOL4-style dynamic language runtime** in **PL/SW**, targeting **COR24 first**.

The core idea is to create a **SIL-inspired abstract machine** in PL/SW and implement the language as:

**SNOBOL source → parsed form → abstract machine form → executor/runtime**

Machine-specific concerns are pushed downward into PL/SW low-level facilities and, when necessary, inline COR24 assembler.

## 2. Design drivers

The architecture is driven by the following constraints:

1. **PL/SW only** for core implementation.
2. **Recursive macro layers** are desired and should be central.
3. **COR24 has only three GPRs**, so register pressure must be assumed everywhere.
4. **Fast stack is small**, so semantic stacks must be heap-backed.
5. **Heap is relatively roomy** at ~1M, enabling descriptor-heavy and frame-heavy designs.
6. **S/370-ish retargeting comes later**, so semantic layout and machine layout must be separated early.

## 3. Architectural principles

## 3.1 Abstract machine first

The key design object is the **SNOBOL abstract machine (AM)**.

The AM should define semantic operations such as:

- descriptor access
- type tests
- object construction
- success/failure branching
- backtrack frame manipulation
- string cursor manipulation
- pattern execution support
- builtin dispatch

This AM is the semantic portability boundary.

## 3.2 Semantic stacks are not machine stacks

Because the fast stack is small, the architecture uses separate heap-backed logical stacks for dynamic language state.

## 3.3 Keep semantics in PL/SW, mechanics in assembler

Inline assembler should implement only machine-level mechanics, such as:

- small copies
- tight scans
- dispatch helpers
- trap/assert helpers

Language semantics should remain visible in PL/SW and macro-expanded PL/SW.

## 3.4 Make runtime state inspectable

The implementation should optimize for visibility first:

- uniform headers
- regular descriptors
- explicit frame shapes
- centralized root enumeration
- first-class dump and validation tools

## 4. Layered architecture

## 4.1 Layer 0 — COR24 machine substrate

Responsibilities:

- register conventions
- call linkage
- stack linkage
- heap primitive hooks
- memory movement primitives
- trap/debug hooks
- inline assembler helpers

Outputs upward:

- low-level callable primitives
- macro-safe machine conventions

## 4.2 Layer 1 — PL/SW low-level runtime substrate

Responsibilities:

- word and descriptor access helpers
- pointer and offset helpers
- block header access
- frame helpers
- allocator interfaces
- assertion and logging hooks

This layer should be reusable for other runtime-heavy PL/SW systems.

## 4.3 Layer 2 — SNOBOL abstract machine

Responsibilities:

- define the AM instruction families
- define semantic helper macros over those ops
- isolate target-specific descriptor and object layout knowledge
- standardize tracing hooks

Examples of AM concepts:

- `LOAD_DESC`
- `STORE_DESC`
- `TEST_TAG`
- `BUILD_INT`
- `BUILD_STR`
- `BR_SUCC`
- `BR_FAIL`
- `PUSH_BT`
- `POP_BT`
- `CALL_BUILTIN`

## 4.4 Layer 3 — SNOBOL runtime executor

Responsibilities:

- statement execution
- expression evaluation
- symbol handling
- coercion
- pattern engine control
- rollback handling
- builtin dispatch
- GC root reporting

## 4.5 Layer 4 — Tools and diagnostics

Responsibilities:

- descriptor dumping
- heap walking
- consistency checking
- stack dumping
- pattern graph dumping
- AM disassembly
- traces and profiling counters

## 5. Execution pipeline

## 5.1 Frontend path

1. Read source.
2. Lex source into tokens.
3. Parse source into a parse tree or equivalent structured form.
4. Lower expressions and statements into an **AM-oriented internal form**.
5. Store generated forms and literal tables in heap objects or code structures.

## 5.2 Runtime path

1. Initialize global runtime state.
2. Initialize symbol tables and root structures.
3. Execute AM-oriented forms.
4. Use heap-backed semantic stacks for dynamic runtime state.
5. Invoke diagnostics conditionally.

## 6. Runtime memory model

## 6.1 Broad categories

The memory model consists of:

1. machine stack
2. heap
3. global tables
4. code / AM forms
5. diagnostic structures

## 6.2 Heap usage

The heap contains:

- strings
- pattern nodes or pattern programs
- symbol/value cells
- arrays/tables later
- heap-backed semantic stacks
- trace structures
- temporary runtime objects

## 6.3 Semantic stack split

The architecture defines separate logical stacks:

1. **evaluation stack**
2. **backtrack stack**
3. **rollback log / binding stack**

These are independent from the machine stack.

## 7. Object model

## 7.1 Descriptor-centric model

Every language-visible value is represented by a **descriptor**, with physical layout hidden below the AM layer.

On COR24, the default expectation is a **2-word descriptor**.

## 7.2 Heap object model

Heap objects use a uniform header plus payload.

This regularity supports:

- GC
- dump tools
- type-directed scanning
- validation

## 8. Pattern subsystem architecture

The pattern subsystem is a first-class subsystem, not a side feature.

## 8.1 Suggested representation

Phase 1 may use direct structured nodes.

Phase 2 should lower patterns into a **pattern graph** or equivalent inspectable representation.

Nodes represent operations such as:

- literal match
- concatenation
- alternation
- repetition later
- capture
- terminal success/failure

## 8.2 Pattern execution

Pattern execution uses:

- a subject cursor
- an explicit continuation/backtrack model
- rollback logging for speculative side effects

The implementation should prefer **iterative execution over machine-recursive execution**.

## 9. Garbage collection architecture

## 9.1 Initial strategy

Start with a debuggable collector, likely **mark-sweep**.

Reasons:

- straightforward to reason about
- easy to debug with heap walkers
- easier than moving/compacting collectors when descriptor rewrites are still evolving

## 9.2 Root model

Roots include:

- globals
- symbol tables
- current executor frames
- evaluation/backtrack/rollback stacks
- any active runtime temporaries registered with the collector

## 10. Portability architecture

The architecture anticipates a future 24-bit S/370-ish target by enforcing these boundaries now:

1. semantic descriptor meaning separated from physical descriptor layout
2. centralized character tables
3. no unconstrained pointer/integer alias assumptions
4. semantic stacks distinct from machine call stack
5. type-specific heap scanning logic explicit and centralized

## 11. Diagnostics architecture

Diagnostics are built in as architectural features.

Core diagnostic views:

- descriptor views
- heap views
- object graph views
- stack views
- symbol views
- pattern views
- execution trace views

This is not optional debugging sugar; it is a core implementation aid.

## 12. Future evolution

The architecture should permit later additions such as:

- denser AM encoding
- threaded dispatch
- compiled hot paths
- more complete pattern forms
- richer I/O
- S/370-ish low-level adapters
- later 31-bit evolution without semantic redesign
