#!/bin/bash
# build-modular.sh -- Build SNOBOL4 interpreter from modular sources
#
# Pipeline:
#   1. Compile each .plsw module to .s via PL/SW compiler
#   2. Strip runtime preamble + shared globals from library modules
#   3. meta-gen prep: identify external refs, rewrite to placeholders
#   4. Pass 1 assembly: assemble at base 0 for sizes
#   5. Compute base addresses (entry module first)
#   6. Pass 2 assembly: reassemble with --base-addr
#   7. meta-gen emit: produce .meta from .lst + .syms
#   8. link24: combine binaries, patch external references
#   9. Result: build/snobol4.bin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD="$PROJECT_DIR/build"
INC="$PROJECT_DIR/include"
SRC="$PROJECT_DIR/src"
STRIP="$PROJECT_DIR/scripts/strip-runtime.sh"

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
for MOD in $ALL_MODULES; do
    echo "  [1] Compiling $MOD.plsw..." >&2
    "$PROJECT_DIR/scripts/build.sh" $INCLUDES "$SRC/${MOD}.plsw" >/dev/null 2>&1
    if [ ! -f "$BUILD/${MOD}.s" ]; then
        echo "  ERROR: $BUILD/${MOD}.s not produced" >&2
        exit 1
    fi
done

# --- Phase 2: Strip runtime + shared globals from libraries ---
# Entry module: keep as-is
cp "$BUILD/${ENTRY}.s" "$BUILD/mod/${ENTRY}.s"

# Library modules: strip runtime preamble + shared globals, prefix L-labels
for MOD in $LIBS; do
    echo "  [2] Stripping $MOD..." >&2
    "$STRIP" "$BUILD/${MOD}.s" "$MOD" > "$BUILD/mod/${MOD}.s"
done

# --- Phase 3: meta-gen prep (rewrite external la refs to la rN,0) ---
for MOD in $ALL_MODULES; do
    echo "  [3] meta-gen prep $MOD..." >&2
    "$META_GEN" prep "$BUILD/mod/${MOD}.s" \
        -o "$BUILD/mod/${MOD}_prep.s" \
        --syms "$BUILD/mod/${MOD}.syms"
done

# --- Phase 4: Pass 1 assembly (base 0 -> sizes) ---
SIZES=()
for MOD in $ALL_MODULES; do
    cor24-run --assemble "$BUILD/mod/${MOD}_prep.s" \
        "$BUILD/mod/${MOD}.bin" "$BUILD/mod/${MOD}.lst" >/dev/null 2>&1
    SZ=$(stat -f%z "$BUILD/mod/${MOD}.bin" 2>/dev/null || stat -c%s "$BUILD/mod/${MOD}.bin" 2>/dev/null)
    SIZES+=($SZ)
    echo "  [4] $MOD: $SZ bytes" >&2
done

# --- Phase 5: Compute base addresses ---
BASES=()
ADDR=0
for i in $(seq 0 $((${#SIZES[@]} - 1))); do
    BASES+=($ADDR)
    ADDR=$((ADDR + ${SIZES[$i]}))
done
echo "  [5] Layout: $(for i in $(seq 0 $((${#SIZES[@]} - 1))); do MOD=$(echo $ALL_MODULES | cut -d' ' -f$((i+1))); printf "%s@0x%04X " "$MOD" "${BASES[$i]}"; done)" >&2

# --- Phase 6: Pass 2 assembly (with --base-addr) ---
MODS_ARR=($ALL_MODULES)
for i in $(seq 0 $((${#MODS_ARR[@]} - 1))); do
    MOD="${MODS_ARR[$i]}"
    cor24-run --assemble "$BUILD/mod/${MOD}_prep.s" \
        "$BUILD/mod/${MOD}.bin" "$BUILD/mod/${MOD}.lst" \
        --base-addr "${BASES[$i]}" >/dev/null 2>&1
done

# --- Phase 7: meta-gen emit (produce .meta from pass-1 .lst) ---
# Use pass-1 .lst (base 0) so offsets are module-relative
# Re-assemble pass 1 for correct .lst
for MOD in $ALL_MODULES; do
    cor24-run --assemble "$BUILD/mod/${MOD}_prep.s" \
        "$BUILD/mod/${MOD}_p1.bin" "$BUILD/mod/${MOD}_p1.lst" >/dev/null 2>&1
    echo "  [7] meta-gen emit $MOD..." >&2
    "$META_GEN" emit "$BUILD/mod/${MOD}_p1.lst" \
        --syms "$BUILD/mod/${MOD}.syms" \
        --module "$MOD" \
        -o "$BUILD/mod/${MOD}.meta"
done

# --- Phase 8: link24 ---
echo "  [8] Linking..." >&2
"$LINK24" --entry "$ENTRY" --dir "$BUILD/mod" \
    --map "$BUILD/mod/snobol4.map" \
    $ALL_MODULES -o "$BUILD/snobol4.bin" 2>&1 | head -5 >&2

TOTAL=$(stat -f%z "$BUILD/snobol4.bin" 2>/dev/null || stat -c%s "$BUILD/snobol4.bin" 2>/dev/null)
echo "  Output: $TOTAL bytes -> build/snobol4.bin" >&2
echo "=== Build complete ===" >&2
