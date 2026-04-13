# Issues #8 and #9: Implementation Notes

## Issue #8: Case-preserving INPUT (RAWINPUT) -- IMPLEMENTED

### Changes

- `include/snoglob.msw`: Added `SYM_WIDTH` (12), widened `SYMN` and
  `LBLN` from 8 to 12 bytes per name (supporting up to 11-char names).
  Added `N_RAWINP(12) CHAR INIT('RAWINPUT')` and `RAWINP_SYM`.
- `include/am.msw`: Added `OP_READ_RAW_INPUT` (45).
- `src/sno_util.plsw`: Added `READ_RAW_INPUT` proc (identical to
  `READ_INPUT` but without the `CH >= 97 / CH <= 122 / CH = CH - 32`
  uppercasing). Updated `FIND_SPECIAL` to detect RAWINPUT symbol.
  Updated SYMN stride from `* 8` to `* SYM_WIDTH`.
- `src/sno_lex.plsw`: Updated all SYMN/LBLN stride references from
  `* 8` to `* SYM_WIDTH`. Updated SYM_ADD and LBL_ADD copy limits
  from `I < 7` to `I < 11`.
- `src/sno_exec.plsw`: Added `RAWINP_SYM` checks alongside every
  `INP_SYM` check in lowering. Added `OP_READ_RAW_INPUT` handler in
  `EXEC_IO` and dispatch entry in `AM_EXEC`.

### Symbol table widening

The original symbol table used 8 bytes per name (7 chars + null).
"RAWINPUT" is 8 characters and did not fit. Widened to 12 bytes per
name (`SYM_WIDTH`), supporting names up to 11 characters. This
required updating:
- `SYMN(512)` → `SYMN(768)` (64 * 12)
- `LBLN(512)` → `LBLN(768)` (64 * 12)
- All `* 8` stride computations → `* SYM_WIDTH`
- SYM_ADD/LBL_ADD copy loop limit `I < 7` → `I < 11`

### PL/SW compiler fix required

The initial implementation hit `CODEGEN ERROR: undefined variable for
store` when adding a 7th WHEN branch to EXEC_IO's SELECT. This was
caused by the PL/SW compiler's AST node pool being too small (8192
nodes). Fixed upstream in `sw-cor24-plsw` commit `e8e2a40` which
increased the pool to 12288 nodes.

## Issue #9: Pattern-replacement assignment -- IMPLEMENTED

### Changes

- `include/snoglob.msw`: Added `ST_REPL` (7) statement type.
- `include/am.msw`: Added `OP_PAT_REPLACE` (46).
- `src/sno_lex.plsw`: After collecting pattern parts for a match
  statement, if TT = TK_EQ, switches to ST_REPL and collects the
  replacement expression. Also added TK_EQ as a terminator for the
  pattern collection loop (otherwise the `=` was consumed as an
  unrecognized token).
- `src/sno_exec.plsw`: Added ST_REPL lowering (emits pattern build
  ops, then replacement value, then OP_PAT_REPLACE). Added
  EXEC_PAT_REPLACE handler that matches the pattern, then rebuilds
  the subject string as prefix + replacement + suffix.

### Test coverage

- `examples/replace.sno`: Basic literal replacement, middle/start
  replacement, deletion (replace with empty string).
- `examples/replace2.sno`: SPAN with capture + deletion, BREAK with
  capture + delimiter removal, failure path.
- `examples/rawinput.sno` + `examples/rawinput.dat`: Case preservation
  vs INPUT uppercasing.
