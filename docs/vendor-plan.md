# Vendor Plan — per-repo pinned tool versions

## Goal

Decouple downstream projects (e.g. `sw-cor24-fortran`, `sw-cor24-snobol4`'s own tests) from whatever version of PL/SW compiler, assembler, or emulator happens to be installed on the system `PATH` (via `sw-install`). Each downstream project should pin the exact versions of its tools so that:

- A contributor can clone the repo and build it reproducibly without juggling system-wide tool versions.
- Breaking changes upstream (PL/SW compiler, tc24r assembler, cor24 emulator) do not silently break downstream builds.
- Two projects on the same machine can use different tool versions without interference.
- Upgrading a tool version is a deliberate, reviewable commit in the downstream repo.

## Layout

Each downstream repo gets a `vendor/` directory with one subtree per pinned tool:

```
vendor/
├── plsw/
│   └── <version>/
│       ├── version.json       # { name, version, sha, date, notes }
│       ├── docs/              # snapshot of upstream docs for this version
│       ├── include/
│       │   └── <system>.msw   # runtime headers (descr, heap, etc.)
│       └── bin/               # gitignored — binary rebuilt locally or fetched
│           └── plsw.s
├── asm/
│   └── <version>/
│       ├── version.json
│       ├── docs/
│       └── bin/
│           └── tc24r
└── emu/
    └── <version>/
        ├── version.json
        ├── docs/
        └── bin/
            └── cor24-run
```

### Binary transience

`bin/` directories are listed in `.gitignore`. The `version.json` for each pinned tool records the upstream git sha and a content hash of the binary, so:

- CI and fresh clones rebuild the binary from the upstream repo at the recorded sha (or fetch it from a release artifact).
- `version.json` is the source of truth for what "this version" means; `bin/` is a local cache.
- The build script verifies the rebuilt binary matches the recorded hash before proceeding.

### Version selection

Build scripts look for tools in this order:
1. `vendor/<tool>/<pinned>/bin/<binary>` — pinned version, local cache hit
2. Rebuild/download to cache if missing, verify hash
3. **Never** fall back to system `PATH` — that defeats pinning

An env var `VENDOR_TOOL_OVERRIDE=plsw=/path/to/dev/plsw.s` lets a developer point at an in-progress upstream checkout for co-development, but this must be explicit.

## Upstream repos referenced

When the tool repos have been split and stabilized in their new homes, each downstream `vendor/<tool>/<version>/version.json` points at:

- **PL/SW compiler**: new repo (TBD URL), currently `sw-embed/sw-cor24-plsw`
- **Assembler (tc24r)**: new repo, currently `sw-vibe-coding/tc24r`
- **Emulator (cor24-run)**: new repo, currently part of `sw-embed/sw-cor24-plsw` or a separate cor24 repo (TBD)

## Applicability

This vendor layout is generic — the same scheme works for any downstream repo that consumes these tools:
- `sw-cor24-snobol4` vendors `plsw`, `asm`, `emu` (the interpreter's own build)
- `sw-cor24-fortran` vendors `plsw`, `asm`, `emu`, **and** `snobol4` (the FTI-0 compiler is written in SNOBOL4, so `snobol4.bin` becomes a fourth pinned tool)
- Future projects in the ecosystem follow the same `vendor/<repo>/<version>/` convention

## Open questions

Before implementing, need to decide:

1. **Binary distribution**: Are pinned tool binaries rebuilt locally from the recorded upstream sha, or fetched from upstream release artifacts? Rebuilding is more portable (no release pipeline needed) but slower on first checkout.

2. **version.json schema**: Should it include just `{name, version, sha, date, notes}` as proposed, or also a `hash` field (sha256 of the binary) for tamper detection and cache validation?

3. **Multiple versions side-by-side**: Should a single repo be able to pin multiple concurrent versions of the same tool (e.g. for A/B testing an upgrade), or is it always exactly one active version per tool? The `vendor/<tool>/<version>/` layout supports both, but the build script needs to know which one is active — presumably a top-level `vendor/active.json` or similar.

4. **SNOBOL4 interpreter as a vendorable tool**: `snobol4.bin` is large and built from a modular PL/SW source tree, not a single-file compiler. For `sw-cor24-fortran` to vendor it, we need a clear "interpreter + required data/runtime" package. Is the shape `vendor/snobol4/<version>/bin/snobol4.bin` enough, or does it also need the `include/` headers from this repo (none are referenced at runtime, so probably not)?

5. **Upstream repo URLs**: Once the new repos exist for PL/SW, tc24r, cor24, what's the canonical git URL / org that `version.json` should record? This determines the rebuild source-of-truth.

6. **CI integration**: How does CI pick up a pinned tool? Does it run a `vendor/rebuild-all.sh` script on every build, or cache the `bin/` directory?

## Migration path

1. **Stabilize upstream tools** — finish the move of PL/SW, tc24r, cor24 into their new repos.
2. **Add `vendor/` to `sw-cor24-snobol4` first** — this is the simplest consumer (one binary, one header set) and proves the shape.
3. **Add `vendor/` to `sw-cor24-fortran`** — adds the complication of vendoring `snobol4.bin` as a fourth tool. This is where the layout pays off.
4. **Remove the hardcoded `~/github/sw-embed/sw-cor24-plsw/build/plsw.s` lookups** from `scripts/build.sh` and friends. Replace with `vendor/plsw/<active>/bin/plsw.s` + the override env var.
5. **Add a `vendor upgrade <tool> <new-sha>` helper** so bumping a pinned version is a one-command workflow that updates `version.json`, clears the binary cache, and rebuilds.
