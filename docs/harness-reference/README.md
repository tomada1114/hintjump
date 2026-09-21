# Harness reference snapshot

This directory is a **read-only reference snapshot, not live code**. Nothing here is
built, linted, tested or executed by this repository.

It holds files copied verbatim from the repository whose development harness is being
transplanted into this one, so that every issue under the harness-transplant tracking
issue can cite an in-repo path instead of a path on someone's machine.

| | |
|---|---|
| Source | https://github.com/tomada1114/english-vocab-app |
| Commit | `e3416c87dadfb3abd247f95de69d46a0a12beb40` |
| License | MIT — see [LICENSE](LICENSE) in this directory (the source repository's license) |
| Stack | Next.js / TypeScript / pnpm / vitest / lefthook |

Paths mirror the source repository's layout. One file is renamed: `package.json` is stored
as `package.json.txt` so GitHub's dependency graph does not treat the snapshot as a
manifest of this repository.

## How to use it

Read these files for their **intent and structure**; do not copy their commands. They
are written for a pnpm/TypeScript stack, while this repository is Swift, SwiftPM,
XcodeGen, `just` and `mise`. Each issue names the files it draws on and what must stay
invariant when translating them.

## Lifetime

The directory is temporary. The final issue of the harness transplant deletes it, along
with the `typos.toml` exclusion added for it.
