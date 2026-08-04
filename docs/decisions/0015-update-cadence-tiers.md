# ADR-0015: Tier update cadence by value × breakage risk, not one rule for everything

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** repo
- **Shipped in:** #18 (base-image provenance stamping); cadence tiers are policy

## The question

The image carries several things that move at very different rates and matter
very differently: the base OS, PowerShell, PlasmaZones, Discord. When #18 asked
to make the base↔output link legible, the natural-looking fix was to digest-pin
the base `FROM` and let Renovate open a PR on every change — the same push-based
model #19 proposes for the content pins. That would apply *one* update rule to
everything. Should we?

## What we chose

No — cadence is tiered by **how valuable/security-critical a thing is** against
**how often it breaks and how often it releases**. Three tiers:

- **Auto, always-latest, no gate — the base OS.** `Containerfile` stays pinned
  to the floating `bazzite-dx:stable-44` (Fedora-versioned per ADR-0003) and
  the daily cron rebuilds with `--pull=newer`. The base is the highest-security,
  highest-value layer and it self-validates (a broken base breaks the build).
  It must always be as current as possible, so it gets **no** review gate.
- **PR-automated bump — PowerShell (`PWSH_VERSION`).** High value (used daily),
  low breakage risk, infrequent releases. Worth pulling in promptly but cheap
  and safe to review, so a Renovate custom-manager PR (#19) is the right gate:
  automated, but a human clicks merge.
- **Manual bump on demand — PlasmaZones (`PLASMAZONES_VERSION`).** A nice-to-have
  KWin extension in active, breaking development, tied to the base's KWin
  version (see the Watchlist skew warning). Frequent forced updates would be
  pure churn, so it is bumped by hand when wanted — not automated at all.

Discord is a fourth, separate case already recorded in ADR-0009: unpinned
"latest" like the base, but forced by upstream *gating* rather than by a
security/value judgment.

The governing principle: **automate what is high-value and low-risk; gate or
defer what breaks often or is merely nice to have.** The base earns *no* gate
because it is both critical and self-validating; PlasmaZones earns *no*
automation because it is neither.

What makes the unpinned base safe to reconcile after the fact is the #18
provenance stamping: each output image now carries
`org.opencontainers.image.base.name` / `.base.digest` and the base's version
string as labels, so "which Bazzite did `latest-<date>-<sha>` come from?" is a
`skopeo inspect` lookup. Reconciliation without pinning — which is the whole
reason pinning isn't needed here.

## What we turned down

| Option | Why not |
|---|---|
| Digest-pin the base `FROM` + Renovate PR per change | Bazzite moves ~daily, so this means a **daily bump PR** — pure noise — and worse, it puts base **security** updates behind a manual merge. The base is exactly the layer that should *not* wait on a human. |
| One uniform auto-update policy for everything | Ignores that PlasmaZones breaks often (churn) and the base is security-critical (can't wait). Same rule, wrong outcome at both ends. |
| Auto-bump PlasmaZones like PowerShell | Active/breaking upstream + KWin coupling means frequent auto-PRs that often shouldn't merge; the maintainer wants to choose the moment. |

## What would change our mind

- **PowerShell's breakage profile worsens** (a run of releases that break the
  image) — demote it from PR-auto toward manual, like PlasmaZones.
- **PlasmaZones stabilizes** (releases stop breaking, KWin coupling loosens) —
  promote it to PR-auto.
- **The base starts shipping breaking changes often enough** that silent daily
  tracking becomes risky — reintroduce a gate (e.g. digest-pin + a *low
  frequency* bump), accepting the noise as the price of safety. Today the #18
  labels give after-the-fact reconciliation, which is why no gate is needed.
