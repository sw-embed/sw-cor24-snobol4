#!/bin/bash
# build-modular.sh -- Build SNOBOL4 interpreter from modular sources
#
# Pipeline (per docs/linker-design.md):
#   1. Compile each .plsw module to .s (library modules use %DEFINE LIBRARY)
#   2. meta-gen prep: identify external refs, rewrite to la rN,0 placeholders
#   3. Pass 1 assembly: assemble at base 0 for sizes
#   4. Compute base addresses (entry module first)
#   5. Pass 2 assembly: reassemble with --base-addr
#   6. meta-gen emit: produce .meta from pass-1 .lst + .syms
#   7. link24: combine binaries, patch FIXUP references
#   8. Result: build/snobol4.bin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD="$PROJECT_DIR/build"
INC="$PROJECT_DIR/include"
SRC="$PROJECT_DIR/src"

# Tools
LINKER_DIR="$HOME/github/sw-embed/sw-cor24-plsw/components/linker/target/release"
LINK24="$LINKER_DIR/link24"
META_GEN="$LINKER_DIR/meta-gen"

INCLUDES="$INC/descr.msw $INC/heap.msw $INC/am.msw $INC/pat.msw $INC/snoglob.msw"

# Module order: entry module first, then libraries
ENTRY=sno_main
LIBS="sno_util sno_lex sno_exec"
ALL_MODULES="$ENTRY $LIBS"

mkdir -p "$BUILD/mod"

echo "=== Building SNOBOL4 interpreter (modular) ===" >&2

# --- Phase 1: Compile each .plsw to .s ---
# sno_main: no LIBRARY (has _start + runtime + shared globals)
# sno_util, sno_lex, sno_exec: %DEFINE LIBRARY (suppresses runtime + shared globals)
for MOD in $ALL_MODULES; do
    echo "  [1] Compiling $MOD..." >&2
    "$PROJECT_DIR/scripts/build.sh" $INCLUDES "$SRC/${MOD}.plsw" >/dev/null 2>&1
    if [ ! -f "$BUILD/${MOD}.s" ]; then
        echo "  ERROR: $BUILD/${MOD}.s not produced" >&2
        exit 1
    fi
    cp "$BUILD/${MOD}.s" "$BUILD/mod/${MOD}.s"
done

# --- Phase 2: meta-gen prep (rewrite external la refs to placeholders) ---
for MOD in $ALL_MODULES; do
    echo "  [2] meta-gen prep $MOD..." >&2
    "$META_GEN" prep "$BUILD/mod/${MOD}.s" \
        -o "$BUILD/mod/${MOD}_prep.s" \
        --syms "$BUILD/mod/${MOD}.syms"
done

# --- Phase 3: Pass 1 assembly (base 0 -> sizes + .lst) ---
SIZES=()
for MOD in $ALL_MODULES; do
    cor24-run --assemble "$BUILD/mod/${MOD}_prep.s" \
        "$BUILD/mod/${MOD}_p1.bin" "$BUILD/mod/${MOD}_p1.lst" >/dev/null 2>&1
    SZ=$(stat -f%z "$BUILD/mod/${MOD}_p1.bin" 2>/dev/null || stat -c%s "$BUILD/mod/${MOD}_p1.bin" 2>/dev/null)
    SIZES+=($SZ)
    echo "  [3] $MOD: $SZ bytes" >&2
done

# --- Phase 4: Compute base addresses ---
BASES=()
ADDR=0
MODS_ARR=($ALL_MODULES)
for i in $(seq 0 $((${#SIZES[@]} - 1))); do
    BASES+=($ADDR)
    ADDR=$((ADDR + ${SIZES[$i]}))
done
echo "  [4] Layout: $(for i in $(seq 0 $((${#SIZES[@]} - 1))); do printf "%s@0x%04X " "${MODS_ARR[$i]}" "${BASES[$i]}"; done)" >&2

# --- Phase 5: Pass 2 assembly (with --base-addr) ---
for i in $(seq 0 $((${#MODS_ARR[@]} - 1))); do
    MOD="${MODS_ARR[$i]}"
    cor24-run --assemble "$BUILD/mod/${MOD}_prep.s" \
        "$BUILD/mod/${MOD}.bin" "$BUILD/mod/${MOD}.lst" \
        --base-addr "${BASES[$i]}" >/dev/null 2>&1
done

# --- Phase 6: meta-gen emit (produce .meta from pass-1 .lst) ---
for MOD in $ALL_MODULES; do
    echo "  [6] meta-gen emit $MOD..." >&2
    "$META_GEN" emit "$BUILD/mod/${MOD}_p1.lst" \
        --syms "$BUILD/mod/${MOD}.syms" \
        --module "$MOD" \
        -o "$BUILD/mod/${MOD}.meta"
done

# --- Phase 7: link24 ---
echo "  [7] Linking..." >&2
"$LINK24" --entry "$ENTRY" --dir "$BUILD/mod" \
    --map "$BUILD/mod/snobol4.map" \
    $ALL_MODULES -o "$BUILD/snobol4.bin" 2>&1 | head -3 >&2

TOTAL=$(stat -f%z "$BUILD/snobol4.bin" 2>/dev/null || stat -c%s "$BUILD/snobol4.bin" 2>/dev/null)
echo "  Output: $TOTAL bytes -> build/snobol4.bin" >&2
echo "=== Build complete ===" >&2
