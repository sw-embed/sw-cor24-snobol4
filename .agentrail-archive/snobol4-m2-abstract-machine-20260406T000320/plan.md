# Milestone 2 — Abstract Machine Boundary

## Goal
Introduce an explicit AM-oriented internal form between the parser
and executor. Prevent the parser and executor from becoming permanently
entangled. Make execution traceable and inspectable.

## Current state
The M1 interpreter (src/snobol4.plsw) parses SNOBOL4 into a statement
table (parallel arrays) and executes directly from that table. This works
but couples parsing tightly to execution, making it hard to add pattern
matching, optimizations, or retargeting.

## Strategy
1. Define AM opcodes as integer constants
2. Add an AM code buffer (linear bytecode)
3. Build a lowering pass: statement table -> AM code
4. Build an AM executor that replaces the current direct executor
5. Add AM dump/trace tools
6. Verify all existing examples still produce identical output

## AM opcode categories (from docs/design.md)
- LOAD_INT, LOAD_STR, LOAD_VAR: push values onto eval stack
- STORE_VAR: pop eval stack into variable
- ADD, SUB: arithmetic on eval stack
- PRINT_INT, PRINT_STR: OUTPUT support
- BR, BR_SUCC, BR_FAIL: control flow
- HALT: END statement
- NOP: empty statement

## Deliverables
1. AM opcode definitions (include/am.msw)
2. AM code buffer and emitter
3. Lowering pass (statement table -> AM bytecode)
4. AM executor (fetch-decode-execute loop)
5. AM disassembler/dump tool
6. Integration: existing examples run via AM
