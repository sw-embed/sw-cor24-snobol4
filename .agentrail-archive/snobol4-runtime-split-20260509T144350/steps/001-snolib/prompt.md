# Extract src/snolib.plsw -- the runtime library module

Extract a new `src/snolib.plsw` containing the runtime helpers that a
compiled SNOBOL4 program needs at runtime, but that do NOT require
the lexer, parser, AM emitter, or executor. This is step 1 of the
three-module runtime/engine/driver re-split (see
`docs/plan.md` section 13.4 and `.agentrail/plan.md`).

## Expected contents

Revise based on what's actually shared across modules:

- **Descriptor helpers** (currently macro-defined in
  `include/descr.msw` and inline-duplicated in
  `src/test_snolib.plsw`): `DESC_SET`, `DESC_SET_NULL`,
  `DESC_SET_INT`, `DESC_SET_STR`, `DESC_SET_LABEL`, `DESC_CELL_CPY`,
  `DESC_IS_NULL`, `DESC_IS_INT`, `DESC_IS_STR`, `DESC_IS_PAT`,
  `DESC_TAG_GET`, `DESC_PAY_GET`, `DESC_EQ`.
- **Heap header helpers** (currently inline-duplicated in
  `src/test_snolib2.plsw`): `HDR_SET`, `HDR_IS_FREE`, `HDR_PAYLOAD`,
  `HDR_NEXT`.
- **Heap allocator**: `HEAP_INIT`, `HEAP_ALLOC`, `HEAP_FREE`.
- **String helpers** (currently in `sno_util.plsw`): `SLEN`, `SCEQ`,
  `IN_CLASS`. These are generic byte-string helpers with no engine
  dependency.
- **Consider moving** (currently in `sno_util.plsw`): `SBPUT`,
  `SBSAVE`, `PUT_DEC`, `EMIT_DEC`. These touch the shared string
  buffer `SB` and decimal formatting. Decide whether they belong in
  the runtime library (yes if a compiled program at runtime needs
  to format integers into its own SB) or stay as engine-only helpers.

## NOT in snolib (stays in engine)

- `READ_SRC`, `READ_INPUT` (I/O bootstrap, main-program-only)
- `REFLECT_STR`, `EMIT_REFLECT_WORD` (SNOBOL4 statement handler)
- `IS_END`, `IS_DUMP`, `IS_REFLECT`, `FIND_SPECIAL` (lexer helpers)

## Dependencies

- snolib.plsw `%INCLUDE`s `include/descr.msw` and `include/heap.msw`.
- snolib.plsw must NOT include `include/snoglob.msw` (engine state)
  or `include/am.msw` (AM opcodes and bytecode).
- Declare `%DEFINE NOLISTING` so it compiles cleanly as a library
  module.

## Reference: abandoned draft

The original unfinished `src/snolib.plsw` draft is preserved at the
`fallback-pre-cleanup` git tag (commit `c6f8ac4`). Recover with:

```
git show fallback-pre-cleanup:src/snolib.plsw > /tmp/snolib-draft.plsw
```

That draft had ~40 PROCs along these lines. It was never completed
or wired into the build, but serves as a starting reference for what
the runtime extraction looked like.

## Test strategy

1. Extract the helpers into `src/snolib.plsw` as a library module.
2. Replace the inline helper definitions in `src/test_snolib.plsw`
   and `src/test_snolib2.plsw` with `%INCLUDE snolib` (or the
   equivalent). Those tests continue to pass.
3. Do NOT yet touch `sno_main.plsw`, `sno_lex.plsw`, `sno_util.plsw`,
   or `sno_exec.plsw`. Step 2 handles engine consolidation.
4. Run `just test` -- both snolib test suites must pass.
5. Run `just build` -- the main interpreter build is unchanged at
   this step (snolib isn't wired in yet).

## Exit criteria

- `src/snolib.plsw` exists as a standalone library module.
- `src/test_snolib.plsw` and `src/test_snolib2.plsw` use the shared
  snolib helpers instead of inline definitions.
- `just test` passes.
- `just build` still works (snolib isn't wired into the main build
  yet -- that's step 2/3/4).
- Step 2 (`sno-engine` consolidation) is now unblocked.

## Out of scope -- later steps handle these

- Moving lexer/parser/executor into `src/sno_engine.plsw` (step 2).
- New driver `src/snobol4.plsw` (step 3).
- Linker/build pipeline updates (step 4).
- Full demo revalidation (step 5).
