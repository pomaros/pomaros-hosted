# PomAROS Hosted 0.2.2 preview

This Apple Silicon application contains the AROS Wanderer desktop, a live system
monitor, host graphics/audio/network/clipboard/file bridges and the 68k runtime.
It is self-contained and does not need the source or development build trees.

This preview requires an Apple Silicon Mac running macOS 26.0 or newer.
The bundled host libraries declare that deployment minimum; older macOS
versions have not been qualified for this binary distribution.

Drag PomAROS.app to Applications and open it. It starts in a normal window.
Files in ~/AROS/Shared appear as MacRO: and MacRW:. Preferences and runtime
configuration are stored under ~/Library/Application Support/AROS.

This core-only candidate excludes Zed, Ferail, FFmpeg media applications,
RustHello, gpufx.library, Moonstone assets and optional TrueType fonts.
Native and 68k application compatibility is still incomplete. Consult THIRD-PARTY-NOTICES.md and Licenses for included component
licences and source obligations. Apple notarization status is recorded beside
the final DMG; successful notarization does not establish application coverage.

Source and project information: https://github.com/pomaros and
https://github.com/jonx. Host integration and the shared operating-system sources are public; see
https://github.com/pomaros/aros-core. Native hardware work remains separate.

Matching corresponding-source and build materials accompany the public release:
https://github.com/pomaros/pomaros-hosted/releases/tag/v0.2.2-preview.1.
See BUILD-MANIFEST.txt in the application documentation for exact input revisions.
