#!/bin/bash
# build-modular.sh -- Build SNOBOL4 interpreter from modular sources
#
# Compiles 4 modules separately, strips runtime from libraries,
# concatenates assembly, produces build/snobol4.s

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD="$PROJECT_DIR/build"
INC="$PROJECT_DIR/include"
SRC="$PROJECT_DIR/src"
STRIP="$PROJECT_DIR/scripts/strip-runtime.sh"

INCLUDES="$INC/descr.msw $INC/heap.msw $INC/am.msw $INC/pat.msw $INC/snoglob.msw"

mkdir -p "$BUILD"

compile_module() {
    local NAME="$1"
    local PLSW="$2"
    echo "  Compiling $NAME..." >&2
    "$PROJECT_DIR/scripts/build.sh" $INCLUDES "$PLSW" >/dev/null 2>&1
    local ASM="$BUILD/$(basename "$PLSW" .plsw).s"
    if [ ! -f "$ASM" ]; then
        echo "  ERROR: $ASM not produced" >&2
        return 1
    fi
    echo "    -> $(wc -l < "$ASM") lines" >&2
}

echo "=== Building SNOBOL4 interpreter (modular) ===" >&2

# Compile each module
compile_module "main (L4)" "$SRC/sno_main.plsw"
compile_module "util (L1)" "$SRC/sno_util.plsw"
compile_module "lex  (L2)" "$SRC/sno_lex.plsw"
compile_module "exec (L3)" "$SRC/sno_exec.plsw"

# Concatenate: main first (has _start + runtime), then libraries stripped
echo "  Linking..." >&2
{
    cat "$BUILD/sno_main.s"
    "$STRIP" "$BUILD/sno_util.s" "util"
    "$STRIP" "$BUILD/sno_lex.s" "lex"
    "$STRIP" "$BUILD/sno_exec.s" "exec"
} > "$BUILD/snobol4.s"

LINES=$(wc -l < "$BUILD/snobol4.s")
BYTES=$(wc -c < "$BUILD/snobol4.s")
echo "  Linked: $LINES lines, $BYTES bytes -> build/snobol4.s" >&2
echo "=== Build complete ===" >&2
