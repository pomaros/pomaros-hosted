# PomAROS Hosted distribution

`graft/make-aros-release.sh` defaults to the `core` profile: a self-contained
AROS desktop, system monitor and host bridges. Zed, Ferail, FFmpeg media apps,
RustHello, gpufx.library and proprietary Moonstone assets are excluded.
`POMAROS_RELEASE_PROFILE=complete` retains the optional application recipe;
its corresponding source and dependency audits must be completed separately.

Core AROS still includes GPL/LGPL components, and Emu68 sources are MPL 2.0.
The core profile does not remove their corresponding-source obligations.
These candidates are internal development distributions for John. Before public
redistribution, provide the exact source/build/relinking materials required for
all included components and complete the component audit. Private native Apple
hardware implementation and history remain outside the public core.

Read the [build](docs/features/build/README.md) and
[deployment](docs/features/deployment/README.md) guides before rebuilding.
Build host libraries and the named shared core revision, then complete a
windowed desktop boot. Preserve development apps by selecting separate outputs:

```sh
export AROS_APP="$PWD/build/distribution/PomAROS.app"
export AROS_DMG="$PWD/build/distribution/PomAROS-Hosted.dmg"
export AROS_DMG_STAGE="$PWD/build/distribution/dmg-root"
POMAROS_REQUIRE_CLEAN_SOURCES=1 graft/make-aros-release.sh
graft/make-aros-release.sh --check
export POMAROS_SIGN_IDENTITY='Developer ID Application: John Knipper (C43N3NG7Z5)'
export POMAROS_SIGN_SCOPE=full
graft/sign-pomaros-release.sh --sign-only
```

The bundle executable is native Mach-O; its bundled shell launcher expands
only bundle-relative module paths into a writable per-user configuration.
Every host executable and dylib must be Developer ID signed with hardened
runtime. The current shared core starts and shuts down under that policy;
the old bootstrap warning is no longer an observed blocker. Verify the exact
signed app in an isolated profile, windowed, after relocation outside the source
tree; verify the complete signature again after runtime. Retain those logs.

Create the DMG from that qualified app, sign it, submit it to Apple with the
Keychain profile `D4Mac`, record the JSON submission ID, inspect its result,
and staple/validate the app and final DMG. Apple uploads are separate from
GitHub release publication. Avoid one long blocking wait: use `notarytool
submit --output-format json`, then bounded `info` calls. For the combined
script workflow, `graft/sign-pomaros-release.sh --notarize` submits both app
and DMG, but its blocking waits should be monitored by the release operator.

Keep VERSION, clean source revisions, BUILD-MANIFEST.txt, exact component
notices, build/runtime logs, checksums and Apple submission reports with the
candidate. A notarized binary is not proof of general app compatibility.
Do not upload a GitHub Release without separate authorization.

The existing notarized build 8 records the earlier private core revision
`9f346ab00d644bd40e0f53e2624c3f625d28f182`. Keep that signed manifest, its
checksums and Apple tickets unchanged. Adopting a new public CORE.lock revision
selects a new source input for future builds; it does not retag those binaries
or establish a byte-identical rebuild of their original toolchain.
