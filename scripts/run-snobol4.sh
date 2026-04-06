#!/bin/bash
# run-snobol4.sh -- Run a SNOBOL4 program on COR24
#
# Usage: ./scripts/run-snobol4.sh examples/hello.sno
#
# The interpreter reads source from memory at 0x080000.
# The .sno file is loaded there via --load-binary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERP_ASM="$PROJECT_DIR/build/snobol4.s"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <program.sno>" >&2
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

BASENAME=$(basename "$SNO_FILE" .sno)

# Build interpreter if not cached
if [ ! -f "$INTERP_ASM" ]; then
    echo "=== Building SNOBOL4 interpreter ===" >&2
    "$PROJECT_DIR/scripts/build.sh" \
        "$PROJECT_DIR/include/descr.msw" \
        "$PROJECT_DIR/include/heap.msw" \
        "$PROJECT_DIR/src/snobol4.plsw" >/dev/null 2>&1
fi

echo "=== SNOBOL4: $BASENAME ===" >&2
cat "$SNO_FILE" >&2
echo "---" >&2

# Run: interpreter + .sno source at 0x080000
RUN_OUT=$(cor24-run --run "$INTERP_ASM" \
    --load-binary "$SNO_FILE"@0x080000 \
    -n 100000000 -t 60 --speed 0 --dump 2>&1)

# Extract UART output
PROG_OUT=$(echo "$RUN_OUT" | awk '/^UART output:/{found=1; sub(/^UART output: /,""); print; next} found && /^Executed /{exit} found{print}')
if [ -n "$PROG_OUT" ]; then
    echo "$PROG_OUT"
fi

echo "$RUN_OUT" | awk '/^  Instructions:|^  Halted:/{print}' >&2
