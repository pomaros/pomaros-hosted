# LLVM compiler-rt builtins

PomAROS Hosted links LLVM compiler-rt 20.1.0 builtins into its AROS runtime
components. The exact upstream licence, including LLVM exceptions and legacy
terms, is retained verbatim in LLVM-COMPILER-RT-LICENSE.txt.

Source: https://github.com/llvm/llvm-project/releases/tag/llvmorg-20.1.0

Official compiler-rt archive SHA-256:
`85798479b6762433a6fc8a87f4cbdb1dc050926220a8240d9e0e126f08e6f25f`.

The public product script `graft/build-hosted-runtime` records the source hashes
and reproducible configuration. It omits enable_execute_stack.c, disables
AArch64 function multi-versioning, and reserves x18 for the Darwin hosted ABI.
The LLVM compiler prefix is unchanged; this is a separate hosted runtime build.
Matching source archives and this build script accompany the public release.
