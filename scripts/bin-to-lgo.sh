#!/bin/bash
# bin-to-lgo.sh -- Convert a raw COR24 binary image to .lgo text format.
#
# Usage: bin-to-lgo.sh <input.bin> <output.lgo>
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

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.bin> <output.lgo>" >&2
    exit 1
fi

IN="$1"
OUT="$2"

xxd -p -c 36 "$IN" | awk '
{
    upper = toupper($0)
    printf "L%06X%s\n", addr, upper
    addr += length($0) / 2
}
' > "$OUT"
