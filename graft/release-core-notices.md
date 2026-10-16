# PomAROS Hosted internal development candidate

This core-only candidate contains the AROS operating system, Wanderer and
standard AROS tools, PomAROS host bridges, and the Emu68-based 68k execution
engine. It excludes Zed, Ferail, FFView/FFViewX, FFmpeg media libraries,
RustHello, gpufx.library, and Moonstone and its proprietary game assets.

AROS contains components under APL 1.1, GPL, LGPL, BSD, MIT, and other licences.
Excluding the optional applications does not remove the source-distribution
obligations of included GPL/LGPL or MPL components. The bundled Licenses
folder retains component notices and full licence texts; notices for excluded
optional applications are reference material and do not imply inclusion.

The Emu68 files are under MPL 2.0, isolated from the surrounding host code.
See Licenses/EMU68-NOTICE and Licenses/MPL-2.0.txt for upstream revision and
file-level provenance. Corresponding source is retained in the PomAROS Hosted
source checkout (hosted/jit68k) and the pinned shared AROS checkout recorded in
BUILD-MANIFEST.txt. Those repositories remain private at this stage.

This candidate is for internal testing by John. It has not been approved for
public redistribution. Before redistribution, provide exact corresponding
source and any required relinking/build materials for every included
copyleft component, and complete the target-specific dependency audit.
Apple system frameworks are loaded from macOS and are not redistributed.
