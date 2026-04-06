# Milestone 3 -- First Pattern Subsystem

## Goal
Introduce SNOBOL4 pattern matching with explicit backtracking.
Target program:

    DIGITS = SPAN('0123456789')
    TEXT = 'abc 123 xyz'
    TEXT DIGITS . N :F(NO)
           OUTPUT = N :(END)
    NO     OUTPUT = 'no match'
    END

## Current state
The interpreter has an AM-based execution pipeline (parse -> lower -> AM execute).
It supports assignments, labels, gotos, OUTPUT, integer/string literals, +/-.
No pattern matching, no subject scanning, no backtracking.

## Strategy
1. Add pattern objects as heap-allocated node graphs
2. Add subject cursor model for scanning strings
3. Add backtrack stack for alternation/failure recovery
4. Implement core pattern primitives: LEN, SPAN, BREAK, literal match
5. Add . (dot) capture operator
6. Add pattern match statement (SUBJECT PATTERN . CAPTURE :F(label))
7. Extend parser, lowering, and AM executor
8. New AM opcodes for pattern operations

## Key design decisions (from docs/design.md)
- Pattern nodes on heap with kind/next/alternate/operand/flags
- Iterative execution via explicit driver loop (not recursion)
- Backtrack frames on heap-backed stack
- Rollback log for speculative side effects
- Success/failure result drives :S()/:F() gotos

## Deliverables
1. Pattern node representation and constructor
2. Subject cursor and scanning model
3. Literal pattern matching
4. SPAN primitive (character class scanning)
5. Dot capture (. operator)
6. Pattern match statement parsing and AM lowering
7. Backtrack stack and failure recovery
8. Integration: SPAN example runs correctly
