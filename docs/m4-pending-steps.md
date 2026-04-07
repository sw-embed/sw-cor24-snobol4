# M4 Pending Steps (carried over from broken saga)

The previous M4 saga had duplicate step numbers (two #7, two #8) created
when v2 versions of legacy steps were added after the modular build landed.
The pending work, deduplicated, is **4 steps**:

## 1. m4-functions — DEFINE, RETURN, FRETURN
User-defined functions in the modular interpreter:
- `DEFINE('NAME(ARG1,ARG2)LOCAL1,LOCAL2')` registers a function.
- `:(RETURN)` returns success with the value of the function name var.
- `:(FRETURN)` returns failure.
- Local variables save/restore on call/return.
- Recursion supported (call stack frame).

(Original legacy step: 005-m4-functions, redone as 008-m4-functions2.)

## 2. m4-builtins — IDENT, DIFFER, GT, EQ, LE
Predicate builtin functions used for control flow via :S/:F gotos:
- `IDENT(A,B)` succeeds when strings are identical.
- `DIFFER(A,B)` succeeds when different.
- `GT(A,B)`, `EQ(A,B)`, `LE(A,B)` numeric comparisons.
- All return null on success, fail otherwise (SNOBOL4 convention).

(Original: 006-m4-builtins, redone as 009-m4-builtins2.)

## 3. m4-continuation — Continuation lines
Source lines beginning with `+` (or `.`) in column 1 continue the
previous statement. Lexer/parser change: when reading a new line,
peek the first column; if `+`, treat as continuation of prior tokens
rather than a new statement.

(Two pending duplicates: 007-m4-continuation and 010-m4-continuation2.)

## 4. m4-integrate — Dating app subset runs
End-to-end test: a subset of the student dating app
(`docs/student-dating-app.txt`) runs to completion on the modular
interpreter. Exercises INPUT, arrays, BREAK patterns, functions,
builtins, and continuation lines together.

(Original: 008-m4-integrate, redone as 011-m4-integrate2.)
