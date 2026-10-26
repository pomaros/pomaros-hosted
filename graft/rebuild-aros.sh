#!/bin/bash
# rebuild-aros.sh -- rebuild the hosted-AROS boot + desktop module set into the
# STABLE build tree, reusing the preserved crosstools. This is the recovery /
# from-scratch-artifacts tool: after the macOS /tmp cleaner eats a build tree,
# or to populate a fresh one, run this. It never rebuilds the LLVM crosstools
# (the expensive part is preserved at $AROS_CROSSTOOLS).
#
# Stable locations (canonical, out of /tmp so the periodic cleaner can't eat them):
#   AROS_BUILD        ~/Source/aros-project/Build/pomaros-hosted          the AROS build tree / SDK / boot image
#   AROS_CROSSTOOLS   ~/Source/aros-project/aros-crosstools     the patched clang/lld + compiler-rt
#   AROS_SRC          ~/Source/aros-project/aros-core (public branch: main)
#
#   graft/rebuild-aros.sh                 # build the whole boot+desktop set
#   TARGETS="kernel-dos kernel-intuition" graft/rebuild-aros.sh   # subset
#
# Explicit metatargets share one MetaMake dependency graph, avoiding independent
# top-level make goals and repeated global prerequisite walks. The complete
# graph and its log are retained; an unknown target or failed build is fatal.
# NEVER run a bare `make` (that fetches and builds LLVM from source).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AROS_SRC="${AROS_SRC:-$ROOT/../aros-core}"
AROS_BUILD="${AROS_BUILD:-${BUILD:-$ROOT/../Build/pomaros-hosted}}"
AROS_CROSSTOOLS="${AROS_CROSSTOOLS:-${XT:-$ROOT/../aros-crosstools}}"
AROS_SRC="$AROS_SRC" "$ROOT/graft/check-core" || exit $?
: "${SOURCE_DATE_EPOCH:=$(git -C "$AROS_SRC" show -s --format=%ct HEAD)}"
export SOURCE_DATE_EPOCH
LOGDIR="${LOGDIR:-$AROS_BUILD/rebuild-logs}"
mkdir -p "$LOGDIR"

# Keep compiler prefixes immutable; aliases belong to this output tree.
HOST_TOOLS="$AROS_BUILD/host-tools"
mkdir -p "$HOST_TOOLS"
ln -sf "$AROS_CROSSTOOLS/bin/llvm-objcopy" "$HOST_TOOLS/objcopy"
ln -sf "$AROS_CROSSTOOLS/bin/llvm-ar" "$HOST_TOOLS/ar"
ln -sf "$AROS_CROSSTOOLS/bin/llvm-ranlib" "$HOST_TOOLS/ranlib"
AROS_BUILD_VENV="${AROS_BUILD_VENV:-$ROOT/../build-venv}"
export PATH="$HOST_TOOLS:$AROS_CROSSTOOLS/bin:$AROS_BUILD_VENV/bin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"

AROS_CROSSTOOLS="$AROS_CROSSTOOLS" "$ROOT/graft/check-toolchain" || exit 2
[ -f "$AROS_BUILD/Makefile" ] || { echo "FATAL: $AROS_BUILD is not a configured build tree (no Makefile). Configure it first:" >&2
    echo "  cd $AROS_BUILD && $AROS_SRC/configure --target=darwin-aarch64 --with-toolchain=llvm --with-aros-toolchain=yes --with-aros-toolchain-install=$AROS_CROSSTOOLS --without-x --with-resolution=1366x768x8" >&2
    exit 3; }

if ! grep -Eq -- '^[^#]*-ffixed-x18' "$AROS_BUILD/config/make.cfg"; then
    echo "FATAL: hosted configuration must reserve x18 (-ffixed-x18)" >&2
    exit 4
fi

# A git branch switch in $AROS_SRC touches configure's mtime without changing
# it; the top Makefile then rejects every make with "The configure script must
# be executed". Refresh the stored configuration instead of re-running
# configure (which risks the LLVM rebuild). If configure CONTENT actually
# changed, a real reconfigure is still on you.
if [ "$AROS_SRC/configure" -nt "$AROS_BUILD/config.status" ]; then
    echo "[rebuild] configure mtime newer than config.status (branch switch?) -- refreshing config.status"
    (cd "$AROS_BUILD" && ./config.status >/dev/null && touch config.status)
fi

# The boot module set (kickstart) -- section 3 of docs/features/build/README.md.
AROS_BUILD="$AROS_BUILD" AROS_CROSSTOOLS="$AROS_CROSSTOOLS" "$ROOT/graft/build-hosted-runtime" || exit 6

BOOT_TARGETS="kernel-exec kernel-dos kernel-kernel kernel-dosboot kernel-utility kernel-aros
kernel-oop kernel-intuition kernel-graphics kernel-layers kernel-keymap
kernel-debug kernel-bootloader kernel-console kernel-input kernel-keyboard
kernel-gameport workbench-devs-clipboard kernel-hidd kernel-hidd-gfx kernel-hidd-input
kernel-hidd-kbd kernel-hidd-mouse kernel-filesystem kernel-lddemon kernel-fs-con
kernel-fs-ram kernel-expansion kernel-timer kernel-battclock kernel-processor
kernel-hostlib kernel-unixio kernel-fs-emul kernel-entropy compiler-stdcio compiler-posixc
workbench-libs-muimaster
workbench-libs-cgfx workbench-libs-datatypes workbench-libs-gadtools
workbench-libs-iffparse workbench-libs-locale workbench-libs-asl
workbench-libs-commodities workbench-libs-coolimages workbench-libs-rexxsyslib
compiler-stdc kernel-hidd-cocoa kernel-bootstrap-hosted"

# The desktop userland -- section 3b. Without these the boot reaches only a CLI
# or dies in the display-driver / dos.library check.
BRIDGE_TARGETS="workbench-libs-uuid workbench-libs-bsdsocket hostlibs-emu68k
workbench-devs-hostdisk kernel-fs-exfat workbench-devs-keymaps
workbench-devs-dosdrivers workbench-fs-pipe"

DESKTOP_TARGETS="workbench-c workbench-libs-icon workbench-libs-kms workbench-libs-png
workbench-libs-lowlevel workbench-libs-diskfont workbench-libs-muiscreen workbench-libs-reaction
workbench-libs-workbench workbench-libs-version workbench-libs-mathffp
workbench-libs-mathieeesingbas workbench-libs-mathieeedoubbas
workbench-libs-mathieeedoubtrans workbench-system-wanderer
workbench-classes-zune workbench-datatypes-picture workbench-datatypes-png
workbench-utilities-clock workbench-utilities-multiview workbench-utilities-more
workbench-prefs-zune workbench-prefs-wanderer workbench-prefs-screenmode
workbench-prefs-moned workbench-prefs-settings workbench-system-aboutaros
iconset-Gorilla-wbench-icons workbench-images workbench-fonts"

# The Workbench apps behind the staged icons (Tools/, System/, Prefs/). The
# icon set is staged wholesale, so every app missing from this list shows up
# as a dead icon on the desktop. NOT here on purpose:
#   - workbench-system (aggregate): broken, workbench-system-vmm-app fails to
#     compile (missing generated locale strings) and VMM is pointless hosted;
#     the aggregate's own FILES (FixFonts + CLI) are built by
#     build_workbench_system_base below instead.
#   - SysExplorer used to trap at launch (the 64-bit taglist bug class,
#     bare-int tag values spilled to stack vararg slots -- see build README
#     3b); fixed 2026-07-16 in the NList sources (upstream 471cb63f).
APP_TARGETS="workbench-tools workbench-tools-systemmonitor workbench-tools-ahirecord workbench-tools-hdtoolbox
workbench-tools-installaros workbench-tools-sysexplorer-app
workbench-utilities-help workbench-utilities-installer
workbench-devs-diskimage-gui workbench-prefs-boot workbench-prefs-softwareupdate
external-openurl-includes external-openurl-fd external-openurl-lib
external-openurl-cmd external-openurl-prefs kernel-usb-trident"

# System/FixFonts + System/CLI (the Shell icon's default tool) have no
# standalone metatarget -- their mmake name IS the broken workbench-system
# aggregate -- so invoke their directory's generated mmakefile directly.
build_workbench_system_base() {
    printf '[rebuild] %-40s ' "workbench-system (base files)"
    if make -j"${AROS_BUILD_JOBS:-4}" --no-print-directory -C "$AROS_BUILD/workbench/system" \
        TOP="$AROS_BUILD" SRCDIR="$AROS_SRC" CURDIR=workbench/system \
        TARGET=workbench-system AROS_TARGET_ARCH=darwin AROS_TARGET_CPU=aarch64 \
        AROS_HOST_ARCH=darwin AROS_HOST_CPU=aarch64 \
        --file=mmakefile workbench-system > "$LOGDIR/workbench-system-base.log" 2>&1; then
        echo "OK"; ok=$((ok+1))
    else
        echo "FAIL (see $LOGDIR/workbench-system-base.log)"; fail=$((fail+1)); failed="$failed workbench-system-base"
    fi
}

# AHI audio (CoreAudio host path). AHI is an autotools subsystem, so the order
# matters: the coreaudio-bridge linklib must exist in Developer/lib BEFORE the
# AHI subsystem configures, or configure's `-lcoreaudio-bridge` probe fails and
# the CoreAudio driver is silently dropped (the `-quick` targets skip the
# prereq that would otherwise build it). Build the bridge first, then the
# subsystem+drivers (which install ahi.device, coreaudio.audio, the COREAUDIO
# mode file and AddAudioModes), then the AHISmoke test client.
# See docs/features/coreaudio-audio/README.md.
AUDIO_TARGETS="AHI-coreaudio-bridge-darwin workbench-devs-AHI-quick
workbench-c-ahismoke workbench-c-testlib"

# Final assembly: link the hosted kickstart core (the `boot/darwin/kernel` file
# AROSBootstrap loads first — darwin hosted uses the unix bootstrap flavor), then
# `boot` stages the boot image + AROS.boot. Without kernel-link-unix the boot
# dies immediately with "Failed to open file kernel!".
ASSEMBLE_TARGETS="kernel-link-unix boot"

FULL_SET=""
[ -z "${TARGETS:-}" ] && FULL_SET=1
TARGETS="${TARGETS:-$BOOT_TARGETS $BRIDGE_TARGETS $DESKTOP_TARGETS $APP_TARGETS}"

cd "$AROS_BUILD"
ok=0; fail=0; failed=""
# Configure AHI before apps such as AHIRecord can pull it into the base graph.
# Its executable linker probe needs the complete SDK linklibs on a fresh tree.
# Header presence in the shared SDK is not physical hardware availability hosted.
if [ -n "$FULL_SET" ]; then
    ahi_dir="$AROS_BUILD/bin/darwin-aarch64/gen/workbench/devs/AHI"
    audio_profile="hosted-coreaudio-v3:$(git -C "$AROS_SRC" rev-parse HEAD):$AROS_CROSSTOOLS"
    if [ "$(cat "$ahi_dir/.pomaros-profile" 2>/dev/null || true)" != "$audio_profile" ]; then
        if [ -d "$ahi_dir" ]; then
            find "$ahi_dir" -type f \( -name '*.o' -o -name '*.d' -o -name '*.a' -o -name Makefile.dep \) -delete
        fi
        rm -f "$ahi_dir/.configured" "$ahi_dir/.installed"
    fi
    if ac_cv_header_asm_io_h=no \
        "$ROOT/graft/build-targets" --build "$AROS_BUILD" --log "$LOGDIR/hosted-audio-configure.log" \
        --make-var "AR_PLAIN=$AROS_CROSSTOOLS/bin/llvm-ar" \
        --make-var "RANLIB=$AROS_CROSSTOOLS/bin/llvm-ranlib" \
        includes linklibs core-linklibs AHI-coreaudio-bridge-darwin workbench-devs-AHI-subsystem-configure; then
        if [ -f "$ahi_dir/Drivers/CoreAudio/Makefile" ] && \
            grep -Eq '^HAVE_COREAUDIO[[:space:]]*=[[:space:]]*1' "$ahi_dir/Drivers/Makefile" && \
            grep -Eq '^HAVE_ASMIO[[:space:]]*=[[:space:]]*$' "$ahi_dir/Drivers/Makefile" && \
            grep -Fq "$AROS_CROSSTOOLS/bin/clang" "$ahi_dir/Device/Makefile" && \
            grep -Fq "$AROS_CROSSTOOLS/bin/llvm-ar" "$ahi_dir/Device/Makefile" && \
            grep -Fq "$AROS_CROSSTOOLS/bin/llvm-ranlib" "$ahi_dir/Device/Makefile"; then
            printf '%s\n' "$audio_profile" > "$ahi_dir/.pomaros-profile"
        else
            fail=$((fail+1)); failed="$failed audio-profile"
        fi
    else
        fail=$((fail+1)); failed="$failed audio-configure"
    fi
fi

# One MetaMake graph deduplicates shared prerequisites without independent goals.
if [ "$fail" -eq 0 ]; then
    if "$ROOT/graft/build-targets" --build "$AROS_BUILD" --log "$LOGDIR/hosted-runtime.log" $TARGETS; then
        ok=$(printf '%s\n' "$TARGETS" | wc -w | tr -d ' ')
    else
        fail=$((fail+1)); failed="$failed explicit-module-graph"
    fi
fi

if [ -n "$FULL_SET" ] && [ "$fail" -eq 0 ]; then
    build_workbench_system_base
    if ! ac_cv_header_asm_io_h=no \
        "$ROOT/graft/build-targets" --build "$AROS_BUILD" --log "$LOGDIR/hosted-audio-assemble.log" \
        --make-var "AR_PLAIN=$AROS_CROSSTOOLS/bin/llvm-ar" \
        --make-var "RANLIB=$AROS_CROSSTOOLS/bin/llvm-ranlib" \
        $AUDIO_TARGETS $ASSEMBLE_TARGETS; then
        fail=$((fail+1)); failed="$failed audio-assembly"
    fi
    if ! grep -Eq '^HAVE_COREAUDIO[[:space:]]*=[[:space:]]*1' "$ahi_dir/Drivers/Makefile" ||
       ! grep -Eq '^HAVE_ASMIO[[:space:]]*=[[:space:]]*$' "$ahi_dir/Drivers/Makefile"; then
        fail=$((fail+1)); failed="$failed final-audio-profile"
    fi
fi

# AROS.boot signature: dos's __dos_IsBootable needs :AROS.boot at the boot
# volume root holding the CPU string, else every boot mis-reports "can't open
# dos.library" (see docs/features/build + run-window.sh).
BOOTV="$AROS_BUILD/bin/darwin-aarch64/AROS"
[ -d "$BOOTV" ] && { echo aarch64 > "$BOOTV/AROS.boot"; echo "[rebuild] wrote $BOOTV/AROS.boot (aarch64)"; }

echo ""
echo "[rebuild] done: $ok ok, $fail failed.${failed:+ FAILED:$failed}"
[ "$fail" -eq 0 ]
