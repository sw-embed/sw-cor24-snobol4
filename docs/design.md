# Design — SNOBOL4 on PL/SW for COR24

## 1. Detailed design overview

This document refines the architecture into concrete choices for:

- descriptors
- heap layout
- stack organization
- macro layers
- AM categories
- parser/lowering boundary
- pattern execution
- diagnostics

The overall design preference is:

- simple regular structures
- explicit heaps and frames
- low dependence on machine recursion
- layered macros rather than ad hoc code duplication

## 2. Descriptor design

## 2.1 Descriptor shape

On COR24, use a **2-word descriptor** as the baseline representation.

### Word 0

Contains compact metadata:

- primary tag
- subtype
- flags
- optional small mode bits

### Word 1

Contains payload:

- pointer
- integer value
- offset
- builtin id
- label id
- small immediate

## 2.2 Descriptor goals

The descriptor design should optimize for:

1. regular dumping
2. simple copying
3. simple tag testing
4. portability across 24-bit targets
5. future adaptation to different word/register environments

## 2.3 Immediate vs heap-backed values

### Immediate-like descriptors

Examples:

- null
- uninitialized
- small integer
- builtin id
- code label reference

### Heap-backed descriptors

Examples:

- string
- pattern object
- symbol cell
- function object
- array or table later
- file/channel object later

## 3. Heap object design

## 3.1 Uniform object header

Every heap object begins with a uniform header.

Suggested fields:

- object kind
- total size in words
- GC mark bit(s)
- subtype or flags
- optional debug/check field

The exact bit layout is target-specific and belongs to the low-level runtime layer.

## 3.2 Object kinds

Initial kinds likely include:

- string object
- symbol cell object
- pattern node object
- pattern graph object
- backtrack frame block
- rollback log block
- code/AM form object
- free block header

## 3.3 Heap invariants

1. Every object kind has a known scanner.
2. Every object kind has a known dumper.
3. Object headers are never skipped by heap walking logic.
4. Free blocks are explicitly typed.
5. Validation tools can distinguish live blocks from structural corruption.

## 4. Stack and frame design

## 4.1 Machine stack

The fast stack is reserved for:

- PL/SW call frames
- linkage
- tiny scratch state
- a few fixed local temporaries

Avoid storing bulk language state here.

## 4.2 Heap-backed semantic stacks

### Evaluation stack

Purpose:

- temporary intermediate descriptors
- expression results when needed

### Backtrack stack

Purpose:

- pattern continuation state
- subject cursor checkpoints
- next node/program counter
- rollback checkpoint ids
- environment snapshot handles if needed

### Rollback stack/log

Purpose:

- speculative variable bindings
- captures
- assignment-like pattern side effects
- state restoration markers

## 4.3 Frame organization

All semantic frames should have explicit headers.

Example backtrack frame contents:

- frame kind
- previous frame pointer/index
- current subject cursor
- next pattern node or pc
- rollback checkpoint
- optional environment reference

## 5. Register and calling convention strategy

## 5.1 Assumption

Assume constant register scarcity.

Suggested working discipline:

- r0: primary scratch/result
- r1: secondary scratch/pointer
- r2: tertiary scratch/frame pointer helper

This is a discipline, not necessarily a hard ABI, but it should be reflected in macro documentation.

## 5.2 Macro clobber discipline

Each low-level or AM macro should conceptually document:

- inputs
- outputs
- clobbered registers
- whether it may call allocator/GC
- whether it may trap

Without this, recursive layered macros will become unmanageable.

## 6. Macro layer design

## 6.1 Layer A — structural macros

These encapsulate routine structure and data layout.

Examples:

- descriptor field access
- object header access
- frame prologue/epilogue
- assertions
- logging helpers

## 6.2 Layer B — abstract machine macros

These expose AM operations in a portable semantic form.

Examples:

- build/load/store/test descriptor
- allocate object
- push/pop frame
- branch on success/failure
- cursor movement helpers
- builtin call wrappers

## 6.3 Layer C — semantic macros

These express recurring language semantics in reusable form.

Examples:

- evaluate as string
- coerce integer or fail
- enter statement with succ/fail continuations
- speculative bind with rollback logging
- pattern-node execution skeletons

These are the most likely place for recursive macro composition.

## 7. Abstract machine design

## 7.1 AM form

The AM should exist in at least one inspectable intermediate form.

Early form may be symbolic and verbose.
Later form may become denser.

## 7.2 AM operation categories

### Descriptor operations

- build descriptor
- copy descriptor
- load/store fields
- compare tags/subtypes

### Control operations

- unconditional branch
- branch success
- branch failure
- call/return
- computed dispatch later if useful

### Heap/object operations

- allocate object
- test object kind
- load payload field
- store payload field

### String operations

- create string
- compare literal segment
- advance cursor
- copy substring
- class test later

### Pattern operations

- push continuation
- pop continuation
- branch on literal match
- alternate path scheduling
- commit success
- force failure
- capture/log rollback action

### Builtin/runtime operations

- builtin dispatch
- conversion/coercion helpers
- trace emit
- assert/trap

## 8. Frontend and lowering design

## 8.1 Frontend phases

1. lexical scan
2. parse into source-oriented nodes
3. semantic normalization
4. lower into AM-oriented code structures

## 8.2 Why lowering matters

The lowering boundary keeps:

- parser concerns separate from runtime concerns
- later optimization possible
- diagnostics richer
- eventual retargeting easier

## 9. Pattern subsystem design

## 9.1 Recommended first internal representation

Start with explicit pattern node objects that are easy to dump.

A node may contain:

- node kind
- next pointer
- alternate pointer
- literal or small operand reference
- flags

## 9.2 Execution style

Execute patterns with an explicit driver loop, not deep machine recursion.

Pseudo-flow:

1. inspect current node
2. test subject state
3. on success, move to next node
4. on alternation or speculative state, push backtrack frame
5. on failure, pop backtrack frame and restore state
6. on terminal success, commit
7. on exhaustion, fail

## 9.3 Rollback design

Any speculative side effect must record an undo entry before modification.

Undo entry examples:

- symbol previous descriptor
- capture buffer previous state
- environment previous binding reference

Rollback checkpoints are referenced from backtrack frames.

## 10. Garbage collection design

## 10.1 Collector choice

Initial implementation: mark-sweep.

## 10.2 Collector interfaces

Needed interfaces:

- register root set providers
- scan object by kind
- walk semantic stacks
- validate free list and block boundaries
- optional collector trace output

## 10.3 Important invariant

Backtrack and rollback structures are roots or root-reachable state until proven dead.

## 11. Diagnostic tool design

## 11.1 Descriptor dump

Should show:

- address if relevant
- tag
- subtype
- payload raw
- interpreted summary

## 11.2 Heap walker

Should show:

- block address
- block kind
- size
- mark/free state
- forward references summary
- corruption warnings

## 11.3 Pattern graph dump

Should show:

- node id/address
- node kind
- next/alternate links
- literal or operand data
- flags

## 11.4 Trace model

Trace categories should be independently controllable:

- statement trace
- expression trace
- pattern step trace
- backtrack trace
- GC trace
- allocator trace

## 12. Inline assembler design rules

Use inline COR24 assembler only when one of the following is true:

1. the operation is purely mechanical
2. the operation is hot and proven expensive in PL/SW form
3. the operation needs machine-specific control not naturally expressible in PL/SW

Examples:

- small descriptor copy
- compare/copy loops
- specialized dispatch helper
- assert/trap helper

Avoid semantic assembler islands.

## 13. Planned source decomposition

Suggested source families:

- AM definitions and macros
- runtime core
- pattern subsystem
- GC subsystem
- frontend
- diagnostics
- driver/main

This decomposition is logical; exact file/repo layout can follow existing PL/SW conventions.
