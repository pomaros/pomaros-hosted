#!/usr/bin/env bash
# Build hosted AROS for the darwin-aarch64 target on Apple Silicon.
#
# This is the real, working recipe (it boots to a Workbench desktop). It is the
# runnable companion to docs/features/build/README.md — read that doc for the
# full rationale, the desktop-userland set, and the symptom->cause table.
#
# The four rules that save you days (all baked in below):
#   1. build in a STABLE dir (not a session scratchpad that gets GC'd mid-build)
#   2. REUSE the cross-toolchain — never rebuild the ~1-2h LLVM from scratch
#   3. select explicit modules, never a bare `make`
#   4. build module METATARGETS, not the `kernel`/`workbench-libs` aggregates
#
# Usage:
#   graft/build-darwin-aarch64.sh                 # configure + build the boot set
#   AROS_SRC=../aros-core-pomaros graft/build-darwin-aarch64.sh
set -euo pipefail

# Paths are relative to the checkout, independent of the caller's directory.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AROS_SRC="${AROS_SRC:-$ROOT/../aros-core-pomaros}"
BUILD="${BUILD:-${AROS_BUILD:-$ROOT/../Build/pomaros-hosted}}"
XT="${XT:-${AROS_CROSSTOOLS:-$ROOT/../aros-crosstools}}"
LLVM="${LLVM:-/opt/homebrew/opt/llvm/bin}"
SHIM="${SHIM:-$BUILD/host-tools}"
AROS_SRC="$(cd "$AROS_SRC" && pwd)"
AROS_SRC="$AROS_SRC" "$ROOT/graft/check-core"
: "${SOURCE_DATE_EPOCH:=$(git -C "$AROS_SRC" show -s --format=%ct HEAD)}"
export SOURCE_DATE_EPOCH
mkdir -p "$BUILD"
BUILD="$(cd "$BUILD" && pwd)"

# Toolchain construction is an explicit first-time operation; normal rebuilds
# reuse the preserved compiler and never remove the configured build tree.
if [ ! -x "$XT/bin/clang" ]; then
    echo "Missing AROS cross-toolchain: $XT (see GETTING-STARTED.md)" >&2
    exit 2
fi
mkdir -p "$SHIM"
ln -sf "$LLVM/llvm-objcopy" "$SHIM/objcopy"
AROS_BUILD_VENV="${AROS_BUILD_VENV:-$ROOT/../build-venv}"
export PATH="$SHIM:$XT/bin:$AROS_BUILD_VENV/bin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"
cd "$BUILD"
CONFIGURE_ID="$(git -C "$AROS_SRC" rev-parse HEAD):$SOURCE_DATE_EPOCH:$XT"
if [ ! -f Makefile ] || [ "$(cat .pomaros-configure-core 2>/dev/null || true)" != "$CONFIGURE_ID" ]; then
    "$AROS_SRC/configure" --target=darwin-aarch64 --with-toolchain=llvm \
        --without-x --with-aros-toolchain=yes --with-aros-toolchain-install="$XT"
    printf '%s\n' "$CONFIGURE_ID" > .pomaros-configure-core
    {
        printf 'CORE_REVISION=%s\n' "$(git -C "$AROS_SRC" rev-parse HEAD)"
        printf 'SOURCE_DATE_EPOCH=%s\n' "$SOURCE_DATE_EPOCH"
        printf 'command='; printf '%q ' "$AROS_SRC/configure" --target=darwin-aarch64 \
            --with-toolchain=llvm --without-x --with-aros-toolchain=yes \
            --with-aros-toolchain-install="$XT"; printf '\n'
    } > pomaros-configure.txt
fi
if ! grep -Eq -- '^[^#]*-ffixed-x18' config/make.cfg; then
    echo "Hosted build requires -ffixed-x18 in config/make.cfg; refusing mixed ABI" >&2
    exit 3
fi

# --- 3) Build the boot module set (rules 3 + 4) ------------------------------
# Explicit metatargets share one MetaMake graph. This deduplicates prerequisites
# without independent top-level make goals racing a metadata regeneration.
# This set boots to a CLI. The full Wanderer desktop needs more userland — see
# docs/features/build/README.md section 3b.
# CAREFUL: mmake exits 0 on an UNKNOWN target ("Nothing known about target X"
# is not an error), so a typo here silently builds nothing. After adding a
# target, check the output does not say "Nothing known about target".
# (kernel-clipboard / workbench-libs-stdc / workbench-libs-cybergraphics were
# such silent no-ops for a while: the real names are workbench-devs-clipboard,
# compiler-stdc and workbench-libs-cgfx.)
TARGETS=(
    kernel-exec kernel-kernel kernel-dos kernel-dosboot kernel-utility
    kernel-intuition kernel-graphics kernel-layers kernel-keymap
    kernel-console kernel-input kernel-keyboard
    kernel-filesystem kernel-lddemon kernel-fs-con kernel-fs-ram
    kernel-hidd kernel-hidd-cocoa kernel-bootstrap-hosted
    compiler-stdc compiler-stdcio workbench-devs-clipboard
    workbench-libs-cgfx
)
"$ROOT/graft/build-targets" --build "$BUILD" "${TARGETS[@]}"

echo
echo "### done. Boot it from the repo:"
echo "###   make cocoametal-dylib pasteboard-dylib coreaudio-dylib bsdsock-dylib"
echo "###   graft/aros-ctl deploy && AROS_CTL_STARTUP_MODE=desktop graft/run-window.sh"
