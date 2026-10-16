# PomAROS Hosted 0.2.2 preview

This public preview packages the AROS Wanderer desktop and PomAROS host bridges
from the public shared core `89db046157d415e98c05ca18316ca7ae63b07023`.
The application identifies itself as version 0.2.2, build 9. Its source revision,
components and build inputs are recorded in the bundled BUILD-MANIFEST.txt.

This binary preview requires Apple Silicon and macOS 26.0 or newer, matching
the deployment minimum declared by its host libraries. Older macOS versions
are outside this binary preview's qualification.

PomAROS Hosted runs AROS as an AArch64 process under macOS. It opens in a normal
window and uses macOS for graphics, audio, networking, clipboard and shared host
files. The system monitor shows live AROS time, uptime and memory; physical Apple
sensors are unavailable on this target. Files in ~/AROS/Shared are exposed as
MacRO: and MacRW:.

The core profile includes the desktop, standard AROS utilities, the exFAT
handler and the Emu68-based legacy execution engine. It excludes Zed, Ferail,
FFView/FFViewX, FFmpeg media libraries, RustHello, gpufx.library, Moonstone assets
and optional TrueType fonts. Compatibility with arbitrary native and 68k
applications remains incomplete. Automatic system updates are unavailable;
install a newer product distribution to update the system.

The public distribution is built with full Developer ID signatures and hardened
runtime throughout the host layer. Apple submission reports and checksums
accompany the final release artifacts. Notarization establishes Apple's delivery
checks; it does not establish compatibility with every AROS application.

Download matching corresponding-source and build materials from the same
[GitHub release](https://github.com/pomaros/pomaros-hosted/releases/tag/v0.2.2-preview.1).
Use the supplied source assets, including submodules and external components,
rather than assuming GitHub's automatic repository archive contains every input.
Included AROS and Emu68 components retain their original licences and notices.

## Hosted developer ABI

Reserve register `x18` in every component executed inside PomAROS Hosted:
compile C/C++ with `-ffixed-x18`, use the supplied hosted Rust target, and keep
assembly and generated JIT code from computing with that register. Apple
reserves x18 and Darwin signal contexts cannot preserve an arbitrary guest
value there. Rebuild incompatible prebuilt AArch64 AROS objects for this target.
VM and QEMU builds have their own ABI and may use x18 normally.

The earlier 0.2.1 build 8 distribution is a separate artifact with its original
private-core provenance. It is not relabelled or reused by this preview.
