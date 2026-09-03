# Agent Instructions for the blueprint bootc Image Builder

## Start here

Task-specific instructions are Agent Skills under
`.agents/skills/<skill-name>/SKILL.md`. Agents discover them automatically from
their descriptions. Use the matching skill before changing behavior; for an
unfamiliar multi-phase task, start with `blueprint-overview`, continue with the
domain skill, and finish with `blueprint-pr-checklist`. Not sure which skill
fits? Load `blueprint-router` — it owns the routing table. The skill index with
links lives in `.agents/skills/README.md`.

`blueprint` is a **personal, multi-image bootc builder** owned by
`huntedraven7`. It is not a fork-this-template project: there is one repository
that builds a set of image variants — `arch`, `debian`, `ubuntu`, `opensuse`,
`gentoo`, `nixos`, `robin`, `holo-amd`, `holo-nvidia` (all from a single unified root
`Containerfile`, with identity inlined in the `Justfile` `build` recipe `case`
arms) plus `fsdk` (built with BuildStream) — and three promoted base images
(`arch-bootc`, `debian-bootc`, `opensuse-bootc`). The `Justfile` is the single
build entrypoint.

## Branch Strategy

- `main` is the **only** branch. There is no `stable` branch. Everything —
  features, fixes, Renovate bumps, promotion PRs — targets `main`.
- Promotion happens at the **registry tag level**, not the git level. Base
  images publish `:testing` on a schedule; a promotion PR pins the approved
  `:testing` digest in `image-versions.yaml`, and merging it re-tags that exact
  digest as `:stable`.
- Variant images publish under their own tag on
  `ghcr.io/huntedraven7/blueprint` (`:arch`, `:debian`, `:ubuntu`, `:opensuse`,
  `:gentoo`, `:nixos`, `:robin`, `:holo-amd`, `:holo-nvidia`, `:fsdk`) plus
  `-<date>` / `-<sha>` alias tags.
- Base images publish under their own repository:
  `ghcr.io/huntedraven7/arch-bootc`, `debian-bootc`, `opensuse-bootc`.
- Never push directly to `main` without a PR that passes CI.

## Release Workflow

Base images (`arch`, `debian`, `opensuse`) use a digest-pin promotion:

1. `build-<base>.yml` runs on a schedule and publishes
   `ghcr.io/huntedraven7/<base>-bootc:testing`.
2. Test the `:testing` image (`just build-qcow2`, `just run-vm-qcow2`, or
   `bootc switch`).
3. Run `promote-<base>.yml` (manual dispatch; `promote-opensuse.yml` also runs
   monthly). It reads the current `:testing` digest with `skopeo inspect`,
   opens a branch `promote/<base>-stable-<digest12>`, pins the digest in
   `image-versions.yaml`, and opens a PR labeled `promote` against `main`.
4. Review and merge that PR.
5. `tag-<base>-stable.yml` fires on the merged PR, pulls the pinned digest,
   re-tags it `:stable`, pushes, and cosign-signs it.

| Image kind                              | Tag         | Audience                                     |
| --------------------------------------- | ----------- | -------------------------------------------- |
| `arch-bootc` / `debian-bootc` / `opensuse-bootc` | `:testing`  | Testing; rebuilt on a schedule               |
| `arch-bootc` / `debian-bootc` / `opensuse-bootc` | `:stable`   | Consumed by downstream variants (e.g. holo)  |
| `blueprint`                             | `:<variant>` | The variant's current build                  |

Downstream variants consume the promoted base: `holo-amd` / `holo-nvidia`
build `FROM arch-bootc:stable`. `robin` builds `FROM arch-bootc:testing`.
Promoting a broken base breaks every downstream variant, so step 2 is not optional.

## CRITICAL: External Repository Research

**Use the GitHub API, not scraping**, when researching an upstream this repo
depends on (`projectbluefin/actions`, `projectbluefin/bluefin-lts`,
`ublue-os/ucore`, `ublue-os/bazzite`, `osbuild/bootc-image-builder`,
`coreos/chunkah`, `freedesktop-sdk`). Prefer a GitHub MCP file-contents tool or
`gh api`; do not `curl`/`wget` raw pages. This keeps access authenticated,
consistent, and rate-limit friendly.

## CRITICAL: Pre-Commit Checklist

**Execute before EVERY commit:**

1. **Conventional Commits** — ALL commits MUST follow conventional commit format (see below)
2. **Just validation** — `just check` (runs `just --unstable --fmt --check` on the `Justfile` and every `*.just`)
3. **Shellcheck** — `just lint`, or `shellcheck <file>` on each modified shell script
4. **shfmt** — `shfmt -d <file>` on modified shell scripts (`just format` writes fixes)
5. **YAML validation** — `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"` on all modified YAML
6. **actionlint** — `actionlint .github/workflows/*.yml` when workflows changed
7. **Confirm with user** — always confirm before committing and pushing

**Never commit files with syntax errors.**

### REQUIRED: Conventional Commit Format

**ALL commits MUST use conventional commits format**

```
<type>[optional scope]: <description>
```

Valid types: `feat`, `fix`, `docs`, `chore`, `build`, `ci`, `refactor`, `test`.
Promotion commits use the `promote:` prefix produced by the promote workflows —
do not hand-write them.

## PR Comment Policy

**One comment per PR event, max.** Combine all findings into a single comment. Never post a follow-up comment for a new observation — edit the existing one instead.

**Never duplicate GitHub UI state.** Do not post approval counts, merge queue status, or CI pass/fail summaries — GitHub already surfaces these natively in the PR timeline.

**Test reports: minimal.** Report what ran, pass/fail, and blockers only. No diff summaries. No tables unless comparing ≥3 divergent approaches that require a human decision.

**@ mentions in context only.** Only ping someone if asking them to do something specific. Always inside the combined comment — never as a standalone comment.

**When in doubt, don't post.** If the only thing to report is "tests pass", post nothing.

## Critical Rules (Enforced)

1. **ALWAYS** use Conventional Commits format for ALL commits
2. **NEVER** commit `cosign.key` (it is `.gitignore`-d) or any `SIGNING_SECRET` value; `cosign.pub` is the only key material in-tree
3. **ALWAYS** run `just check`, `just lint`, and YAML validation before committing
4. **NEVER** push directly to `main` without a PR whose CI (`build.yml`, `zizmor.yml`) passes
5. **ALWAYS** add a new variant as an inline `case` arm in the `Justfile` `build` recipe (hardcoded identity plus a `build_files/` script and a build workflow if not already in a matrix) — there is no per-variant `Containerfile` or `images/*.env`; every variant builds from the unified root `Containerfile`. For a new **base** image, add the same inline `case` arm plus `promote-<base>.yml` + `tag-<base>-stable.yml`
6. **NEVER** reuse a `DEFAULT_TAG` across two variants — all `blueprint` variants share one registry repository, so a duplicate tag silently overwrites another image
7. **NEVER** reintroduce a shared `images/*.env` `dotenv-filename` or a per-variant `containerfiles/Containerfile.<variant>` — all variant identity is inline in the `Justfile` `build` recipe `case` arms (the old primary env file is retired)
8. **ALWAYS** use the variant's native package manager (`pacman`, `apt-get`, `zypper`, `dnf5`, `emerge`, `nix-env`, BuildStream elements) — never mix managers inside one variant
9. **ALWAYS** copy `system_files/global` **before** the per-variant overlay so variant files win
10. **ALWAYS** let Renovate bump pinned digests (`image-versions.yaml`, action SHAs); do not hand-edit them
11. **NEVER** hand-edit a promoted `:stable` digest in `image-versions.yaml` — use `promote-<base>.yml`
12. **ALWAYS** test a base image's `:testing` tag before promoting it to `:stable`; `holo-amd`/`holo-nvidia` build `FROM arch-bootc:stable`, `robin` builds `FROM arch-bootc:testing`
13. **ALWAYS** keep `RUN bootc container lint` in Containerfiles that already have it
14. **NEVER** modify `.github/workflows/*` without running `actionlint` and considering `zizmor.yml`
15. **ALWAYS** confirm with the user before deviating from upstream @ublue-os / @projectbluefin patterns

## Analysis vs Implementation

**Answer first, implement when asked.** Provide analysis before making changes. Don't implement unless explicitly asked.

## Attribution Requirements

AI agents must disclose what tool and model they are using in the "Assisted-by" commit footer:

```text
Assisted-by: [Model Name] via [Tool Name]
```

---

## Ownership boundaries

This is a personal repository. Agents work only on `huntedraven7/blueprint`.
Never write to `ublue-os/*`, `projectbluefin/*`, `freedesktop-sdk/*`, or any
other upstream — if a fix belongs upstream, describe it and let a human open
the upstream PR. Keep blueprint-specific knowledge in `.agents/skills/`.

## Self-Improvement

Every session: ship the work and update the relevant skill file in
`.agents/skills/`. Same PR, not a follow-up.

Banned:
- No changelog files. Delete `IMPROVEMENTS.md`, `CHANGELOG.md`, and
  `SESSION.md` if found.
- No session notes committed to the repository.
- No "append here" documentation. Route durable learning to `.agents/skills/`.

Before marking work done:
- [ ] Discovered a workaround, pattern, or convention?
- [ ] Updated or created the relevant skill file?
- [ ] Included that learning in this PR?

**Last Updated**: 2026-09-03
**Repository**: huntedraven7/blueprint (personal multi-image bootc builder)
**Maintainer**: huntedraven7
