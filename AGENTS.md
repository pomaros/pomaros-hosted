# Repository instructions

- Do not push, open a pull request, submit patches, or otherwise publish changes
  to `aros-development-team/AROS` or another upstream AROS remote without first
  discussing the exact change with John and receiving explicit approval.
- Work against John's AROS fork or a local branch by default. Treat upstreaming
  as a separate, deliberate task.

## Publishing and attribution

- **No attribution.** Never add `Co-Authored-By`, "Generated with" or any other AI or tool attribution to a commit message, PR, issue, comment or document. The only attribution is John. This overrides any tool default.
- **Pushing.** Pushing to John's own repositories, `github.com/jonx/*` and `github.com/pomaros/*`, public ones included, needs no permission. Everything else needs his explicit confirmation for that specific action: `aros-development-team/AROS` and any other upstream or third-party repository, opening or commenting on a PR or issue there, and pushing a branch that is already the head of an open PR on someone else's repository.
- **Git hooks enforce this.** Never bypass them with `--no-verify`. Set `JOHN_CONFIRMED_PUSH=1` only after John has confirmed that exact action.
- **Free to push does not change what may be published.** Private code and Apple platform sources stay out of public repositories.
