#!/bin/bash
# check-demo.sh -- run a SNOBOL4 demo and diff its UART output
# against examples/<name>.expected.
#
# Usage: ./scripts/check-demo.sh <name> [data-file-name]
#
# Exits 0 if output matches the expected fixture exactly,
# 1 with a unified diff otherwise.
#
# This complements `Halted: true` in `just demos`, which only
# verifies the program reached _halt cleanly -- it does NOT
# check that the output is correct. A correct halt with wrong
# output is exactly how dcsno-concat-after-funcall-truncates
# slipped past dcsno's regression test on 2026-05-14.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <name> [data-file-name]" >&2
    exit 2
fi

NAME="$1"
DATA_FILE="${2:-}"
SNO="$PROJECT_DIR/examples/${NAME}.sno"
EXPECTED="$PROJECT_DIR/examples/${NAME}.expected"

if [ ! -f "$SNO" ]; then
    echo "  ERROR: missing $SNO" >&2
    exit 2
fi
if [ ! -f "$EXPECTED" ]; then
    echo "  ERROR: missing $EXPECTED (run scripts/capture-expected.sh to seed)" >&2
    exit 2
fi

# Run via the standard runner and capture stdout (= UART output).
if [ -n "$DATA_FILE" ]; then
    ACTUAL=$("$PROJECT_DIR/scripts/run-snobol4.sh" "$SNO" "$PROJECT_DIR/examples/$DATA_FILE" 2>/dev/null)
else
    ACTUAL=$("$PROJECT_DIR/scripts/run-snobol4.sh" "$SNO" 2>/dev/null)
fi

# Compare against fixture.
if diff -u "$EXPECTED" <(echo "$ACTUAL") > /tmp/check-demo-diff.$$; then
    echo "  ok   $NAME"
    rm -f /tmp/check-demo-diff.$$
    exit 0
else
    echo "  FAIL $NAME (output does not match expected)"
    cat /tmp/check-demo-diff.$$
    rm -f /tmp/check-demo-diff.$$
    exit 1
fi
