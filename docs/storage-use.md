# SNOBOL4 storage use -- what's actually in those 128 KB

This is the audit companion to `docs/storage.md`. That doc is about
the **future** runtime (region-stack over `?GETMAIN`); this one is
about the **current** static-buffers-in-`snoglob.msw` reality:
where each kilobyte goes, how it's managed today, and why naive
`.bin` size is paying for it twice.

Companion briefs (filed 2026-05-09, dcsno-drafted):
- `tools/briefs/dcxas-zero-fill-directive.md` -- adds `.zero N` to
  `cor24-asm` so `.s` text doesn't enumerate every zero byte.
- `tools/briefs/dcpls-emit-zero-fill.md` -- teaches PL/SW codegen
  to use the new directive for `INIT(0)` static arrays.

## 1. The three places zeros live

| Layer | Size today | What it is | Who reads it |
|---|---:|---|---|
| `.s` text (per-module) | ~261 KB for `sno_main.s` | `.byte 0,0,0, ... ` enumeration of every zero byte in static arrays | `cor24-asm` (assembler input) |
| `.bin` / `.lgo` | ~128 KB (zeros) + ~40 KB (code) | Actual loadable image: code + literal zero bytes baked into the image | `cor24-emu` (loader) |
| RAM at runtime | ~128 KB | `_SB`, `_SRC`, etc. at fixed virtual addresses, populated from the image at load time | The interpreter |

The text-to-binary cost is **2 source chars per byte**: `.byte 0,0,0` puts
2 chars (`0,`) on the wire per byte of output. So the `.bin`/`.lgo`
zero region is roughly half the size of the `.s` text representing
it. The 128 KB of RAM zero is real working memory; the 261 KB of
`.s` text is a wasteful encoding of those same 128 KB of zero.

The proposed `.zero N` directive shrinks the `.s` text only --
the `.bin`, the `.lgo`, and the runtime image are byte-identical
afterward. **The interpreter needs the zeros at runtime; what the
brief fixes is the source-text encoding cost, not the runtime
cost.**

## 2. What's in the 128 KB (per-buffer accounting)

All declared in `include/snoglob.msw`. Sizes computed from current
`SB_SIZE=65536`, `STMAX=256`, `EPMAX=2048`, `SYMMAX=64`, etc.

### 2.1 The big four (~110 KB out of 128 KB)

| Buffer | Size | Purpose | Management |
|---|---:|---|---|
| `_SB` | 65,536 | Runtime string heap. Every concat result, every `INPUT` line read, every pattern capture, every decimal conversion of an integer, every `REFLECT` output appends here. | **Mark-copy GC.** Watermark `SBPOS` advances on append. At `SB_SOFT_LIMIT` (61 KB) `SB_COMPACT` walks live string offsets in `VARS` / eval stack / pattern captures, copies live strings into a fresh region above `SB_COMPILE_END`, rewrites references via `SB_FWD_OLD`/`SB_FWD_NEW`. (Issues #11, #12, #14.) |
| `EP_TYP/EP_VAL` `PP_TYP/PP_VAL` | 24,576 | Per-statement expression slots and pattern slots. `EPMAX = STMAX × EPSLOTS = 256 × 8 = 2048` entries × 4 arrays. Holds lowered operands (literals, variable indices, `OE_SUBSTR` / `OE_SIZE` / `OE_CHAR` markers) and pattern parts (SPAN/BREAK/LEN/REM/CAP). | **Static, indexed by statement.** Slot `S*8+i` is statement S's i'th part. Set during `PARSE`, read during `LOWER` and `AM_EXEC`. Never reclaimed -- a statement's slots keep their values for the program lifetime. |
| `S_*` (~17 arrays) | 13,056 | Per-statement metadata: type, subject sym, goto type/target/F-target/AM-offset/F-offset, EP/PP counts, AM bytecode address, exec count. 17 INT arrays of `STMAX=256`. | **Static, indexed by statement number.** Each statement's row is set once during parse; `STCNT` is the high-water mark. |
| `_SRC` | 12,288 | Loaded SNOBOL4 source code, NUL-terminated. | **Static, read-only after load.** Filled by `READ_SRC` from the input image at startup. `SPOS` is the lexer's read cursor. Hard cap at `SRC_LIMIT = 12280`; overflow triggers `SB_OVERFLOW` halt with diagnostic (issue #14). |

### 2.2 Bytecode and stacks (~7 KB)

| Buffer | Size | Purpose | Management |
|---|---:|---|---|
| `_AM_CODE` | 4,096 | Compiled AM bytecode. | **Write-once, read-many.** `AM_PC` is the write cursor during `LOWER_ALL`; `AM_EXEC` reads from address 0 onwards. No reclaim. Hard cap at `AM_CODE_SIZE`. |
| `_ESTK` / `_ETYP` | 1,536 | Executor's eval stack -- value + type. 256 deep. | **Stack discipline.** `ESP` is the top-of-stack pointer; ops push/pop. Drops back near 0 between statements. |
| `_PSTK` / `_PSTYP` | 96 | Pattern stack frames (compiled SPAN/BREAK/LEN/REM/CAP). 16 deep. | **Stack discipline within a single match attempt.** Built up as a pattern compiles, walked during the match. |
| `_CSTK_PC` `_CSTK_PV` `_CSTK_FN` | 144 | Call stack for user-defined functions (saved PC, saved param value, function index). 16 deep. | **Stack discipline.** Pushed on `CALL`, popped on `:(RETURN)` / `:(FRETURN)`. |

### 2.3 Tables (~6 KB)

| Buffer | Size | Purpose | Management |
|---|---:|---|---|
| `_SYMN` `_SYMV` `_VTYP` `_VARS` | 1,472 | Symbol table: name (12 chars × 64) + value (INT × 64) + type tag (INT × 64) + per-symbol primary value (INT × 64). | **Insertion-only.** `SYMC` advances on each new symbol; never freed. Hard cap at `SYMMAX = 64`; overflow stops parse. |
| `_LBLN` `_LBLS` | 1,024 | Label table: name (12 chars × 64) + statement index (INT × 64). | Insertion-only, same shape as symbols. Hard cap at `LBL_MAX = 64`. |
| `_ARR_DATA` `_ARR_TYP` | 2,400 | SNOBOL4 array element pool. `ARR_MAX=8` arrays × `ARR_ELEMS=50` slots × 2 arrays × 3 bytes. | **Slab-style.** Each `ARRAY('1:N')` allocation gets a contiguous slice of `ARR_ELEMS` slots from `ARR_CNT`. No reclaim. |
| `_FN_NAME` `_FN_NAMOFF` `_FN_PARAM` `_FN_ENTRY` | 48 | User-function table: name idx, name offset, parameter idx, entry statement. 4 user functions max. | Insertion-only at parse time. |

### 2.4 Working buffers (~1.5 KB)

| Buffer | Size | Purpose | Management |
|---|---:|---|---|
| `_TB` | 128 | Lexer's token buffer for in-flight identifier / string text. | Reused per token. |
| `_SB_FWD_OLD` `_SB_FWD_NEW` | 768 | Forwarding tables for `SB_COMPACT`. 128 entries each. Map old SB offset -> new SB offset for the duration of one collection. | **Per-cycle.** Reset at the start of each `SB_COMPACT`. Hard cap at `SB_FWD_MAX = 128` distinct live strings per cycle; overflow skips compaction and triggers `SB_OVERFLOW`. |
| `_NL` `_N_OUT` `_N_INP` `_N_RAWINP` `_SB_OVF_MSG` `_SRC_OVF_MSG` etc. | ~250 | String constants (newline, special-symbol names, overflow diagnostic prefixes) + scalar flags (`SBPOS`, `STCNT`, `INP_TTY`, `SB_OVERFLOW`, etc.). | Static. |

## 3. Two regimes of management

The 128 KB splits cleanly:

### Regime A: dynamic, has a cap, lives during execution (~67 KB)

- `_SB` (64 KB) with mark-copy compaction.
- `ESTK` / `PSTK` / `CSTK` -- stack discipline, recovered at frame
  exit.
- `SB_FWD_*` -- recovered every collection cycle.

This is the working set that grows and shrinks while a program
runs. The cap is real: programs that exceed it halt with a
diagnostic.

### Regime B: compile-time-fixed, written once during parse (~61 KB)

- `_SRC` (12 KB) -- source code, read once at startup.
- `_AM_CODE` (4 KB) -- bytecode, written during lowering, read
  forever after.
- `EP_*` / `PP_*` / `S_*` (~37 KB) -- every parsed statement's
  slots and metadata, never re-set after parse.
- `SYM*` / `LBL*` / `ARR_*` / `FN_*` / `VARS` (~7 KB) --
  symbol/label/array/function tables.

This is **provisioned for the largest program SNOBOL4 will ever
compile**, not for what's actually running. `hello.sno`
(~10 statements, no patterns) consumes <100 bytes of regime B; the
compile-time `STMAX = 256` cap dictates the rest.

## 4. Compile-time caps and their tension

```
SRC_SIZE = 12288       ; bytes of source
SB_SIZE  = 65536       ; bytes of runtime string heap
STMAX    = 256         ; statements
EPSLOTS  = 8           ; expression/pattern parts per statement
EPMAX    = 2048        ; STMAX * EPSLOTS
SYMMAX   = 64          ; symbols (variable names)
LBL_MAX  = 64          ; labels
ARR_MAX  = 8           ; arrays
ARR_ELEMS = 50         ; elements per array
ESTK_DEPTH = 256       ; eval stack
SB_FWD_MAX = 128       ; live strings tracked per compaction cycle
```

These caps were sized for "any reasonable demo program." Today's
demos use **<1 KB of regime B** in practice, so the rest of the 128 KB
is provisioned headroom for programs no demo currently exercises.

But: `compiler.sno` (the future SNOBOL4-implemented compiler) is
expected to need 200+ statements, and pattern-heavy programs may
exceed `EPSLOTS = 8` per statement. The current caps are
**simultaneously over-provisioned for today's programs and likely
under-provisioned for tomorrow's.** That's the storage-runtime
brief's actual motivation: replace pre-baked caps with
`?GETMAIN(per_program_size)` at startup.

## 5. Could 128 KB be smaller without architecture changes?

Three knobs, each painful:

| Knob | Saving | Cost |
|---|---:|---|
| `EPSLOTS` 8 -> 4 | ~12 KB on `EP_*`/`PP_*` | Programs with `>4` parts in any expression / pattern fail to parse. Real demos use `<=4` mostly, but `eliza.sno` and similar push 6+. Some pattern-tutorial cases too. |
| `STMAX` 256 -> 128 | ~6 KB on `S_*`, halve `EPMAX` | Compile fails on programs > 128 statements. Real risk for `compiler.sno`; current top programs are under 100. |
| `SB_SIZE` 64 KB -> 32 KB | ~32 KB on `_SB` | Pattern-match-heavy or `REFLECT`-heavy programs hit `SB_OVERFLOW` sooner. The whole `SB_COMPACT` machinery was added (issue #12) precisely because 4 KB -> 64 KB was a forced bump. |

Under the current static-arrays-everywhere model, **128 KB is
roughly right** -- within 2x either way of "as small as you can go
without breaking real programs we want to run." The two genuinely
fixable inefficiencies (EP slot over-provisioning, `STMAX`
over-provisioning for small programs) cost code complexity and are
why the storage-runtime brief exists.

## 6. The .s vs .bin distinction (and why the briefs help)

The `.s` text and the `.bin` / `.lgo` image are paying for the
same zeros twice with different encodings:

| Layer | bytes for 128 KB of zeros | Why |
|---|---:|---|
| `.s` text (today) | ~256 KB | `.byte 0,0,0,...` -- 2 source chars per byte |
| `.s` text (with `.zero N`) | ~1 KB | one `.zero <count>` line per array, regardless of size |
| `.bin` / `.lgo` (today) | ~128 KB / ~256 KB | Bytes are baked into the image; `.lgo` text-encodes 2 hex chars per byte |
| `.bin` / `.lgo` (with `.zero N`) | unchanged -- 128 KB / 256 KB | Same bytes get into the image; only the source text representation changes |

The dcxas + dcpls briefs are **tier-1 only**: they fix the `.s` text
encoding without touching the image. This is sufficient to unblock
`pr/sno-engine-consolidation` (the EMIT_BUF problem is purely a
source-text problem).

Tier 2 (a real `.bss` segment in `cor24-asm` / `link24` / the
`.lgo` format that gets zero-filled at load time) would shrink the
image too -- 128 KB -> ~7 KB in the `.lgo` -- but is wholly out of
scope for the immediate blocker.

Tier 3 (the storage-runtime refactor in `docs/storage.md`) replaces
static buffers with `?GETMAIN(BIG)` at startup. It's
**architecturally cleaner** but doesn't shrink the image any
further than tier 2 did -- the same 128 KB still has to live in
RAM, just allocated dynamically rather than image-loaded. The win
of tier 3 is **dynamic sizing** (working memory matched to the
program being interpreted) and **fragmentation control** (the
existing static caps go away).

## 7. Recommended sequencing

1. **Tier 1 (now-ish)**: dcxas adds `.zero N` directive; dcpls
   emits it for `INIT(0)` arrays. ~20 lines of code each. `.s`
   shrinks from 261 KB to ~7 KB. `pr/sno-engine-consolidation`
   unblocks.
2. **Steps 2-5 of `snobol4-runtime-split`** (existing saga):
   complete the engine consolidation now that the `.s` budget has
   headroom.
3. **Tier 2** (some future saga, low priority): `.bss` segment
   support so the `.lgo` doesn't carry 128 KB of zero bytes either.
4. **Tier 3** (`docs/storage.md` Scope B, gated on a real
   workload that exceeds the static caps): SNOBOL4 moves to
   GETMAIN-managed working memory. By that point neither the `.s`
   nor the `.lgo` is paying for the static blocks.

The 128 KB itself doesn't shrink until tier 3 -- the runtime needs
that working memory regardless of how it gets allocated. What the
intervening tiers fix is the **encoding cost** of representing it
in source and in the loadable image.

## See also

- `docs/storage.md` -- design for the future runtime (region-stack
  over `?GETMAIN`)
- `include/snoglob.msw` -- declares all 75 statics covered above
- `src/sno_exec.plsw` -- search for `SB_COMPACT`, `SB_FWD_*`,
  `SB_COMPILE_END` for the existing string-heap GC
- `tools/briefs/dcxas-zero-fill-directive.md` -- the `.s` shrink
  brief for the assembler
- `tools/briefs/dcpls-emit-zero-fill.md` -- the `.s` shrink brief
  for the PL/SW codegen
