# PomAROS Hosted internal development candidate

This Apple Silicon application contains the AROS Wanderer desktop, a live system
monitor, host graphics/audio/network/clipboard/file bridges and the 68k runtime.
It is self-contained and does not need the source or development build trees.

Drag PomAROS.app to Applications and open it. It starts in a normal window.
Files in ~/AROS/Shared appear as MacRO: and MacRW:. Preferences and runtime
configuration are stored under ~/Library/Application Support/AROS.

This core-only candidate excludes Zed, Ferail, FFmpeg media applications,
RustHello, gpufx.library, and Moonstone assets. It is for John's internal testing;
public distribution and broader third-party application qualification remain
separate. Consult THIRD-PARTY-NOTICES.md and Licenses for included component
licences and source obligations. Apple notarization status is recorded beside
the final DMG; successful notarization does not establish application coverage.

Source and project information: https://github.com/pomaros and
https://github.com/jonx. Host integration sources are public; the shared AROS checkout remains private.
