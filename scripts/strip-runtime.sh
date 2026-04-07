#!/bin/bash
# strip-runtime.sh -- Prepare library .s for modular linking
#
# 1. Removes PL/SW runtime preamble (_start, UART_*, dummy MAIN)
# 2. Prefixes internal labels (L0-L999) with module name
# 3. Strips duplicate .data for shared globals (from snoglob.msw)
#
# Usage: ./scripts/strip-runtime.sh <module.s> <prefix>

set -euo pipefail

FILE="$1"
PREFIX="${2:-$(basename "$FILE" .s)}"

# Phase 1: Strip runtime + dummy MAIN + shared global data
# Phase 2: Prefix L-labels (done via sed since awk match(,,arr) not portable)

# Shared global labels from snoglob.msw
# Shared labels: snoglob globals + BASED records from all includes
SHARED="_AM_CODE|_AM_PC|_ARR_CNT|_ARR_DATA|_AT_SOL|_EP_TYP|_EP_VAL|_ESP|_ESTK|_INP_POS|_INP_SYM|_LAST_PUSH_TYP|_LAST_RESULT|_LBLC|_LBLN|_LBLS|_LHAS_LBL|_NL|_OUT_SYM|_PP_TYP|_PP_VAL|_PSTK|_PSTOP|_PSTYP|_S_EPCNT|_S_GLBL|_S_GTYP|_S_OEOP|_S_OETY|_S_OEV1|_S_OEV2|_S_PPCNT|_S_SIDX|_S_SPTR|_S_SUBJ|_S_TYP|_SB|_SBPOS|_SPOS|_SRC|_STCNT|_STMT_ADDR|_SYMC|_SYMN|_SYMV|_TB|_TN|_TT|_TV|_VARS|_VTYP|_DESCR|_FREEBLK|_OBJHDR|_PATNODE|_STROBJ|_SYMOBJ"

awk -v pfx="$PREFIX" -v shared_re="$SHARED" '
BEGIN {
    skip = 0; in_main = 0; started = 0; skip_data = 0
}

# --- Strip runtime preamble ---
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

# --- Strip dummy MAIN ---
/^[[:space:]]*\.globl[[:space:]]+_MAIN/ { in_main = 1; next }
/^_MAIN:/ { in_main = 1; next }
in_main && /^[[:space:]]+jmp[[:space:]]+\(r1\)/ { in_main = 0; next }
in_main { next }

# --- Strip shared global data entries ---
{
    # Check if this line is a shared global label definition
    if (match($0, /^(_[A-Z_]+[A-Z0-9_]*):/) ) {
        label = substr($0, RSTART, RLENGTH - 1)
        # Exact match: anchor with ^ and $
        if (match(label, "^(" shared_re ")$")) {
            skip_data = 1
            next
        } else {
            skip_data = 0
        }
    }
    # Skip comment before shared global
    if (skip_data && /^[[:space:]]*;/) next
    # Skip .byte/.word data lines while stripping
    if (skip_data && /^[[:space:]]+\.(byte|word)/) next
    # New label ends skip
    if (skip_data && /^[^ ;]/ && !/^[[:space:]]+\./) skip_data = 0
    if (skip_data) next

    print
}
' "$FILE" | \
sed -E "s/([^A-Za-z_])L([0-9]+)/\1${PREFIX}_L\2/g; s/^L([0-9]+)/${PREFIX}_L\1/g"
