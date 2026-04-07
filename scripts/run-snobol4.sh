#!/bin/bash
# run-snobol4.sh -- Run a SNOBOL4 program on COR24
#
# Usage: ./scripts/run-snobol4.sh program.sno [data.dat]
#
# The interpreter is loaded from build/snobol4.bin (modular build).
# SNOBOL4 source at 0x080000, optional data at 0x090000.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERP_BIN="$PROJECT_DIR/build/snobol4.bin"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <program.sno> [data.dat]" >&2
    echo "" >&2
    echo "Examples:" >&2
    for f in "$PROJECT_DIR/examples/"*.sno; do
        [ -f "$f" ] && echo "  $0 $(basename "$f")" >&2
    done
    exit 1
fi

SNO_FILE="$1"
if [ ! -f "$SNO_FILE" ]; then
    if [ -f "$PROJECT_DIR/examples/$SNO_FILE" ]; then
        SNO_FILE="$PROJECT_DIR/examples/$SNO_FILE"
    else
        echo "Error: $SNO_FILE not found" >&2
        exit 1
    fi
fi

DAT_FILE=""
if [ $# -ge 2 ]; then
    DAT_FILE="$2"
    if [ ! -f "$DAT_FILE" ]; then
        if [ -f "$PROJECT_DIR/examples/$DAT_FILE" ]; then
            DAT_FILE="$PROJECT_DIR/examples/$DAT_FILE"
        else
            echo "Error: $DAT_FILE not found" >&2
            exit 1
        fi
    fi
fi

BASENAME=$(basename "$SNO_FILE" .sno)

# Build interpreter if needed
if [ ! -f "$INTERP_BIN" ] || [ "$PROJECT_DIR/src/sno_main.plsw" -nt "$INTERP_BIN" ]; then
    "$PROJECT_DIR/scripts/build-modular.sh" 2>&1 | grep -v "^\[" >&2
fi

echo "=== SNOBOL4: $BASENAME ===" >&2
cat "$SNO_FILE" >&2
echo "---" >&2

# Entry at 0 (which is _start, which calls _MAIN)
ENTRY=0

# Run
if [ -n "$DAT_FILE" ]; then
    RUN_OUT=$(cor24-run --load-binary "$INTERP_BIN"@0 \
        --load-binary "$SNO_FILE"@0x080000 \
        --load-binary "$DAT_FILE"@0x090000 \
        --entry "$ENTRY" \
        -n 200000000 -t 120 --speed 0 --dump 2>&1)
else
    RUN_OUT=$(cor24-run --load-binary "$INTERP_BIN"@0 \
        --load-binary "$SNO_FILE"@0x080000 \
        --entry "$ENTRY" \
        -n 200000000 -t 120 --speed 0 --dump 2>&1)
fi

# Extract UART output
PROG_OUT=$(echo "$RUN_OUT" | awk '/^UART output:/{found=1; sub(/^UART output: /,""); print; next} found && /^Executed /{exit} found{print}')
if [ -n "$PROG_OUT" ]; then
    echo "$PROG_OUT"
fi

echo "$RUN_OUT" | awk '/^  Instructions:|^  Halted:/{print}' >&2
