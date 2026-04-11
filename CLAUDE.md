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

## CRITICAL: Rules for .agentrail/ (do NOT violate)

The `.agentrail/` and `.agentrail-archive/` directories are the durable
record of saga and step history. Treat them like source code.

### Always track them in git

- `.agentrail/` and `.agentrail-archive/` **must** be tracked in git.
  Never add them to `.gitignore`. If you inherit a repo where they are
  ignored, that is a bug — unignore them and commit existing contents
  first.
- Commit step artifacts as each step completes, in the same commit as
  your code changes.

### Never edit or delete files under .agentrail/ by hand

- **Do not** `rm`, `rm -rf`, `mv`, or use `Write` / `Edit` on any file
  under `.agentrail/` or `.agentrail-archive/`.
- Always go through agentrail subcommands: `init`, `add`, `begin`,
  `complete`, `abort`, `archive`, `plan`, `audit`, `snapshot`.
- Direct deletion of **untracked** step files is **unrecoverable** —
  git reflog cannot restore blobs that were never staged. This has
  happened before in this repo and lost saga history (see docs/plan.md
  section 13.1). The reconstruction relied on a fortunate `git stash`
  catching part of the deleted state — there is no general recovery.

### Commit order matters

Work → `git add` → `git commit` → `agentrail complete`. In that order.
Completing before committing means the step's `commits` field is empty
and `agentrail audit` can't link the step back to its commit.

## Safety net: agentrail snapshot

Before any risky operation that touches `.agentrail/` (a big agent run,
a rebase, cleaning up untracked files, switching branches with
uncommitted saga state), run:

```bash
agentrail snapshot
```

This creates a git commit under `refs/agentrail/snapshots/<timestamp>`
containing a copy of `.agentrail/` and `.agentrail-archive/`. It uses a
throwaway temp index, so your real `.git/index` is never touched. The
snapshot survives `git gc` because a named ref holds it.

Restore from a snapshot with a normal git command:

```bash
git restore --source=refs/agentrail/snapshots/<timestamp> \
    -- .agentrail .agentrail-archive
```

List existing snapshots with `agentrail snapshot --list`.

**Run `agentrail snapshot` proactively** when you create new saga or
step files but have not yet committed them. It is cheap, leaves no
working-tree side effects, and is the only thing that protects
not-yet-staged saga state from a stray `rm` or `git clean`. This is a
safety net, not a substitute for normal commits — commit your saga
files in the same commit as your code changes, and use snapshot as
belt-and-suspenders insurance for the window between creating and
committing them.

## Recovering from gaps: agentrail audit

If saga history and git history get out of sync — commits without a
matching `agentrail complete`, or steps whose recorded commit isn't in
the current history, or a fresh repo where you want a retroactive saga
on top of existing commits — use the audit command.

```bash
agentrail audit                     # human-readable markdown report
agentrail audit --emit-commands     # shell script of suggested add lines
agentrail audit --since <revision>  # limit to commits after a revision
```

The report has four sections: matched commits, orphan commits (no
step), orphan steps (no commit), and uncommitted working-tree changes.
With `--emit-commands` it prints a shell script of `agentrail add
--commit <hash>` lines for each orphan, with slugs and prompts seeded
from commit subjects. **Review and edit the script before running** —
the seeded slugs and prompts always need human judgment.

For retroactive bootstrapping of an old repo:

```bash
agentrail audit --emit-commands > rebuild.sh
# Edit rebuild.sh: reword slugs and prompts, group commits into coherent steps
sh rebuild.sh
```

The script begins with `agentrail init --retroactive --name ...` when
no saga exists and adds one step per historical commit. Retroactive
sagas are flagged in `saga.toml` so future audits know those commits
are claimed.
