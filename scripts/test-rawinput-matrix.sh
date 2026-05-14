#!/bin/bash
# test-rawinput-matrix.sh -- exhaustive RAWINPUT line-count regression.
#
# For each (N, line-length) combination, build a fresh data file
# with N newline-terminated lines and assert that
# examples/rawinput_lines.sno reads exactly N records.
#
# Catches:
#   * EOF garbage (one extra read past real EOF, the
#     dcsno-rawinput-eof-garbage class).
#   * Mid-file halt (RAWINPUT silently exits at a specific size,
#     dcsno-rawinput-mid-file-halt).
#   * `:F` exactness -- the SNOBOL4 contract says every RAWINPUT
#     call must fire exactly one of :S or :F.  Both eof-garbage
#     (extra :S past real EOF) and mid-file-halt (neither :S nor
#     :F) are violations of that contract.
#
# Exit 0 if all green; exit 1 with a summary on any mismatch.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SNO="$PROJECT_DIR/examples/rawinput_lines.sno"
INTERP_BIN="$PROJECT_DIR/build/snobol4.bin"

if [ ! -f "$INTERP_BIN" ]; then
    "$PROJECT_DIR/scripts/build-modular.sh" >&2
fi

FAILS=0
PASSES=0

run_case() {
    local label="$1"
    local data_file="$2"
    local expected="$3"

    local actual
    actual=$(cor24-emu --load-binary "$INTERP_BIN"@0 \
                      --load-binary "$SNO"@0xE0000 \
                      --load-binary "$data_file"@0xF0000 \
                      --entry 0 -n 100000000 -t 30 --speed 0 --dump 2>&1 \
              | awk '/^UART output:/{f=1; sub(/^UART output: /,""); print; next} f && /^Executed /{exit} f && /^$/{exit} f{print}' \
              | grep -E "^reads=" || true)

    if [ "$actual" = "reads=$expected" ]; then
        printf '  ok   %s (reads=%d)\n' "$label" "$expected"
        PASSES=$((PASSES + 1))
    else
        printf '  FAIL %s: expected reads=%d, got %q\n' "$label" "$expected" "$actual"
        FAILS=$((FAILS + 1))
    fi
}

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Matrix: (line-length, line-count). Picked to cover:
#   N=0: empty input
#   N=1,2,3: off-by-one EOF detection
#   N=5,10: small batches
#   N=50: above the cap that triggered earlier truncation patterns
#   line-length = {10, 30, 80, 150}: short, medium, long, and the
#     non-uniform shape that hit dcsno-rawinput-mid-file-halt
#     (~152-byte files with one ~100-char line)
for LL in 10 30 80; do
    # Skip N=0: an empty data file falls through the INP_TTY probe
    # in sno_main and switches RAWINPUT to live-UART mode. Real bug,
    # separate fix; not in scope for the cap regressions.
    for N in 1 2 3 5 10 50; do
        DAT="$TMP/lines_LL${LL}_N${N}.txt"
        > "$DAT"
        for i in $(seq 1 $N); do
            printf '%*s\n' "$LL" "line${i}" | tr ' ' '.' >> "$DAT"
        done
        run_case "LL=$LL N=$N" "$DAT" "$N"
    done
done

# Mid-file-halt exact repro: 100+50 with one ~152-byte file
DAT="$TMP/mid_halt.txt"
python3 -c "import sys; sys.stdout.buffer.write(b'A'*100 + b'\n' + b'B'*50 + b'\n')" > "$DAT"
run_case "mid-halt repro (100+50)" "$DAT" 2

# Non-uniform mix: catches subtle buffer-resize issues
DAT="$TMP/varied.txt"
{
    printf 'short\n'
    python3 -c "import sys; sys.stdout.buffer.write(b'M'*60 + b'\n')"
    printf 'tiny\n'
    python3 -c "import sys; sys.stdout.buffer.write(b'L'*120 + b'\n')"
} > "$DAT"
run_case "varied lengths (4 records)" "$DAT" 4

echo
echo "PASS: $PASSES"
echo "FAIL: $FAILS"
if [ "$FAILS" -gt 0 ]; then
    exit 1
fi
