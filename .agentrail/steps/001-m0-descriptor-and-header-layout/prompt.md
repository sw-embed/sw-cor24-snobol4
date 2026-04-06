Milestone 0, Step 1: Define descriptor and heap header layouts in PL/SW.

Reference docs/design.md sections 2 and 3 for the descriptor and heap object designs.
Reference docs/architecture.md sections 7 and 4.1-4.2 for the layered architecture.

Deliverables:
1. Create src/descr.plsw (or equivalent) with:
   - 2-word descriptor layout: Word 0 (tag, subtype, flags), Word 1 (payload)
   - Tag constants for initial types: null, uninitialized, integer, string, symbol, pattern, label, builtin
   - Descriptor field access macros: DESC_TAG, DESC_SUBTYPE, DESC_FLAGS, DESC_PAYLOAD
   - Descriptor construction macros: BUILD_NULL, BUILD_INT, BUILD_STR_REF, etc.
   - Descriptor copy macro
   - Descriptor tag test macros

2. Create src/heap.plsw (or equivalent) with:
   - Uniform heap object header layout: kind, size (words), GC mark, flags
   - Object kind constants: string, symbol_cell, pattern_node, backtrack_frame, rollback_entry, code_block, free_block
   - Header field access macros: OBJ_KIND, OBJ_SIZE, OBJ_MARK, OBJ_FLAGS
   - Header construction macro

3. Create src/assert.plsw (or equivalent) with:
   - ASSERT macro (condition check with trap on failure)
   - TRACE macro (conditional trace output)
   - Trace category flags: TRACE_ALLOC, TRACE_STMT, TRACE_PATTERN, TRACE_GC

Key constraints (from docs/design.md):
- COR24: 24-bit words, 3 GPRs (r0, r1, r2), small fast stack
- Descriptors must be regular and dumpable
- Headers must support heap walking (contiguous, sized)
- Macro clobber discipline: document inputs/outputs/clobbers per macro

This is PL/SW source — use PL/SW macro syntax conventions. If unsure of exact PL/SW syntax, use clear pseudo-PL/SW with comments explaining intent; the next step will refine syntax.