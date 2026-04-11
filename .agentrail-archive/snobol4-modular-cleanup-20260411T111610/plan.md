# Modular cleanup -- April 2026

Retroactively claim the eight cleanup commits that bridge the
snobol4-cleanup saga (executor refactor + bugfixes + demo batches)
and the snobol4-runtime-split saga (modular re-split).

The cleanup resolved long-standing confusion in the working tree:
an untracked stale single-file interpreter copy `src/snobol4.plsw`
shadowing the real four-module modular interpreter, an unfinished
3-module refactor draft `src/sno_engine.plsw` + `src/snolib.plsw`
sitting dormant, and a `justfile build:` target pointing at the dead
monolith. None of these were used by the actual demos, but the
arrangement was misleading enough that a fresh reader would
reasonably conclude the working interpreter was a monolith.

The cleanup also added agentrail safety rules to CLAUDE.md
(prohibiting hand-edits of `.agentrail/`, documenting the snapshot
safety net, and the audit recovery command) after a prior agent
session deleted untracked saga files irrecoverably.

See docs/plan.md section 13 for the full background and the per-phase
exit criteria.

## Steps

1. **snapshot** -- Capture all working-tree state (the dead
   interpreter files, the reconstructed agentrail archives, the
   plan.md update) before any deletions, with the snapshot tagged
   `fallback-pre-cleanup` for future resurrection.

2. **remove-and-repair** -- `git rm` the three dead .plsw files now
   that they live in the fallback tag. Repair the `just build`
   target to invoke `scripts/build-modular.sh` instead of the dead
   monolith. Add a `just rebuild` target for force-rebuild.

3. **lock-down** -- Make the modular layout explicit and irreversible:
   refresh the stale limits table in `docs/language-reference.md`,
   replace the source-files sentence with an explicit four-module
   list, add a CRITICAL section to `CLAUDE.md` forbidding monolith
   creation, block the three dead filenames in `.gitignore`. Tag the
   resulting commit `v0-modular-stable`. Then add agentrail safety
   rules to `CLAUDE.md` (snapshot guidance, audit recovery, and the
   prohibition on hand-editing `.agentrail/`).

4. **init-runtime-split** -- Initialize the next architectural saga,
   `snobol4-runtime-split`, with the plan from docs/plan.md section
   13.4 (re-split the four-module functional layout into a
   three-module runtime / engine / driver layout).

## Exit criteria

- All eight cleanup commits are claimed by saga steps.
- `agentrail audit` reports a single orphan: the meta-commit that
  recorded this retroactive reconstruction itself.
- The snobol4-runtime-split saga is re-initialized with no work lost.
