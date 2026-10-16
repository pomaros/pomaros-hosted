---
name: fix-aros-issue
description: >-
  Fix (or triage) an issue from the upstream AROS tracker
  (github.com/aros-development-team/AROS) and ship it as a clean per-issue PR.
  Use when asked to work an AROS issue number, sweep the `app/todo` auto-issues,
  or reproduce/repair an AROS bug on the hosted aarch64-darwin build.
---

# Fixing an upstream AROS issue

One issue -> one PR, each reproduced and verified on the hosted build before it
ships. The work is published as John's, product-neutral, with no AI attribution.

## Non-negotiable rules

- **No Claude/AI mention anywhere, commits included.** No `Co-Authored-By:
  Claude` trailer, no "Generated with" footer. The only attribution is John.
  Commit with `git -c commit.gpgsign=false commit` and write the message
  yourself without a trailer.
- **Comment sparingly, never as changelog.** Add a code comment only for
  non-obvious intent. Do NOT write *why the change was made* or *what it
  replaces* in the code ("use X instead of Y because..."). That rationale goes
  in the PR message / commit message / GitHub comment, not the source.
- **Name no other products or brands** in code, comments, or PR text.
- Plain, concise English. No em-dashes (John is French, non-native).
- **A wrapped-grep "no matches" is not evidence.** The shell `grep` here skips
  non-UTF-8 files silently; a historical AROS audit found many such files. Before
  claiming something is absent, or counting call sites, follow
  [search-evidence](../search-evidence/SKILL.md).

## Repos and trees (see docs/features/build + deployment)

- Shared OS source: public `../aros-core`, branch `main`, repository
  `https://github.com/pomaros/aros-core.git`. `CORE.lock` pins the reviewed source.
  Claim paths and coordinate with its owner before editing this shared checkout.
- Official upstream: remote `upstream` points to
  `https://github.com/aros-development-team/AROS.git`. Use an isolated worktree
  based on the reviewed `upstream/master` revision for upstream patches. Do not
  assume an old sibling worktree or a historical graft branch exists.
- Build tree: `../Build/pomaros-hosted`, or the explicit stable `AROS_BUILD`.
  Reuse the preserved `AROS_CROSSTOOLS`; never rebuild LLVM during a bug fix.
- Validate product changes on a coordinated source commit/pin and owned output
  tree. The official upstream tree does not yet contain every Hosted adaptation;
  describe that validation boundary when preparing a portable upstream patch.
- Read [upstream-pr](../upstream-pr/SKILL.md) before any upstream action.
  Public product/core repository authorization does not authorize an upstream
  PR, comment, or update to an upstream PR branch. Follow CLAUDE.md's gate.

## Workflow

1. **Triage — is it ours to fix?**
   - In-tree? Contrib apps are NOT in this repo (Scout, MUI 5, ...). If the fix
     lives in AROS-contrib, it's out.
   - Our platform? We build/run aarch64-darwin hosted. Out of reach: m68k /
     Vampire, SMP, x86 install/boot, X11/SDL, native-GPU drivers (nouveau, ata,
     ahci, intelgma...).
   - Already resolved? Grep the TODO text or symptom **tree-wide** in
     the isolated official upstream worktree (not just the original path). Watch for
     renames/moves: a file can be renamed and the TODO travel with it, so a
     missing-at-old-path result is NOT proof it's gone.
2. **Reproduce** on the hosted build with `graft/aros-ctl` (run / wait / type /
   enter / shot). Ground the bug in an observed artifact before touching code.
3. **Root-cause** in the source. Read the actual code path; do not guess.
4. **Fix** in a coordinated `aros-core` feature worktree (minimal change).
   Commit and review the source pin before using guarded product build scripts.
5. **Build** the specific metatarget in `~/Source/aros-project/Build/pomaros-hosted`
   (`PATH=~/Source/aros-project/aros-crosstools/bin:$PATH; make <metatarget>`). Never a bare `make`.
   Find the metatarget name in the module's `mmakefile.src` (`mmake=...`).
6. **Verify**: `aros-ctl deploy` -> `run` -> drive the repro -> `shot`. Test
   every affected case for a behaviour change. For high-blast-radius code
   (console write path, exec, dos), also confirm no regression to normal use.
7. **Prepare the upstream patch** in an isolated worktree based on
   `upstream/master`. Port the verified change with upstream anchors and record
   any contextual differences. Preserve the shared source checkout, its commits,
   and every unrelated working change; do not revert a shared tree as cleanup.
8. **Request the required upstream approval** with the exact patch, validation
   and proposed PR text. After approval, push the dedicated branch to the public
   `pomaros/aros-core` fork and open the authorized PR against
   `aros-development-team/AROS`, base `master`, head `pomaros:<branch>`.
   The PR body ends with `Fixes #<n>`.

## Triage-only outcomes (we are not maintainers, cannot close issues)

- After upstream-comment approval, already fixed: comment "the TODO is no longer present in `<file>` on current
  master ... can be closed as resolved."
- After upstream-comment approval, moved: comment where it now lives ("renamed to `<file>:<line>`").
- Not our call (needs a design decision or a big refactor): prepare the root-cause
  analysis and proposed approach for review before any upstream comment.

## Gotchas learned

- `aros-ctl type` drops `>` (the shell redirect char). To test redirection,
  write a script file host-side into `SYS:` (= `~/Source/aros-project/Build/pomaros-hosted/bin/darwin-aarch64/
  AROS/`) and `execute` it, or craft a file and `type`/`execute` it.
- `Type` flushes in 8192-byte writes, so a byte placed at file offset 8191
  reliably splits across two `Write()`s (useful for split-sequence repros).
- The `app/todo` bot auto-files an issue per `TODO` comment on merge; the issue
  URL pins the commit it was filed at, so it looks live even after the code
  moved. Most are stale.
- If John is rebuilding in parallel, avoid concurrent `make` in `~/Source/aros-project/Build/pomaros-hosted`
  (shared mmake DB) unless told it's fine; the single hosted instance is shared
  too (reboot to run-verify only when free).
- When the touched file differs between the public product core and upstream:
  implement and verify on the coordinated product worktree, then port to the PR branch with
  upstream anchors, and prove equivalence by diffing the added lines of both
  patches (`git diff | grep '^+'` on each side must match).
- SYS: is the live host dir `~/Source/aros-project/Build/pomaros-hosted/bin/darwin-aarch64/AROS/` -- files
  written there (test binaries, scripts) are visible to the RUNNING instance
  immediately, while in-memory handlers/modules stay old until reboot. Useful
  to repro a bug on the old module with a fresh test binary.
- `CLAUDE.md` is tracked here and owns the current source and publication rules.
