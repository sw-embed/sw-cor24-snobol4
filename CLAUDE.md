# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: The interpreter is modular -- do NOT create monolithic sources

The SNOBOL4 interpreter is built from four PL/SW modules:

```
src/sno_main.plsw   -- driver: MAIN, calls READ_SRC / PARSE / LOWER_ALL / AM_EXEC
src/sno_util.plsw   -- I/O helpers, READ_SRC, READ_INPUT
src/sno_lex.plsw    -- lexer + parser + AM emit
src/sno_exec.plsw   -- lowering + executor + pattern matching + builtins
```

Plus shared globals in `include/snoglob.msw` and runtime headers in
`include/{descr,heap,am,pat}.msw`. Built by `scripts/build-modular.sh`
into `build/snobol4.bin`. Invoke via `just build` (or `just rebuild`
to bypass the dep cache).

**Do not create `src/snobol4.plsw`, `src/sno_engine.plsw`, or
`src/snolib.plsw`.** Those names belonged to abandoned single-file
or alternate-split experiments and are blocked in `.gitignore`. The
abandoned files are preserved in the `fallback-pre-cleanup` git tag
for cherry-picking, but they must not return to the working tree.

If you want to refactor the module split, that is the
`snobol4-runtime-split` saga (see `docs/plan.md` section 13.4) and
must happen as a deliberate saga -- never as a silent monolith
revival. Edit the four files above for any feature, fix, or test
work. The whole demo suite, the tutorials, the TTY runner, and the
FORTRAN compiler project (when it arrives) all depend on this layout.

## CRITICAL: AgentRail Session Protocol (MUST follow exactly)

This project uses AgentRail. Every session follows this exact sequence:

### 1. START (do this FIRST, before anything else)
```bash
agentrail next
```
Read the output carefully. It tells you your current step, prompt, skill docs, and past trajectories.

### 2. BEGIN (immediately after reading the next output)
```bash
agentrail begin
```

### 3. WORK (do what the step prompt says)
Do NOT ask the user "want me to proceed?" or "shall I start?". The step prompt IS your instruction. Execute it.

### 4. COMMIT (after the work is done)
Commit your code changes with git.

### 5. COMPLETE (LAST thing, after committing)
```bash
agentrail complete --summary "what you accomplished" \
  --reward 1 \
  --actions "tools and approach used"
```
If the step failed: `--reward -1 --failure-mode "what went wrong"`
If the saga is finished: add `--done`

### 6. STOP (after complete, DO NOT continue working)
Do NOT make any further code changes after running agentrail complete.
Any changes after complete are untracked and invisible to the next session.
If you see more work to do, it belongs in the NEXT step, not this session.

Do NOT skip any of these steps. The next session depends on your trajectory recording.
