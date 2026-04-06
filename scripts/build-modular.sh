#!/bin/bash
# build-modular.sh -- Build SNOBOL4 interpreter from modular sources
#
# Target architecture (docs/linker-design.md):
#   PL/SW -m flag -> prefixed labels + .meta -> link24 -> combined .bin
#
# Current approach (until PL/SW gets module support):
#   Compile each module -> strip runtime -> prefix labels -> concat .s
#   Then assemble the combined .s with cor24-run
#
# Future approach (when link24 + PL/SW -m exist):
#   Compile each module with -m <name> -> assemble -> link24 -> .bin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD="$PROJECT_DIR/build"
INC="$PROJECT_DIR/include"
SRC="$PROJECT_DIR/src"
STRIP="$PROJECT_DIR/scripts/strip-runtime.sh"

INCLUDES="$INC/descr.msw $INC/heap.msw $INC/am.msw $INC/pat.msw $INC/snoglob.msw"

# Module order: main first (has _start), then libraries by layer
MODULES="sno_main sno_util sno_lex sno_exec"

mkdir -p "$BUILD"

# Phase 1: Compile each module to .s
for MOD in $MODULES; do
    echo "  Compiling $MOD..." >&2
    "$PROJECT_DIR/scripts/build.sh" $INCLUDES "$SRC/${MOD}.plsw" >/dev/null 2>&1
    if [ ! -f "$BUILD/${MOD}.s" ]; then
        echo "  ERROR: $BUILD/${MOD}.s not produced" >&2
        exit 1
    fi
    echo "    -> $(wc -l < "$BUILD/${MOD}.s") lines" >&2
done

# Phase 2: Concatenate with stripping and label prefixing
# Main module goes first verbatim (has _start + runtime)
# Library modules: strip runtime + preamble, prefix internal labels,
# strip duplicate .data entries (globals from snoglob)
echo "  Linking..." >&2
{
    # Main module: keep everything
    cat "$BUILD/sno_main.s"

    # Library modules: strip runtime + prefix labels + smart data strip
    for MOD in sno_util sno_lex sno_exec; do
        "$STRIP" "$BUILD/${MOD}.s" "$MOD"
    done
} > "$BUILD/snobol4.s"

LINES=$(wc -l < "$BUILD/snobol4.s")
BYTES=$(wc -c < "$BUILD/snobol4.s")
echo "  Linked: $LINES lines, $BYTES bytes -> build/snobol4.s" >&2
echo "=== Build complete ===" >&2
