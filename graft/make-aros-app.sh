#!/bin/sh
# make-aros-app.sh — wrap hosted AROS in a first-class macOS .app bundle.
#
# ADDITIVE + non-colliding: a sibling to run-window.sh (which keeps its relocatable
# bare-binary model). This packages the same pieces as a double-clickable PomAROS.app:
#   Contents/MacOS/PomAROS              launcher script (CFBundleExecutable) — sets env
#   Contents/MacOS/AROSBootstrap     the hosted-AROS binary (signed w/ entitlements)
#   Contents/MacOS/AROSBootstrap.conf + aros-host-conf.sh
#   Contents/Frameworks/cocoametal.dylib + host shims + settings.json
#       required legacy engine: libemu68k.dylib
#       optional shims: libpasteboard.dylib, libcoreaudio.dylib, libbsdsockhost.dylib
#   Contents/Resources/settings.json (AROS_SETTINGS_SCHEMA)
#   Contents/Resources/aros-bootdir (external development build working directory)
#   Contents/Info.plist
# The launcher exports AROS_DARWIN_THREADED, points the dylib at the bundled schema,
# and sources aros-host-conf.sh so the GUI's aros-host.conf drives the boot.
#
#   ./make-aros-app.sh            build build/PomAROS.app from the discovered build
#   ./make-aros-app.sh --check    unattended structural self-check (no AROS build needed)
#
# Note (v1 limitation): AROSBootstrap.conf's module paths point at the EXTERNAL AROS
# install (same as run-window.sh) — the bundle wraps the launcher, it does not embed
# the whole AROS tree yet. The first-class app surface (menu/About/icon/settings) is
# delivered by the dylib regardless of packaging.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DYLIB="${AROS_CTL_DYLIB:-$ROOT/build/cocoametal.dylib}"
PASTEBOARD="${AROS_CTL_PASTEBOARD_DYLIB:-$ROOT/build/libpasteboard.dylib}"
COREAUDIO="${AROS_CTL_COREAUDIO_DYLIB:-$ROOT/build/libcoreaudio.dylib}"
BSDSOCK="${AROS_CTL_BSDSOCK_DYLIB:-$ROOT/build/libbsdsockhost.dylib}"
EMU68K="${AROS_CTL_EMU68K_DYLIB:-$ROOT/build/libemu68k.dylib}"
SCHEMA="$ROOT/hosted/cocoametal/settings.json"
ICON="${AROS_CTL_ICON:-$ROOT/hosted/cocoametal/PomAROS.icns}"
ENT="${AROS_CTL_ENT:-$HERE/aros-host.entitlements.plist}"
APP="${AROS_APP:-$ROOT/build/PomAROS.app}"
VERSION_FILE="${POMAROS_VERSION_FILE:-$ROOT/VERSION}"
[ -r "$VERSION_FILE" ] || { echo "missing release version file: $VERSION_FILE" >&2; exit 1; }
. "$VERSION_FILE"
VERSION="${POMAROS_VERSION:-}"
BUILD_NUMBER="${POMAROS_BUILD_NUMBER:-}"
case "$VERSION" in *[!0-9.]*|'') echo "invalid POMAROS_VERSION in $VERSION_FILE: $VERSION" >&2; exit 2 ;; esac
case "$BUILD_NUMBER" in *[!0-9]*|'') echo "invalid POMAROS_BUILD_NUMBER in $VERSION_FILE: $BUILD_NUMBER" >&2; exit 2 ;; esac

INFO_PLIST='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>PomAROS</string>
  <key>CFBundleDisplayName</key><string>PomAROS Hosted</string>
  <key>CFBundleIdentifier</key><string>org.pomaros.hosted</string>
  <key>CFBundleExecutable</key><string>PomAROS</string>
  <key>CFBundleIconFile</key><string>PomAROS</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>@POMAROS_VERSION@</string>
  <key>CFBundleVersion</key><string>@POMAROS_BUILD_NUMBER@</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 John Knipper</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict></plist>'

LAUNCHER='#!/bin/sh
D="$(cd "$(dirname "$0")" && pwd)"
APP="$(cd "$D/../.." && pwd)"
export AROS_DARWIN_THREADED=1
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks"
export AROS_SETTINGS_SCHEMA="$APP/Contents/Resources/settings.json"
: "${AROS_RUN_DIR:=$HOME/Library/Application Support/AROS}"; export AROS_RUN_DIR
[ -f "$APP/Contents/Resources/report-env.sh" ] && . "$APP/Contents/Resources/report-env.sh"
POMAROS_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || true)"
POMAROS_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist" 2>/dev/null || true)"
export POMAROS_VERSION POMAROS_BUILD_NUMBER
: "${AROS_HOST_CONF:=$HOME/Library/Application Support/AROS/aros-host.conf}"
export AROS_HOST_CONF
[ -f "$D/aros-host-conf.sh" ] && . "$D/aros-host-conf.sh"
if [ -n "${AROS_HOST_MEMORY:-}" ] && [ -f "$D/AROSBootstrap.conf" ]; then
    grep -v "^memory " "$D/AROSBootstrap.conf" > "$D/.c.tmp" 2>/dev/null || cp "$D/AROSBootstrap.conf" "$D/.c.tmp"
    printf "memory %s\n" "$AROS_HOST_MEMORY" >> "$D/.c.tmp"; mv "$D/.c.tmp" "$D/AROSBootstrap.conf"
fi
BOOTD="$(cat "$APP/Contents/Resources/aros-bootdir")"
[ -d "$BOOTD" ] || { echo "PomAROS Hosted: external AROS build is unavailable; rebuild the development app." >&2; exit 1; }
cd "$BOOTD" || exit 1
exec "$D/AROSBootstrap" -c "$D/AROSBootstrap.conf"'

assemble() {   # assemble <bootd> <app>
    _bd="$(cd "$1" && pwd)"; _app="$2"
    rm -rf "$_app"
    mkdir -p "$_app/Contents/MacOS" "$_app/Contents/Frameworks" "$_app/Contents/Resources"
    cp "$_bd/AROSBootstrap" "$_app/Contents/MacOS/AROSBootstrap"
    printf '%s\n' "$_bd" > "$_app/Contents/Resources/aros-bootdir"
    [ -f "$_bd/AROSBootstrap.conf" ] && cp "$_bd/AROSBootstrap.conf" "$_app/Contents/MacOS/AROSBootstrap.conf"
    cp "$DYLIB"  "$_app/Contents/Frameworks/cocoametal.dylib"
    [ -f "$PASTEBOARD" ] && cp "$PASTEBOARD" "$_app/Contents/Frameworks/libpasteboard.dylib"
    [ -f "$COREAUDIO" ] && cp "$COREAUDIO" "$_app/Contents/Frameworks/libcoreaudio.dylib"
    [ -f "$BSDSOCK" ] && cp "$BSDSOCK" "$_app/Contents/Frameworks/libbsdsockhost.dylib"
    [ -f "$EMU68K" ] && cp "$EMU68K" "$_app/Contents/Frameworks/libemu68k.dylib"
    cp "$SCHEMA" "$_app/Contents/Frameworks/settings.json"
    cp "$SCHEMA" "$_app/Contents/Resources/settings.json"
    [ -f "$ICON" ] && cp "$ICON" "$_app/Contents/Resources/PomAROS.icns"
    cp "$HERE/aros-host-conf.sh" "$_app/Contents/MacOS/aros-host-conf.sh"
    cp "$HERE/report-env.sh" "$_app/Contents/Resources/report-env.sh"
    printf '%s' "$LAUNCHER"   > "$_app/Contents/MacOS/PomAROS"; chmod +x "$_app/Contents/MacOS/PomAROS"
    printf '%s' "$INFO_PLIST" | sed \
        -e "s|@POMAROS_VERSION@|$VERSION|g" \
        -e "s|@POMAROS_BUILD_NUMBER@|$BUILD_NUMBER|g" \
        > "$_app/Contents/Info.plist"
}

# --- discover the AROS boot dir (same approach as run-window.sh) ---
find_bootd() {
    if [ -n "${AROS_CTL_BOOTD:-}" ]; then printf '%s\n' "$AROS_CTL_BOOTD"; return; fi
    for d in \
        "${BUILD:-${AROS_BUILD:-$ROOT/../Build/pomaros-hosted}}/bin/darwin-aarch64/AROS/boot/darwin" \
        "$ROOT/build/AROS/boot/darwin"; do
        [ -x "$d/AROSBootstrap" ] || continue
        printf '%s\n' "$d"
        return
    done
}

# --- unattended structural self-check (synthesizes a dummy bootd; no AROS build) ---
if [ "${1:-}" = "--check" ]; then
    fail=0; ck() { if [ "$1" = 0 ]; then printf '    ok: %s\n' "$2"; else printf '    FAIL: %s\n' "$2"; fail=1; fi; }
    echo "[APP] make-aros-app structural self-check"
    [ -f "$DYLIB" ]  || { echo "[APP] SKIP: build/cocoametal.dylib missing (run: make cocoametal-dylib)"; exit 0; }
    [ -f "$SCHEMA" ] || { echo "[APP] FAIL: settings.json missing"; exit 1; }
    TMP="$(mktemp -d)"; BD="$TMP/bootd"; mkdir -p "$BD"
    printf '#!/bin/sh\n[ "$(pwd)" = "$POMAROS_TEST_BOOTDIR" ]\n' > "$BD/AROSBootstrap"; chmod +x "$BD/AROSBootstrap"
    printf 'module /x/exec.library\nmemory 64\n' > "$BD/AROSBootstrap.conf"
    assemble "$BD" "$TMP/PomAROS.app"
    A="$TMP/PomAROS.app/Contents"
    plutil -lint "$A/Info.plist" >/dev/null 2>&1; ck $? "Info.plist is valid"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$A/Info.plist" 2>/dev/null)" = "$VERSION" ]; ck $? "bundle version matches VERSION"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$A/Info.plist" 2>/dev/null)" = "$BUILD_NUMBER" ]; ck $? "bundle build number matches VERSION"
    AROS_HOST_CONF=/dev/null AROS_RUN_DIR="$TMP/run" CFFIXED_USER_HOME="$TMP/profile" \
        POMAROS_TEST_BOOTDIR="$BD" "$A/MacOS/PomAROS" >/dev/null 2>&1
    ck $? "launcher starts bootstrap in the external AROS boot directory"
    [ -x "$A/MacOS/PomAROS" ];                       ck $? "MacOS/PomAROS launcher present + executable"
    [ -f "$A/MacOS/AROSBootstrap" ];              ck $? "MacOS/AROSBootstrap present"
    [ -f "$A/Frameworks/cocoametal.dylib" ];      ck $? "Frameworks/cocoametal.dylib present"
    if [ -f "$PASTEBOARD" ]; then
        [ -f "$A/Frameworks/libpasteboard.dylib" ];    ck $? "Frameworks/libpasteboard.dylib present"
        codesign --verify "$A/Frameworks/libpasteboard.dylib" 2>/dev/null; ck $? "bundled libpasteboard.dylib codesign verifies"
    fi
    if [ -f "$COREAUDIO" ]; then
        [ -f "$A/Frameworks/libcoreaudio.dylib" ];     ck $? "Frameworks/libcoreaudio.dylib present"
        codesign --verify "$A/Frameworks/libcoreaudio.dylib" 2>/dev/null; ck $? "bundled libcoreaudio.dylib codesign verifies"
    fi
    if [ -f "$BSDSOCK" ]; then
        [ -f "$A/Frameworks/libbsdsockhost.dylib" ];    ck $? "Frameworks/libbsdsockhost.dylib present"
        codesign --verify "$A/Frameworks/libbsdsockhost.dylib" 2>/dev/null; ck $? "bundled libbsdsockhost.dylib codesign verifies"
    fi
    if [ -f "$EMU68K" ]; then
        [ -f "$A/Frameworks/libemu68k.dylib" ];       ck $? "Frameworks/libemu68k.dylib present"
        codesign --verify "$A/Frameworks/libemu68k.dylib" 2>/dev/null; ck $? "bundled libemu68k.dylib codesign verifies"
    fi
    [ -f "$A/Frameworks/settings.json" ];         ck $? "Frameworks/settings.json (dladdr-relative)"
    [ -f "$A/Resources/settings.json" ];          ck $? "Resources/settings.json (AROS_SETTINGS_SCHEMA)"
    if [ -f "$ICON" ]; then
        [ -f "$A/Resources/PomAROS.icns" ];        ck $? "Resources/PomAROS.icns present"
        grep -q '<string>PomAROS</string>' "$A/Info.plist"; ck $? "Info.plist CFBundleIconFile = PomAROS"
    fi
    [ -f "$A/MacOS/aros-host-conf.sh" ];          ck $? "MacOS/aros-host-conf.sh present"
    [ -f "$A/Resources/report-env.sh" ];           ck $? "Resources/report-env.sh present"
    grep -q 'AROS_DARWIN_THREADED=1' "$A/MacOS/PomAROS";       ck $? "launcher sets AROS_DARWIN_THREADED"
    grep -q 'AROS_SETTINGS_SCHEMA' "$A/MacOS/PomAROS";         ck $? "launcher points the dylib at the bundled schema"
    grep -q 'aros-host-conf.sh' "$A/MacOS/PomAROS";            ck $? "launcher sources aros-host-conf.sh"
    grep -q 'export POMAROS_VERSION POMAROS_BUILD_NUMBER' "$A/MacOS/PomAROS"; ck $? "launcher passes bundle identity to About"
    codesign --verify "$A/Frameworks/cocoametal.dylib" 2>/dev/null; ck $? "bundled dylib codesign verifies"
    rm -rf "$TMP"
    [ "$fail" = 0 ] && { echo "[APP] PASS structural self-check"; exit 0; } || { echo "[APP] FAIL"; exit 1; }
fi

# --- real build ---
BOOTD="$(find_bootd)"
[ -n "$BOOTD" ] && [ -x "$BOOTD/AROSBootstrap" ] || {
    echo "make-aros-app.sh: no AROSBootstrap found." >&2
    echo "  point AROS_CTL_BOOTD at <build>/bin/darwin-aarch64/AROS/boot/darwin, or build one." >&2
    exit 1; }
AROS_SRC="${AROS_SRC:-$ROOT/../aros-core}" AROS_BUILD="$(cd "$BOOTD/../../../../.." && pwd)" "$HERE/check-core"
[ -f "$DYLIB" ] || { echo "missing $DYLIB — run: make cocoametal-dylib" >&2; exit 1; }
[ -f "$EMU68K" ] || { echo "missing $EMU68K — run: make emu68k-dylib" >&2; exit 1; }
echo ">> boot dir: $BOOTD"
assemble "$BOOTD" "$APP"

# Sign inside-out: dylib ad-hoc, AROSBootstrap with the hardened-runtime entitlements
# (allow-jit / dyld-env / library-validation — see aros-host.entitlements.plist), then
# the bundle. The launcher script execs AROSBootstrap, which carries its own signature.
codesign -s - -f "$APP/Contents/Frameworks/cocoametal.dylib" 2>/dev/null || true
[ -f "$APP/Contents/Frameworks/libpasteboard.dylib" ] && codesign -s - -f "$APP/Contents/Frameworks/libpasteboard.dylib" 2>/dev/null || true
[ -f "$APP/Contents/Frameworks/libcoreaudio.dylib" ] && codesign -s - -f "$APP/Contents/Frameworks/libcoreaudio.dylib" 2>/dev/null || true
[ -f "$APP/Contents/Frameworks/libbsdsockhost.dylib" ] && codesign -s - -f "$APP/Contents/Frameworks/libbsdsockhost.dylib" 2>/dev/null || true
[ -f "$APP/Contents/Frameworks/libemu68k.dylib" ] && codesign -s - -f "$APP/Contents/Frameworks/libemu68k.dylib" 2>/dev/null || true
if [ -f "$ENT" ]; then
    codesign -s - -f -o runtime --entitlements "$ENT" "$APP/Contents/MacOS/AROSBootstrap" 2>/dev/null || true
else
    codesign -s - -f "$APP/Contents/MacOS/AROSBootstrap" 2>/dev/null || true
fi
codesign -s - -f "$APP" 2>/dev/null || true

echo ">> built $APP"
echo ">> open it:  open '$APP'      (or: '$APP/Contents/MacOS/PomAROS' to see stdout)"
