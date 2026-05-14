# Step 1 -- raise SRC_LIMIT (source-byte cap)

Brief: `tools/briefs/dcsno-source-byte-cap.md`.

The runtime SOURCE: buffer has a 12,280-byte cap (`SRC_LIMIT` in
`include/snoglob.msw`; backed by `DCL SRC(SRC_SIZE) BYTE` where
`SRC_SIZE = 12288`). dcftn's `emit_asm.sno` hit this cap and had
to splice runtime comments out into separate `.s` files. The
overflow diagnostic landed with `pr/stmt-table-cap`; this step
raises the cap itself.

## Changes

`include/snoglob.msw`:
- `%DEFINE SRC_SIZE 12288;` -> `%DEFINE SRC_SIZE 65536;` (64 KiB)
- `%DEFINE SRC_LIMIT 12280;` -> `%DEFINE SRC_LIMIT 65528;`
  (SRC_SIZE - 8 for the existing null-terminator headroom)
- Keep / update the comment block that explains the cap history.

Cost: 53 KiB of static. Current `build/snobol4.bin` is ~282 KB
after the STMAX bump; this adds ~53 KB -> ~335 KB. Still well
inside the 1 MB SRAM budget. If link sizes cliff at this number,
fall back to 49152 (48 KiB / 47 KiB SRC_LIMIT), still 4x today.

## Tests

1. Reproduce the current behaviour at 13,000 bytes (250 comment
   lines + tiny program) -- diagnostic should fire.
2. After the cap bump, the same 13,000-byte file should compile
   and run cleanly.
3. Add `examples/large_source.sno`: ~30 KB SNOBOL4 source (mix
   of comment lines and active statements), should produce
   exactly the expected output.
4. Verify the overflow diagnostic still fires above the new cap
   (build a >65 KiB padded file; should print "truncated at byte=").
5. `just demos`, `just test`: no regressions.

## Out of scope

- pl-sw's `SRC_BUF_SIZE`. Different layer (pl-sw compiler input,
  not SNOBOL4 runtime). Tracked under
  `tools/briefs/dcpls-enlarge-src-buf.md`.
- Streaming SOURCE: reads. Tokenizer does random-access; bigger
  buffer is the right fix today.

## Exit

- SRC_SIZE / SRC_LIMIT raised
- new regression `examples/large_source.sno` green
- diagnostic still fires above the new cap (verified empirically;
  no need to commit a 70 KB regression file -- the smaller files
  exercise both sides)
- `build/snobol4.{bin,lgo}` rebuilt and committed
- `just demos` + `just test` green
- commit + `agentrail complete --next-slug any-pattern-fails`

When done, propose step 2 (`any-pattern-fails`).
