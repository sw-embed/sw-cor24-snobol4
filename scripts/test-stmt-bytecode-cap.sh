#!/bin/bash
# test-stmt-bytecode-cap.sh -- scan N statements and assert each
# emits N+1 output lines (N padN + DONE sentinel) or emits a
# diagnostic and halts cleanly. Never silently truncates.
#
# Reproduces the cap dcftn hit on 2026-05-14:
#   At 363 statements / ~17,417 source bytes: correct output
#   At 364 statements / ~17,459 source bytes: halts mid-emit
#
# Source size stays under SRC_LIMIT=65528 even at N=1000, and
# statement count stays under STMAX=1024 -- so neither of the
# documented caps is responsible. Strong suspect:
# AM_CODE_SIZE=4096 in include/snoglob.msw. At ~11 bytes of
# bytecode per OUTPUT statement, the 4096-byte buffer fills
# around N=364 -- matching dcftn's observation exactly.
#
# Test asserts CORRECT behavior:
#   * N <= cap: program emits exactly N+1 lines (N padN + DONE)
#   * N > cap : program must emit a clear compile-time
#     diagnostic and halt; silent halt-mid-emit is a hard fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERP_BIN="$PROJECT_DIR/build/snobol4.bin"

if [ ! -f "$INTERP_BIN" ]; then
    "$PROJECT_DIR/scripts/build-modular.sh" >&2
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PASSES=0
FAILS=0

# Generate a program of N OUTPUT statements + a DONE sentinel.
# Each line is `        OUTPUT = 'padNNN of NNN'` -- ~30 bytes,
# enough to dominate the source size scan but small enough that
# we can reach N=1000 without exceeding SRC_LIMIT.
gen_sno() {
    local n=$1
    local out=$2
    {
        for i in $(seq 1 $n); do
            printf "        OUTPUT = 'pad%d of %d'\n" "$i" "$n"
        done
        echo "        OUTPUT = 'DONE'"
        echo "END"
    } > "$out"
}

run_n() {
    local n=$1
    local sno="$TMP/n${n}.sno"
    gen_sno "$n" "$sno"

    local src_bytes
    src_bytes=$(wc -c < "$sno")

    local raw
    raw=$(cor24-emu --load-binary "$INTERP_BIN"@0 \
                    --load-binary "$sno"@0xE0000 \
                    --entry 0 --quiet --speed 0 -n 500000000 -t 60 2>&1) || true

    local lines
    lines=$(echo "$raw" | wc -l)
    local has_done
    has_done=$(echo "$raw" | grep -c "^DONE" || true)
    local has_diag
    has_diag=$(echo "$raw" | grep -c "^SNOBOL4:" || true)

    # Expected: either (lines == n+1 AND has_done == 1) OR
    # (has_diag >= 1) -- never silent truncation.
    local expected=$((n + 1))
    local status
    if [ "$has_done" -ge 1 ] && [ "$lines" -ge "$expected" ]; then
        status="ok-complete"
    elif [ "$has_diag" -ge 1 ] && [ "$has_done" -eq 0 ]; then
        status="ok-diagnosed-overflow"
    else
        status="FAIL-silent-truncation"
    fi

    printf '  %-25s N=%-4d src=%-6d lines=%-5d done=%d diag=%d\n' \
        "$status" "$n" "$src_bytes" "$lines" "$has_done" "$has_diag"

    case "$status" in
        ok-*)            PASSES=$((PASSES + 1)) ;;
        FAIL-*)          FAILS=$((FAILS + 1)) ;;
    esac
}

echo "Statement-count scan (bytecode-cap probe):"
# Coarse scan first to find the cliff, then fine-grained around it.
for N in 100 200 300 350 360 363 364 365 370 400 500 800 1000; do
    run_n "$N"
done

echo
echo "PASS: $PASSES"
echo "FAIL: $FAILS"
if [ "$FAILS" -gt 0 ]; then
    exit 1
fi
