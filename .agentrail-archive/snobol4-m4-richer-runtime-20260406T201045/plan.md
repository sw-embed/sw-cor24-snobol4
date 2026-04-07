# Milestone 4 -- Richer Runtime

## Goal
Expand the interpreter to support real SNOBOL4 programs, targeting
the dating app demo (M5) as the exit test.

## Current state
The interpreter has: lexer, parser, AM lowering, AM executor,
SPAN pattern, capture, labels, gotos, OUTPUT, variables, +/-.
Missing: arrays, tables, user functions, builtins, INPUT, BREAK,
string concat, multiplication, continuation lines.

## Deliverables
1. String concatenation in expressions
2. Multiplication operator
3. BREAK pattern primitive
4. REM pattern primitive
5. INPUT variable (read lines, EOF)
6. ARRAY() and <> indexed access
7. User functions: DEFINE, RETURN, FRETURN
8. Builtin functions: IDENT, DIFFER, GT, EQ, LE
9. Continuation lines (+ in column 1)
10. Integration: dating app subset runs
