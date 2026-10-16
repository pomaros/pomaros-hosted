# PomAROS repository boundary

The dedicated [pomaros/pomaros-hosted](https://github.com/pomaros/pomaros-hosted) repository is now
the product and release-integration home. It owns the hosted bridges, graft and
deployment scripts, unattended harness, product documentation, compatibility
policy, packaging, signing workflow, and release notes.

The implementation boundaries are:

- **PomAROS** assembles and tests the product.
- **aros-core** is the shared AROS source checkout consumed by all
  products; `CORE.lock` records the reviewed revision. Hosted reserves x18 and
  builds its Darwin adaptation; native targets use their own platform binaries.
- **AROS-AArch64** is retained as a redirect; its standalone QEMU experiment and
  remaining documentation moved here after the main migration.
- **zed-aros** and **Ferail** own their applications, licences, and source
  histories.

The migration preserved the history of `graft/`, `docs/`, `harness/`, and
`hosted/` by filtering those paths into PomAROS before removing them from
AROS-AArch64. Its original QEMU experiment is retained under
[`docs/hosted/initial-platform-bringup/`](../hosted/initial-platform-bringup/README.md).
Future issues and changes should follow ownership: AROS
source and architecture work goes to the AROS fork, application bugs go to their
application repositories, and assembly experiments, host integration, installer,
or release problems go to PomAROS. AROS-AArch64 receives only its final redirect
before it is archived.

## Next boundary improvement

Today the release builder consumes explicit sibling checkouts and records their
commits and artifact hashes in `BUILD-MANIFEST.txt`. The next useful step is a
checked-in release manifest that pins all input revisions before building. That
will make the unsigned image reproducible without relying on unnamed sibling
state and will give clean Apple Silicon CI one auditable input.

No change is sent to the AROS upstream repository without prior discussion and
John's explicit approval. Upstreaming is a separate, deliberate task, not an
automatic consequence of finishing a PomAROS feature.
