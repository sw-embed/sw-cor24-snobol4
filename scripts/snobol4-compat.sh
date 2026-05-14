#!/usr/bin/env bash
# snobol4-compat.sh -- transition wrapper for the post-cap-saga
# load-address migration. Drop-in replacement for the PATH
# `snobol4` wrapper.
#
# The pre-2026-05-14 binary loaded source at 0x80000 and data at
# 0x90000. After the cap-raise saga the binary outgrew that
# region and the addresses moved to 0xE0000 / 0xF0000 (see
# tools/briefs/dcsno-load-addr-migration.md for the full story).
#
# This wrapper accepts BOTH old- and new-style invocations:
#   snobol4 --load-binary X@0x080000 --load-binary Y@0x090000 ...
#   snobol4 --load-binary X@0x0E0000 --load-binary Y@0x0F0000 ...
#
# Any `@0x080000` (524288) or its zero-padded variants gets
# rewritten to `@0xE0000`. Same for `@0x090000` -> `@0xF0000`.
# All other args (including different addresses for advanced
# use) pass through unchanged.
#
# Install:
#   install -m 0755 scripts/snobol4-compat.sh \
#       /disk1/.../work/bin/snobol4
#
# The wrapper is a transition aid. The recommendation is to
# update invocations to use 0xE0000 / 0xF0000 directly and
# retire this wrapper.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Resolve LGO from the PATH layout the original wrapper assumed.
LGO_DEFAULT="$SCRIPT_DIR/../lib/cor24/snobol4.lgo"
if [[ -f "$LGO_DEFAULT" ]]; then
    LGO="$LGO_DEFAULT"
elif [[ -f "$SCRIPT_DIR/../build/snobol4.lgo" ]]; then
    LGO="$SCRIPT_DIR/../build/snobol4.lgo"
else
    echo "snobol4: error: could not find snobol4.lgo under $LGO_DEFAULT or build/" >&2
    exit 1
fi

# Translate any `@0x80000` / `@0x90000` (or `@524288` / `@589824`)
# in the arg list to the new addresses.
TRANSLATED=()
for arg in "$@"; do
    case "$arg" in
        *@0x080000|*@0x80000|*@524288)
            new="${arg%@*}@0xE0000"
            echo "snobol4-compat: rewrote $arg -> $new" >&2
            TRANSLATED+=("$new")
            ;;
        *@0x090000|*@0x90000|*@589824)
            new="${arg%@*}@0xF0000"
            echo "snobol4-compat: rewrote $arg -> $new" >&2
            TRANSLATED+=("$new")
            ;;
        *)
            TRANSLATED+=("$arg")
            ;;
    esac
done

exec cor24-emu --lgo "$LGO" "${TRANSLATED[@]}"
