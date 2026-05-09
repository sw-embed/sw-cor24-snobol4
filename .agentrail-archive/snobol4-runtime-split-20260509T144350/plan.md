# SNOBOL4 runtime/engine split

Re-modularize the SNOBOL4 interpreter so the runtime helpers (descriptor
+ heap + basic primitives) live in their own module that can be linked
into compiled SNOBOL4 programs without dragging in the lexer, parser,
and executor. Continues the modular-build work and prepares the ground
for standalone compiled .sno -> .bin output.

## Starting point

The current modular interpreter is split by *function*:

```
src/sno_main.plsw   -- driver: MAIN
src/sno_util.plsw   -- I/O helpers
src/sno_lex.plsw    -- lexer + parser + AM emit
src/sno_exec.plsw   -- lowering + executor + pattern matching + builtins
```

Built by `scripts/build-modular.sh` into `build/snobol4.bin`. This is
the v0-modular-stable baseline (git tag).

## Target shape

Re-split along a *runtime vs compiler engine vs driver* axis:

```
src/snolib.plsw     -- runtime library: descriptors, heap, helpers
                       (linkable into compiled SNOBOL4 programs without
                       the engine)
src/sno_engine.plsw -- compiler + executor library: lexer, parser,
                       AM emit, lowering, executor, pattern matching
src/snobol4.plsw    -- driver: MAIN, wires snolib + sno_engine
```

The names match dormant unfinished drafts preserved in the
`fallback-pre-cleanup` git tag. Those drafts may be cherry-picked as a
starting reference, or the saga may start fresh.

## Steps

1. **snolib** -- Extract runtime library from `sno_util.plsw` and the
   runtime helpers in `sno_exec.plsw`. Validate via the existing
   `test_snolib` and `test_snolib2` suites. Compiles cleanly as a
   standalone library.

2. **sno-engine** -- Consolidate `sno_lex.plsw` and the executor portion
   of `sno_exec.plsw` into a single linkable engine module that
   compiles cleanly stripped of the runtime library (from step 1).

3. **snobol4-main** -- New top-level `src/snobol4.plsw` driver that
   wires `snolib` + `sno_engine`. Replaces `src/sno_main.plsw`.

4. **linker** -- Update `scripts/build-modular.sh` (or successor) for
   the new three-module layout. Verify the strip step. Update
   `justfile` if needed; `just build` and `just rebuild` must still
   work without callsite changes.

5. **validate** -- Run the full demo and tutorial suite (fizzbuzz,
   sieve, nqueens, eliza, palindrome, fibonacci, factorial, gcd,
   reverse, plus tutorials) against the new layout. Run `just test`.
   `agentrail audit` reports zero gaps.

## Exit criteria

- All existing tests and demos pass against the re-split layout.
- `scripts/build-modular.sh` produces a working interpreter from the
  new three-module layout.
- The runtime library `snolib.plsw` compiles cleanly as a standalone
  library that could be linked into a compiled .sno -> .bin output.
- The old four-file layout (`sno_main`, `sno_util`, `sno_lex`,
  `sno_exec`) is removed in favor of the new three-file layout.
- `.gitignore` is updated: `src/snobol4.plsw`, `src/sno_engine.plsw`,
  `src/snolib.plsw` are unblocked (they are now the canonical sources).
  `src/sno_main.plsw`, `src/sno_lex.plsw`, `src/sno_exec.plsw`,
  `src/sno_util.plsw` may be added to `.gitignore` if a fallback tag
  preserves them.
