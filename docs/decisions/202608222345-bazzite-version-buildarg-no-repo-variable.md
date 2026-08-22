# ADR-202608222345: Parameterize the Bazzite Fedora-version pin as a build arg, not a repo variable

- **Status:** Accepted
- **Date:** 2026-08-22
- **Scope:** repo
- **Shipped in:** the PR adding `BAZZITE_VERSION` to `Containerfile`

## The question

`Containerfile`'s `FROM ghcr.io/ublue-os/bazzite-dx:stable-44` hardcoded the
Fedora major version directly in the `FROM` line. Testing a candidate bump
(e.g. `stable-45`) meant hand-editing that line, same as `PWSH_VERSION` /
`PLASMAZONES_VERSION` before they became build args. Should the Fedora
version get the same treatment — and if so, should it also get the same
CI-side repo-variable override those two have (`vars.PWSH_VERSION` in
`build.yml`)?

## What we chose

**Parameterize it as a `Containerfile` `ARG BAZZITE_VERSION=44`** (declared
before the first `FROM`, so it's usable in the base image's `FROM` line) and
forward it as a `--build-arg` from `just build` when the `BAZZITE_VERSION`
env var is set — mechanically identical to `PWSH_VERSION`/`PLASMAZONES_VERSION`.
This gets you `BAZZITE_VERSION=45 just build ...` to test-build against a
candidate Fedora bump without editing the file.

**No `BAZZITE_VERSION` repo variable, and `build.yml` never sets this env
var.** The default in `Containerfile` remains the actual pin, and bumping it
stays a reviewed Containerfile edit — the same "Bumping the Fedora version"
4-step process in `docs/README.md` (confirm PlasmaZones has a matching `.fc<NN>`
asset, verify the candidate tag really is that Fedora version, rebuild
locally, only merge once checks pass) applies exactly as before. This is
deliberate, not an oversight: **ADR-0003** pins to a Fedora-versioned tag
specifically so a Fedora bump only happens when someone chooses to make it,
and **ADR-0015** already drew the line between "auto, no gate" (the base
image *within* its pinned Fedora version — daily `--pull=newer`) and
"PR-gated" (PowerShell) versus "manual, no automation at all" — the Fedora
*major version itself* was never a candidate for automation in any of those
tiers; it's the thing the whole pinning scheme exists to gate. A repo
variable that `build.yml`'s daily cron reads would let that gate be bypassed
by flipping a GitHub Settings value, with none of the 4-step verification.

The `Justfile`'s `just build` recipe already parsed the literal `FROM` line
text to resolve the base image for pulling/inspecting/labeling (issue #18's
provenance stamping). Parameterizing the `FROM` line meant that parse would
capture the literal, unexpanded `${BAZZITE_VERSION}` string instead of a real
tag — fixed by resolving the same value the build itself uses (the override
if set, else `Containerfile`'s own `ARG` default) and substituting it into
the parsed template before pulling.

## What we turned down

| Option | Why not |
|---|---|
| Full repo-variable override, same mechanism as `PWSH_VERSION` | Would let the daily scheduled build silently move to a new Fedora major version with no PR, no review, and no run of the 4-step "Bumping the Fedora version" checklist — the exact failure ADR-0003 exists to prevent (an unannounced Fedora bump landing before PlasmaZones has a matching `.fc<NN>` build). |
| Leave the `FROM` line hardcoded, no override at all | Testing a candidate bump before committing to it meant hand-editing `Containerfile`, test-building, then remembering to either keep or revert the edit — an override flag is strictly more convenient with no downside once it's build-arg-only. |
| Have `check-drift.sh`'s Fedora-currency check also *file the bump* (open a PR) instead of just an issue | Out of scope here and a bigger call — the drift watcher (ADR-202608222309) deliberately only notifies for exactly this reason; a bot-opened Containerfile PR would still need the same local-rebuild verification a human does, so auto-opening it buys little over the current issue. |

## What would change our mind

- **If the 4-step manual-bump process is ever fully automated** (e.g. a CI
  job that itself confirms the PlasmaZones asset exists and rebuilds/verifies
  before opening a PR) — a repo-variable-driven PR-gated flow like
  PowerShell's would then be consistent, and worth revisiting.
- **If ADR-0003's Fedora-version pinning is itself reconsidered** — this
  record's reasoning inherits directly from that one; a change there flows
  through here.
