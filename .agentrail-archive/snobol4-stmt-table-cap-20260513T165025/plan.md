# SNOBOL4 statement-table cap fix

## Problem

`include/snoglob.msw` defines `STMAX = 256`. The PARSE loop in
`src/sno_lex.plsw` bounds the parser with
`DO WHILE (TT != TK_EOF AND STCNT < STMAX);` — when statement 256
arrives, the loop exits silently. Everything after is dropped:
remaining statements, the final `END` marker, late `:S(LABEL)` /
`:F(LABEL)` registrations.

Symptoms (reported by dcftn in
`tools/briefs/dcsno-static-program-size-limit.md`):

- N=234 OUTPUT statements + dispatch loop -> `:(LOOP)` jumps to
  PC=0 (re-enters prologue), looks like an infinite loop.
- N=300 OUTPUTs -> truncates at exactly 256 output lines.
- No diagnostic at compile time.

Real-world hit: `dcftn/sw-cor24-fortran` had to splice a 70-line
runtime out of `snobol4/src/emit_asm.sno` to keep the file under
~233 stmts.

## Plan

One-step fix: raise STMAX (and the dependent EPMAX), add an
overflow diagnostic so the next time anyone hits the cap they get
told instead of corrupted output. Verify against dcftn's repro
plus a scaling regression test.

### Step 1 — raise-cap-and-diagnose

1. **Inspect dependent globals** in `include/snoglob.msw`:
   - `STMAX` (256) -- statement-table size
   - `EPSLOTS` (8) -- per-statement expression slots
   - `EPMAX` (= STMAX * EPSLOTS = 2048) -- EP_TYP/EP_VAL/PP_TYP/PP_VAL
   - All `S_*(STMAX)`, `STMT_ADDR(STMAX)` arrays scale with STMAX
   - `LBL_MAX` (64) -- labels. Probably fine, but check.

2. **Pick a new STMAX**. Target: 1024 if the resulting binary still
   builds and runs (currently ~165 KB; +1024 cap adds ~140 KB to
   the static globals). Fallback: 512 (~35 KB extra) if 1024 cliffs
   anything else (EMIT_BUF, link size, etc.). Confirm empirically.

3. **Add overflow diagnostic** in PARSE. Replace the silent
   `STCNT < STMAX` early-exit with: if the parser would step past
   STMAX, emit a clear diagnostic via the existing UART_PUTS path
   ("ERROR: program exceeds STMAX statements"), abort compilation
   cleanly. Don't truncate-and-execute.

4. **Add regression test** at the parser level: a `.sno` program
   with N=400 OUTPUT lines + dispatch loop. Expected: prints all
   400 prologues then dispatches correctly. (If we lift the cap
   to 1024, this test exercises being above the old cap but well
   within the new one.)

5. **Verify dcftn's repro fixes**. Build the repro from the brief
   for N in {200, 230, 234, 240, 300, 500}; for each, the line
   count must be exactly N+4.

### Out of scope

- No transition to dynamic statement-table allocation. That's a
  bigger lift (needs heap-backed growth + slot bookkeeping in the
  parser); we'll revisit if 1024 turns out to be the wrong cap.
- No changes to `LBL_MAX` (64). Labels haven't cliffed.
- No `pr/static-program-size-limit` branch (dcftn's brief suggested
  that name but our workflow renames at handoff, not before).

## Exit criteria

- STMAX raised (target 1024, minimum 512)
- Overflow path emits a clear compile-time diagnostic instead of
  silently truncating
- New scaling regression (`examples/many_outputs.sno` or similar)
  green
- dcftn's repro builds and runs correctly for N up to the new cap;
  emits diagnostic and halts cleanly above it
- `just demos` and `just test` regressions all green
- Build artifact (`build/snobol4.bin`) committed to feat branch

When done: commit, `agentrail complete --done`, rename branch
`feat/stmt-table-cap` -> `pr/stmt-table-cap`. Brief reply to dcftn
goes into the commit message + the saga summary.
