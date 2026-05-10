#!/bin/bash
# bin-to-lgo.sh -- Convert a raw COR24 binary image to .lgo text format.
#
# Usage:
#   bin-to-lgo.sh [--lgo-full|--lgo-compact] <input.bin> <output.lgo>
#
# .lgo records are `L<24-bit hex address><hex byte stream>`, 36 data bytes
# per line (matching the format cor24-asm emits for single-file builds).
# The image is assumed to start at address 0 -- which is the layout
# link24 produces (entry module placed at 0).
#
# This converter exists because link24 emits raw `.bin` only. cor24-asm
# already produces `.lgo` for single-file builds, but the modular linker
# pipeline goes .s -> .bin per module -> link24 (.bin) -> here (.lgo).
# After dcpls (or dcasm) extends link24 to emit .lgo natively, this
# script can be retired.
#
# Modes:
#
#   --lgo-full     (default) Emit every L record including those whose
#                  data is all zeros. Bit-for-bit reproduces today's
#                  behavior. Hardware-safe -- no assumption about
#                  destination memory initial state.
#
#   --lgo-compact  Skip L records whose data is entirely zero bytes.
#                  The .lgo shrinks dramatically (typical SNOBOL4 build
#                  goes from ~374 KB to ~92 KB, ~4x). Safe when the
#                  loader's destination memory is independently zero-
#                  initialized -- cor24-emu (fresh OS process) and FPGA
#                  cold boot both qualify. NOT safe for warm reload or
#                  hot replacement: any byte that was non-zero before
#                  the load stays non-zero in the gaps.
#                  Format-wise, compact .lgo is a strict subset of full
#                  .lgo -- every emitted line is still a valid L record
#                  per the loadngo.c contract.
#
# The flag (or MODE=compact env var) selects mode. Default matches
# today's full output so this is a no-regression rename + extension.

set -euo pipefail

MODE="${MODE:-full}"

# Parse leading flag(s).
while [ $# -gt 0 ]; do
    case "$1" in
        --lgo-full)    MODE=full;    shift ;;
        --lgo-compact) MODE=compact; shift ;;
        --) shift; break ;;
        --*) echo "Unknown flag: $1" >&2; exit 2 ;;
        *) break ;;
    esac
done

if [ $# -lt 2 ]; then
    echo "Usage: $0 [--lgo-full|--lgo-compact] <input.bin> <output.lgo>" >&2
    exit 1
fi

IN="$1"
OUT="$2"

xxd -p -c 36 "$IN" | awk -v mode="$MODE" '
{
    upper = toupper($0)
    if (mode == "compact" && upper ~ /^0+$/) {
        # Skip pure-zero L record. The byte range is still accounted
        # for by addr advancement below, so subsequent records keep
        # their correct addresses.
    } else {
        printf "L%06X%s\n", addr, upper
    }
    addr += length($0) / 2
}
' > "$OUT"
