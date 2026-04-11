# SNOBOL4 demo expansion and stability

Add demo content that exercises real interpreter usage and fix correctness
issues that surfaced along the way.

## Steps
1. demos             — Demo backlog doc + first two demo batches (palindrome, fibonacci, factorial, define/io tutorials, quickstart)
2. bugfixes          — Issues #1-#3 (SIZE/SUBSTR/CHAR builtins + silent memory corruption) and issue #4 (SPAN/BREAK pattern variables corrupt REM matching with arrays)
3. executor-refactor — SELECT/WHEN dispatch and grouped handler procedures in the executor
