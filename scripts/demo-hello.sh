#!/bin/bash
# demo-hello.sh -- End-to-end Hello World demo
#
# 1. Build the modular SNOBOL4 interpreter
# 2. Load interpreter binary at 0x000000
# 3. Load examples/hello.sno at 0x080000
# 4. Run with --dump and --uart-log
# 5. Print captured UART output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERP_BIN="$PROJECT_DIR/build/snobol4.bin"
HELLO_SNO="$PROJECT_DIR/examples/hello.sno"
UART_LOG="$PROJECT_DIR/build/hello.uart.log"

echo "=== Demo: Hello World ===" >&2

# Step 1: Build interpreter (always rebuild for demo clarity)
echo "Building SNOBOL4 interpreter..." >&2
"$PROJECT_DIR/scripts/build-modular.sh" 2>&1 | tail -3 >&2

echo "" >&2
echo "Loading hello.sno:" >&2
cat "$HELLO_SNO" >&2
echo "" >&2

# Step 2: Run with --dump
echo "Running on COR24 emulator..." >&2
cor24-run --load-binary "$INTERP_BIN"@0 \
    --load-binary "$HELLO_SNO"@0x080000 \
    --entry 0 \
    -n 200000000 -t 60 --speed 0 \
    --dump \
    > "$PROJECT_DIR/build/hello.dump.txt" 2>&1

# Step 3: Extract UART output from dump
echo "=== Output ===" >&2
PROG_OUT=$(awk '/^UART output:/{found=1; sub(/^UART output: /,""); print; next} found && /^Executed /{exit} found && /^$/{exit} found{print}' "$PROJECT_DIR/build/hello.dump.txt")
if [ -n "$PROG_OUT" ]; then
    echo "$PROG_OUT"
else
    echo "(no UART output)"
fi

# Stats
echo "" >&2
grep -E "Instructions:|Halted:" "$PROJECT_DIR/build/hello.dump.txt" >&2 || true
