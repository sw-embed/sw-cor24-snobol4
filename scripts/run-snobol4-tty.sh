#!/bin/bash
# run-snobol4-tty.sh -- Run a SNOBOL4 program with live UART input
#
# Usage: ./scripts/run-snobol4-tty.sh program.sno
#
# Connects stdin/stdout to the emulated UART via cor24-run --terminal,
# so `LINE = INPUT` reads typed lines instead of a data file.
# Exit the session with Ctrl-] (cor24-run convention) or Ctrl-D on
# an empty input line (handled by READ_INPUT as EOF).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERP_BIN="$PROJECT_DIR/build/snobol4.bin"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <program.sno>" >&2
    exit 1
fi

SNO_FILE="$1"
if [ ! -f "$SNO_FILE" ]; then
    if [ -f "$PROJECT_DIR/demos/$SNO_FILE" ]; then
        SNO_FILE="$PROJECT_DIR/demos/$SNO_FILE"
    elif [ -f "$PROJECT_DIR/examples/$SNO_FILE" ]; then
        SNO_FILE="$PROJECT_DIR/examples/$SNO_FILE"
    else
        echo "Error: $SNO_FILE not found" >&2
        exit 1
    fi
fi

# Build interpreter if needed
if [ ! -f "$INTERP_BIN" ] || [ "$PROJECT_DIR/src/sno_main.plsw" -nt "$INTERP_BIN" ]; then
    "$PROJECT_DIR/scripts/build-modular.sh" 2>&1 | grep -v "^\[" >&2
fi

# Note: do NOT load anything at 0x090000 -- the interpreter probes that
# address and switches READ_INPUT to live UART mode when it finds it null.
exec cor24-run --terminal \
    --load-binary "$INTERP_BIN"@0 \
    --load-binary "$SNO_FILE"@0x080000 \
    --entry 0 \
    -n -1 -t -1 --speed 0
