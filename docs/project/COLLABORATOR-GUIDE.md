# PomAROS collaborator handoff

PomAROS is the product and integration repository for running AROS as a hosted
Apple Silicon Mac application. This is the short orientation for anyone already
working on the project after the repository split.

## Where work belongs

- **PomAROS:** macOS host bridges, `graft/` build and release tools, the
  unattended harness, 68k compatibility integration, packaging, release notes,
  third-party notices, and product documentation.
- **aros-core:** the shared AROS operating-system source checkout,
  including the Darwin adaptation; see `CORE.lock` for the exact input.
- **[zed-aros](https://github.com/jonx/zed-aros):** the AROS port of Zed.
- **[Ferail](https://github.com/jonx/Ferail):** Ferail application work.
- **AROS-AArch64:** archived. It is a redirect and must not receive new work.

The old QEMU `virt` experiment, its source, and the Phase 1/Phase 2 notes are
retained in the
[initial platform bring-up archive](../hosted/initial-platform-bringup/README.md).
It remains useful architecture evidence for new platform ports, but it is not a
plan for booting directly on Apple hardware.

## Non-negotiable technical rules

This product is **hosted under macOS**. macOS owns its hardware-facing
services; AROS reaches them through the host bridges. QEMU, Apple VM, native
Apple Silicon, and Raspberry Pi are separate platform targets of the shared
AROS source. Native work stays private until it is ready.

All AArch64 code built for this target must leave `x18` unused. Apple reserves
it as a platform register, and Darwin signal delivery does not preserve a guest
value there during PomAROS preemption.

- C/C++: use `-ffixed-x18`.
- Rust: use `hosted/rust/aarch64-unknown-aros.json`, which reserves `x18`.
- Assembly: never use `x18`, including as a temporary register.
- Rebuild incompatible precompiled objects; do not assume generic AArch64
  objects are safe.

PomAROS includes the evolving legacy 68k execution layer and the writable exFAT
driver. Changes to either need their focused tests as well as the general hosted
suite.

## Working and release discipline

1. Work in the repository that owns the change and keep sibling source states
   identifiable.
2. Run the focused test while developing, then `make hosted-test` for integration
   changes. Release work also requires the desktop, 68k, exFAT, host-volume, and
   clipboard smoke tests described in [`RELEASE.md`](../../RELEASE.md).
3. The normal public image contains Zed and Ferail. Moonstone is excluded unless
   a private build explicitly sets `POMAROS_INCLUDE_MOONSTONE=1` and supplies its
   binary and assets.
4. Update third-party notices whenever a bundled dependency or source revision
   changes. Every published binary must correspond to clean, publicly available
   source.
5. Build and test an unsigned candidate first. Do not sign, notarize, publish a
   GitHub release, or publish the accompanying blog article until John approves
   the tested candidate.

Most importantly: **do not push, submit patches, or open a pull request against
the AROS upstream project without first discussing the exact action with John
and receiving explicit approval.** Work against John's fork or a local branch by
default. Upstreaming is always a separate decision.

Start with [`README.md`](../../README.md),
[`GETTING-STARTED.md`](../../GETTING-STARTED.md), and
[`RELEASE.md`](../../RELEASE.md); detailed designs and verification evidence
live under [`docs/features/`](../features/README.md).
