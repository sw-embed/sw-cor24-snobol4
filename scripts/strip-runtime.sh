#!/bin/bash
# strip-runtime.sh -- Prepare library .s for concatenation
#
# 1. Removes PL/SW runtime preamble (_start, UART_*, dummy MAIN)
# 2. Prefixes internal labels (L0-L999) with module name to avoid collisions
#
# Usage: ./scripts/strip-runtime.sh <module.s> [prefix]

set -euo pipefail

FILE="$1"
PREFIX="${2:-$(basename "$FILE" .s)}"

awk -v pfx="${PREFIX}" '
BEGIN { skip = 0; in_main = 0; started = 0 }

# Skip runtime preamble
/^[[:space:]]*\.text/ && !started { skip = 1; next }
/^[[:space:]]*\.globl[[:space:]]+_start/ { skip = 1; next }
/^_start:/ { skip = 1; next }
/^_halt:/ { skip = 1; next }
/^[[:space:]]*\.globl[[:space:]]+_UART_PUTCHAR/ { skip = 1; next }
/^_UART_PUTCHAR:/ { skip = 1; next }
/^[[:space:]]*\.globl[[:space:]]+_UART_PUTS/ { skip = 1; next }
/^_UART_PUTS:/ { skip = 1; next }
skip && /^[[:space:]]+jmp[[:space:]]+\(r1\)/ { skip = 0; started = 1; next }
skip { next }

# Skip dummy MAIN
/^[[:space:]]*\.globl[[:space:]]+_MAIN/ { in_main = 1; next }
/^_MAIN:/ { in_main = 1; next }
in_main && /^[[:space:]]+jmp[[:space:]]+\(r1\)/ { in_main = 0; next }
in_main { next }

# Skip entire .data section (globals provided by main module)
/^[[:space:]]*\.data/ { in_data = 1; next }
in_data { next }

# Prefix internal labels L0-L999
{
    line = $0
    # Process each L-label occurrence
    while (match(line, /L[0-9]+/)) {
        before = substr(line, 1, RSTART - 1)
        label = substr(line, RSTART, RLENGTH)
        after = substr(line, RSTART + RLENGTH)
        # Only prefix if not already part of a longer name (like _LABEL)
        ch_before = (RSTART > 1) ? substr(line, RSTART - 1, 1) : ""
        if (ch_before == "_" || ch_before ~ /[A-Za-z]/) {
            # Part of a longer name, skip
            printf "%s%s", before, label
            line = after
        } else {
            printf "%s%s_%s", before, pfx, label
            line = after
        }
    }
    printf "%s\n", line
}
' "$FILE"
