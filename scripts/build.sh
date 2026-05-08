#!/bin/bash
# build.sh -- Compile and run a SNOBOL4 .plsw program via the
# devgroup-shared toolchain.
#
# Usage: ./scripts/build.sh [include/*.msw ...] src/program.plsw
#
# Tooling (all PATH-resolved):
#   pl-sw        -- PL/SW compiler (cor24-emu --lgo plsw.lgo wrapper)
#   cor24-asm    -- assembler: .s -> .lgo (and optionally .bin/.lst)
#   cor24-emu    -- runtime: cor24-emu --lgo <prog>.lgo
#
# Outputs build/<name>.s (assembly) and build/<name>.lgo (loadable).

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 [include/*.msw ...] src/program.plsw" >&2
    exit 1
fi

# Separate .msw and .plsw files
MACROS=()
MAIN=""
for f in "$@"; do
    case "$f" in
        *.msw) MACROS+=("$f") ;;
        *.plsw) MAIN="$f" ;;
        *) echo "Error: unknown file type: $f" >&2; exit 1 ;;
    esac
done

if [ -z "$MAIN" ]; then
    echo "Error: no .plsw file specified" >&2
    exit 1
fi

BASENAME=$(basename "$MAIN" .plsw)
mkdir -p build

# Build UART input for the compiler (FILE:/SOURCE: protocol)
build_input() {
    printf 'c\n'
    if [ ${#MACROS[@]} -gt 0 ]; then
        for m in "${MACROS[@]}"; do
            printf 'FILE:%s\n' "$(basename "$m")"
            cat "$m"
            printf '\x1E'
        done
        printf 'SOURCE:\n'
    fi
    cat "$MAIN"
    printf '\x04'
}

INPUT=$(build_input)

# Compile via pl-sw (wraps cor24-emu --lgo plsw.lgo)
echo "=== Compiling $BASENAME ===" >&2
echo "  Macros: ${MACROS[*]:-none}" >&2
echo "  Source: $MAIN" >&2

COMPILER_OUT=$(pl-sw -u "$INPUT" -n 1000000000 -t 600 --speed 0 2>&1)
UART_OUT=$(echo "$COMPILER_OUT" | sed -n '/^UART output:/,/^Executed /{/^Executed /d;p;}' | sed '1s/^UART output: //')

# Check for errors
if echo "$UART_OUT" | grep -q "compilation failed\|COMPILE ERROR\|ERROR:"; then
    echo "Compilation FAILED:" >&2
    echo "$UART_OUT" | grep -E "ERROR:|failed|error" >&2
    echo "" >&2
    echo "Full compiler output:" >&2
    echo "$UART_OUT" >&2
    exit 1
fi

# Show registered includes
echo "$UART_OUT" | grep "registered:" >&2 || true

# Extract assembly
START_MARKER="--- generated assembly ---"
END_MARKER="--- end assembly ---"
ASM=$(echo "$UART_OUT" | sed -n "/$START_MARKER/,/$END_MARKER/{/$START_MARKER/d;/$END_MARKER/d;p;}")

if [ -z "$ASM" ]; then
    echo "Error: no assembly output found" >&2
    echo "Full compiler output:" >&2
    echo "$UART_OUT" >&2
    exit 1
fi

# Save assembly
OUT_S="build/${BASENAME}.s"
echo "$ASM" > "$OUT_S"
ASM_LINES=$(echo "$ASM" | wc -l | tr -d ' ')
echo "  Assembly: $ASM_LINES lines -> $OUT_S" >&2

# Assemble to .lgo. Tolerate failure: build-modular.sh calls this script
# only to obtain $OUT_S for individual modules, where standalone assembly
# of a library module may have unresolved cross-module labels.
OUT_LGO="build/${BASENAME}.lgo"
ASM_OUT=$(cor24-asm "$OUT_S" -o "$OUT_LGO" 2>&1) || {
    echo "=== Assembly skipped/failed for $BASENAME ===" >&2
    echo "$ASM_OUT" >&2
    exit 0
}

echo "=== Running $BASENAME ===" >&2
RUN_OUT=$(cor24-emu --lgo "$OUT_LGO" -n 100000000 -t 60 --speed 0 --dump 2>&1)

# Save dump
OUT_DUMP="build/${BASENAME}-dump.txt"
echo "$RUN_OUT" > "$OUT_DUMP"

# Show program UART output
PROG_OUT=$(echo "$RUN_OUT" | sed -n '/^UART output:/,/^Executed /{/^Executed /d;p;}' | sed '1s/^UART output: //')
if [ -n "$PROG_OUT" ]; then
    echo "$PROG_OUT"
fi

# Show execution stats
echo "$RUN_OUT" | grep -E "^  Instructions:|^  Halted:" >&2 || true
