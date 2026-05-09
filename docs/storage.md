# SNOBOL4 storage runtime

This document is the authoritative description of how SNOBOL4 manages
dynamic memory on top of the PL/SW substrate. Read alongside
`/disk1/.../work/dcpls/.../sw-cor24-plsw/docs/storage-allocation.md`
(the PL/SW-side contract for `?GETMAIN` / `?FREEMAIN` /
`_PLSW_GETMAIN` / `_PLSW_FREEMAIN`).

PL/SW provides only the raw alloc / free primitives. **Region
boundaries, mark / reclaim, and garbage collection live in this
runtime.**

## 1. Audit: what allocates today

This is the starting point. The SNOBOL4 interpreter
(`sno_main` + `sno_util` + `sno_lex` + `sno_exec`) does **not**
use any dynamic heap today. Everything is statically declared in
`include/snoglob.msw`. The only runtime memory management is the
SB string-buffer compactor described in §1.3.

### 1.1 Static buffers (75 DCLs in `snoglob.msw`)

Sized at compile time and never resized:

| Buffer            | Size     | Purpose                                  |
|-------------------|----------|------------------------------------------|
| `SRC`             | 12 KB    | Source code, loaded by `READ_SRC`        |
| `SB`              | 64 KB    | String buffer for runtime concat / input |
| `AM_CODE`         | 4 KB     | Compiled bytecode                        |
| `SYMN` / `SYMV`   | 768+256B | Symbol name + value tables (`SYMMAX=64`) |
| `LBLN` / `LBLS`   | 768+256B | Label name + statement tables (`LBL_MAX=64`) |
| `S_*` (statement) | per-stmt | `S_TYP/S_SUBJ/S_GTYP/...` etc., `STMAX=256` |
| `EP_TYP/EP_VAL`   | 2x6 KB   | Expression-part slots (`STMAX*EPSLOTS=2048`) |
| `PP_TYP/PP_VAL`   | 2x6 KB   | Pattern-part slots                       |
| `ARR_DATA/ARR_TYP`| 2x1.2 KB | Array element pool (`ARR_POOL=400`)      |
| `ESTK / ETYP`     | 2x768 B  | Eval stack (`ESTK_DEPTH=256`)            |
| `PSTK / PSTYP`    | 2x48 B   | Pattern stack (16-deep, static)          |
| `CSTK_*`          | 3x48 B   | Call stack for user-defined functions    |
| `FN_*`            | 4 ints   | Function table (max 4 user fns)          |

Programs that exceed any `*MAX` cap fail with a compile-time error
(see `examples/test_limits.sno`).

### 1.2 Ad-hoc heap allocators (test files only)

`test_alloc.plsw`, `test_pat.plsw`, `test_walk.plsw`, `test_pmatch.plsw`
each ship inline copies of `HEAP_INIT` / `HEAP_ALLOC` / `HEAP_FREE`
backed by a fixed-size `ARENA(N) BYTE` array. These are **test**
fixtures; the interpreter proper does not call them. After the
runtime/engine split saga lands `snolib.plsw` already canonicalises
the implementation (step 1, 2026-05-08), but only the snolib tests
exercise it -- production code paths still hold static buffers.

### 1.3 SB compactor (existing string GC, `sno_exec.plsw` + `snoglob.msw`)

This is already a form of mark / copy GC, just over a single
contiguous arena instead of a free-list heap:

- `SB_COMPILE_END` is a watermark set at the start of `AM_EXEC`.
  Strings below are compile-time-stable (referenced by bytecode);
  strings at-or-above are runtime-allocated and may be relocated.
- When `SBPOS` reaches `SB_SOFT_LIMIT` (61 KB / 64 KB), `SB_COMPACT`
  walks the live root set (variable values that are string offsets,
  pattern captures, eval-stack entries) and rewrites every live
  string into a fresh contiguous region above `SB_COMPILE_END`.
- `SB_FWD_OLD` / `SB_FWD_NEW` (128-entry forwarding tables)
  remember the old-offset → new-offset mapping for the duration of
  one compaction cycle so duplicate references resolve consistently.
- If the live set exceeds 128 distinct strings, compaction is
  skipped and the program halts cleanly via `SB_OVERFLOW` (issue
  #12).

The model is: roots → forward → rewrite. That's the same model a
generational copying GC uses; we just have one generation.

## 2. Design choice: region-stack over `?GETMAIN`

Of the two designs the brief lays out, this runtime picks **Design B
(region-stack over `?GETMAIN`/`?FREEMAIN`)** as the default policy
for new dynamic allocations, with the existing SB compactor staying
where it is. The reasoning:

### 2.1 SNOBOL4's allocation profile naturally maps to regions

The brief's design questions, answered concretely:

- **Dominant allocation size?** Tiny: pattern nodes (~12 B),
  capture descriptors (~6 B), backtrack frames (~12 B). Strings
  go through SB; they don't hit the heap.
- **Rooted set during pattern matching?** The eval stack
  (`ESTK`/`ETYP`, currently 256 deep), the pattern stack
  (`PSTK`/`PSTYP`, currently 16 deep), variable values
  (`VARS(SYMMAX)`), and active capture targets. Enumerable but
  shifts on every backtrack -- not pleasant for a precise GC.
- **Natural scope boundaries?** Yes, several:
  - **Pattern-match attempt**: every `SUBJ pattern...` statement
    starts and ends with the eval stack at a known depth. Anything
    allocated during the attempt and not promoted into a captured
    variable is dead at statement exit.
  - **Statement boundary**: temporaries built for `OUTPUT = expr`
    are dead after the statement.
  - **User-function call**: each `CALL FN(arg)` pushes a frame on
    `CSTK_*`; on `:(RETURN)` / `:(FRETURN)` the frame is gone.
- **Worst-case live set?** Hard to say without `compiler.sno` to
  profile against. Today's largest demos peak under 1 KB of
  bytecode + a few KB of strings. Default `PLSW_HEAP_SIZE` of
  64 KB gives plenty of headroom.

A region-stack matches this exactly: push a region when entering
a scope, pop (= free everything since the watermark) on exit. No
mark phase, no traversal, no precise root set required. The cost
is that values escaping a region need explicit promotion -- but
that's the same cost SB's `SB_COMPILE_END` watermark already pays,
just over byte strings instead of objects.

### 2.2 Full mark-and-reclaim is deferred until profiled need

Design A (one big region, mark / sweep over the whole thing) is
more general but pays for what we don't use yet: every pattern node
gets a mark bit, every match attempt walks the heap on collection,
the root set has to be precise across the eval stack and pattern
stack. Worth doing if SNOBOL4 ends up holding a lot of long-lived
graph-shaped state (think: `compiler.sno` building an AST that
outlives any single statement). It is **not** the right first
pass because:

- We have no concrete workload that demands it.
- SB compaction already handles the major source of dynamic
  storage churn (strings).
- A region-stack covers everything our current demos need; promoting
  to GC later is a bounded refactor, not a redesign.

If profiling under `compiler.sno` shows region-stack is leaking
(values consistently escape into long-lived regions and the base
region grows unboundedly), that's the trigger for a Design A saga.

### 2.3 Hybrid: SB compactor stays, region-stack is new

The two layers don't conflict and won't be merged:

- **SB** continues to own all byte strings (concat results, INPUT,
  pattern captures). The compact-copy GC there has been hardened
  through issues #11, #12, #14 -- ripping it out to put strings
  on the heap would lose work.
- **Region-stack** owns all *non-string* dynamic allocations
  starting with pattern nodes and backtrack frames as those move
  off static buffers.
- The two roots (SB's watermark + the region stack) are walked
  independently. SB compaction never visits region-stack memory;
  region-stack frees never touch SB.

## 3. Runtime interface (proposed)

These procedures live in a new `src/snort.plsw` ("SNOBOL4 runtime")
module after the runtime/engine split saga finishes step 2. Until
then, the interface is documented here and stubbed in
`src/snolib.plsw` so consumers can compile against it.

```pl/i
/* One-time setup at AM_EXEC start. Carves out one big PL/SW
 * region; subsequent regions are sub-allocated within it. */
SNO_RT_INIT: PROC;
    /* uses ?GETMAIN to grab PLSW_HEAP_SIZE bytes;
     * sets up the base region as the bottom of the stack */
END;

/* Push a new region. Returns a handle (typically a pointer to
 * the saved watermark) the caller passes to SNO_RT_REGION_POP. */
SNO_RT_REGION_PUSH: PROC RETURNS(PTR);

/* Pop the region pushed by the matching SNO_RT_REGION_PUSH.
 * All allocations made since the push are dead. Handle parameter
 * is for assert-pairing -- a mismatched push/pop is a bug. */
SNO_RT_REGION_POP: PROC(HANDLE PTR);

/* Allocate SIZE bytes from the topmost region. Returns 0 on OOM
 * (region full -- caller should bubble failure up to the
 * statement, matching SB_OVERFLOW's halt-cleanly model). */
SNO_RT_ALLOC: PROC(SIZE INT) RETURNS(PTR);

/* Promote a value out of the topmost region into the
 * second-topmost. Used for capture-target writes during a match
 * attempt: the captured string lives longer than the attempt. */
SNO_RT_PROMOTE: PROC(SRC PTR, SIZE INT) RETURNS(PTR);
```

Compatible with PL/SW's contract: the SNOBOL4 runtime calls
`?GETMAIN SET(BASE) LENGTH(N) RC(rc);` once at `SNO_RT_INIT`
and `?FREEMAIN ADDR(BASE) LENGTH(N) RC(rc);` once at program
exit. Per-cell `_PLSW_GETMAIN` / `_PLSW_FREEMAIN` calls do not
happen inside SNO_RT_ALLOC.

## 4. Migration plan

In order, smallest first:

1. **Pattern nodes** -- currently nonexistent in the runtime
   (the pattern stack `PSTK`/`PSTYP` is static, 16 deep; the
   match engine inlines structure). The first concrete workload
   that exceeds 16 stack entries (deep backtracking patterns)
   triggers this; that workload then allocates pattern nodes
   from the topmost region and promotes captured fragments.
2. **Backtrack frames** -- as the pattern engine grows alternation
   (`|`) and `*PATTERN` recursion (out-of-scope today; tracked in
   `docs/language-reference.md` "currently not supported"), the
   per-frame state lives on the region stack.
3. **Bytecode buffers for nested compilation** -- when
   `compiler.sno` arrives it needs to emit bytecode for the
   programs it compiles, which doesn't fit `AM_CODE`'s 4 KB. A
   compile region is a natural per-compilation-unit allocation.
4. **Eventually**: array storage (`ARR_DATA`/`ARR_TYP`), call
   stack (`CSTK_*`), function table (`FN_*`) -- but these are
   bounded by `ARR_MAX`/`STMAX` and don't urgently need to move.

Static buffers stay where they are until a concrete workload
exceeds their cap. The first cap that breaks is the trigger;
allocation moves to the region stack at that site, not preemptively.

## 5. Open questions

- **Region nesting depth**: the brief doesn't bound it. SNOBOL4's
  pattern matching can nest an arbitrary number of attempts in
  principle (e.g. recursion via `*PATTERN`). A 16-deep cap
  (matching `PSTK`) is a starting point; bumping is cheap once the
  saga commits to a region-stack model.
- **Promotion semantics for captures**: when `pattern . VAR` fires,
  the captured string copy lives in the variable forever. Do we
  copy into the parent region eagerly, or rely on SB to keep the
  string alive (SB never relocates already-rooted offsets)? The
  audit confirms SB already handles this -- captures store SB
  offsets, not heap addresses, so promotion is implicit. New
  non-string capture types (none today) would need explicit
  promotion.
- **Failure mode on heap exhaustion**: matches SB's existing model
  (set a halt flag + diagnostic, let `AM_EXEC`'s loop notice).
  The brief recommends this; we adopt it.

## 6. Status

This document is the design (Scope A from the brief). Implementation
of the runtime interface (Scope B) is a follow-up saga
(`pr/storage-allocation-runtime-impl` or similar) sequenced after:

- `pr/storage-allocation-runtime` (this saga) lands the design.
- The runtime/engine split saga finishes step 2 (so the runtime
  has a stable home in `snolib.plsw` or its successor).
- A workload appears that actually requires it (the brief's
  "compiler.sno or pattern-heavy demos that need deeper
  backtracking").

Speculative implementation without a workload to drive it is
explicitly out of scope -- design errors caught in code reviews
of the doc are cheaper than design errors caught in shipped
runtime code.

## See also

- PL/SW substrate:
  `work/dcpls/github/sw-embed/sw-cor24-plsw/docs/storage-allocation.md`
- Saga brief: `tools/briefs/dcsno-storage-allocation-runtime.md`
- Existing SB compactor implementation: `src/sno_exec.plsw` search
  for `SB_COMPACT`, `SB_FWD_*`, `SB_COMPILE_END`.
