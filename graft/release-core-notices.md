# PomAROS Hosted public core preview

This core-only candidate contains the AROS operating system, Wanderer and
standard AROS tools, PomAROS host bridges, and the Emu68-based 68k execution
engine. It excludes Zed, Ferail, FFView/FFViewX, FFmpeg media libraries,
RustHello, gpufx.library, Moonstone and its proprietary game assets, and
optional TrueType fonts.

AROS contains components under APL 1.1, GPL, LGPL, BSD, MIT, and other licences.
Excluding the optional applications does not remove the source-distribution
obligations of included GPL/LGPL or MPL components. The bundled Licenses
folder retains component notices and full licence texts; notices for excluded
optional applications are reference material and do not imply inclusion.

The Emu68 files are under MPL 2.0, isolated from the surrounding host code.
See Licenses/EMU68-NOTICE and Licenses/MPL-2.0.txt for upstream revision and
file-level provenance. Corresponding source is retained in the PomAROS Hosted
source checkout (hosted/jit68k) and the pinned shared AROS checkout recorded in
BUILD-MANIFEST.txt. The host and Emu68 integration sources are public at
https://github.com/pomaros/pomaros-hosted. The shared operating-system source is public at
https://github.com/pomaros/aros-core, at the exact revision recorded in the
build manifest. Native Apple hardware work is excluded from that repository.

Matching corresponding-source assets and build materials accompany the public
preview at https://github.com/pomaros/pomaros-hosted/releases/tag/v0.2.2-preview.1.
Use the exact revisions recorded in BUILD-MANIFEST.txt. The supplied release
source assets include the necessary submodules and external-source materials;
GitHub's automatic product repository archive alone is not the complete source
closure. Refer to the component licence texts for their respective terms.
The five standard bitmap font families (XEN, arial, fixed, stop and ttcourier)
come from the public core workbench/fonts tree, retaining its LEGAL/default APL
provenance. Optional outline font families are excluded from this profile.

LLVM compiler-rt 20.1.0 builtins are linked into the AROS runtime components.
See Licenses/LLVM-COMPILER-RT-NOTICE.md and the verbatim
Licenses/LLVM-COMPILER-RT-LICENSE.txt for their source and licence terms.

Apple system frameworks are loaded from macOS and are not redistributed.
