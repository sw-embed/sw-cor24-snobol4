# Step 1 -- raise-cap-and-diagnose

Fix `dcsno-static-program-size-limit` (dcftn brief
`tools/briefs/dcsno-static-program-size-limit.md`). The SNOBOL4
parser silently drops statements beyond STMAX=256, producing the
"`:(LABEL)` wraps to PC=0" symptom dcftn hit with a 70-line `_putint`
in `snobol4/src/emit_asm.sno`.

## Changes

`include/snoglob.msw`:
- `%DEFINE STMAX 256;` -> `%DEFINE STMAX 1024;` (target; fall back to
  512 if 1024 inflates the binary past what links cleanly)
- `%DEFINE EPMAX 2048;` -> `%DEFINE EPMAX 8192;` (or 4096 for the 512
  fallback). Keep the `STMAX * EPSLOTS` comment in sync.
- All `S_*(STMAX)`, `STMT_ADDR(STMAX)`, `EP_TYP/EP_VAL/PP_TYP/PP_VAL`
  declarations automatically scale via the macro.

`src/sno_lex.plsw` PARSE loop (line ~768):
- Currently: `DO WHILE (TT != TK_EOF AND STCNT < STMAX);` silently
  exits when STMAX is hit.
- New behaviour: when the parser would write STCNT == STMAX, set
  an overflow flag, emit
  `'ERROR: program exceeds <STMAX> statements (raise STMAX in
  snoglob.msw and rebuild)'` via UART_PUTS (or the equivalent
  error path used elsewhere in the parser), and halt parsing
  cleanly. Compilation must NOT silently produce a bad bytecode
  stream.

The diagnostic should land at compile time (during parser
execution), not at runtime. Look at existing diagnostics like the
"ERROR: source read failed" pattern in pl-sw / the SB overflow
detection from issue #12 / #14 -- match that style: print to UART,
set a flag, return early from PARSE so the caller (sno_main) can
skip LOWER_ALL / AM_EXEC.

## Tests

1. **Reproduce the bug first**. Build `/tmp/r.sno` from the
   `repro-builder.sh` in the dcftn brief at N=240. Confirm current
   `build/snobol4.bin` produces the wrapped-to-PC=0 symptom (or
   the 85000-line output).

2. **Add an examples/regression**. `examples/many_outputs.sno`:
   500 `OUTPUT = 'padN'` lines followed by a small dispatch loop.
   Expected line count: 504. Add to `justfile` if the project
   convention has a `just <slug>` recipe per example.

3. **Apply the fix**. Rebuild. Verify the regression passes.

4. **Scan dcftn's table**. For N in {200, 230, 233, 234, 240, 300,
   500, 800, 1000}, line count must be exactly N+4 below the new
   cap; above the cap, output should include the new diagnostic
   and halt cleanly without garbage.

5. **No regression in existing tests**. `just demos` -- 15 halted.
   `just test` -- 14 "All tests done", no FAIL/ERROR.

## Sizing check

Current `build/snobol4.bin`: ~165 KB.

STMAX 256 -> 1024 (4x):
- 14 single-STMAX INT arrays: 256*3*14 = ~10.5 KB -> 4x = ~42 KB extra
- 4 EPMAX INT arrays (STMAX*EPSLOTS=2048 -> 8192): 2048*3*4 = ~24 KB
  -> 4x = ~72 KB extra (96 KB total - 24 KB current = ~72 KB extra)
- Estimated new binary: ~165 + 114 = ~280 KB

STMAX 256 -> 512 (2x):
- ~10.5 KB extra single-STMAX
- ~24 KB extra EPMAX
- Estimated new binary: ~200 KB

Pick 1024 unless the 280 KB binary cliffs something (link-time,
EMIT_BUF on a fresh rebuild, etc.). The interpreter has plenty of
runway on a 1 MB SRAM host even at 1024.

## Out of scope

- Dynamic statement-table allocation. The static cap with
  diagnostic is sufficient for the M5 epoch.
- LBL_MAX change. Labels haven't cliffed; leave alone.
- Branch handoff or PR creation. Step 1 is just the fix; the saga
  caller handles handoff after `agentrail complete`.

## Exit

- All tests green (`just demos`, `just test`, new
  `examples/many_outputs.sno` if added)
- dcftn repro at N=240 produces correct output
- diagnostic emits on N > STMAX with clean abort
- `build/snobol4.bin` rebuilt and committed
- commit + `agentrail complete --done` + branch rename to
  `pr/stmt-table-cap`
