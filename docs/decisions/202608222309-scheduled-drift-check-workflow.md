# ADR-202608222309: Watch PlasmaZones, PowerShell, KWin skew, and Fedora currency with a scheduled workflow that files an issue

- **Status:** Accepted
- **Date:** 2026-08-22
- **Scope:** repo
- **Shipped in:** the PR closing part of #19

## The question

#19 asked for the Maintenance Watchlist's silent-drift items to surface as
issues in this tracker instead of relying on someone remembering to check. It
sketched two non-exclusive mechanisms: a scheduled job that files issues, and
Renovate `customManagers` regex tracking for the version pins. Which to build
first, and what should the scheduled job actually watch?

## What we chose

**A weekly GitHub Actions workflow (`drift-check.yml`) that runs
`.github/scripts/check-drift.sh` and files or updates a single
`drift-watch`-labeled issue when it finds something**, covering four watch
items:

- **PlasmaZones** — pinned `PLASMAZONES_VERSION` vs. the latest GitHub release.
- **PowerShell** — pinned `PWSH_VERSION` vs. the latest GitHub release.
- **PlasmaZones/KWin skew** — pulls the pinned base image and the pinned
  PlasmaZones RPM directly (no full `just build`) and runs the same
  X.Y-series regex comparison `build_files/build.sh` already does at build
  time, so the warning that currently only shows up in a build log surfaces
  as an issue instead.
- **Base Fedora currency** — compares the `Containerfile`'s pinned
  `stable-<NN>` major against what the floating `stable` tag currently
  resolves to (via `skopeo inspect`), i.e. whether a `stable-45` bump is due.

**PowerShell is watched here even though
[ADR-0015](0015-update-cadence-tiers.md) assigns it a different long-term
mechanism** — a PR-gated Renovate `customManagers` bump (option 2 from #19).
That Renovate manager is separate follow-up work, not yet built. Until it
lands, `PWSH_VERSION` would otherwise have no drift signal at all, so this
watcher covers it in the meantime. The two mechanisms aren't a conflict: an
issue here says "look at this," a Renovate PR would say "here's the bump
already made" — once Renovate is watching `PWSH_VERSION`, drop it from this
script rather than run both (see *What would change our mind*).

**Template drift** (comment on #19, and
[ADR-202608042137](202608042137-no-automated-template-sync.md)) is also left
out here. It's a structurally different check — diffing this repo's tree
against `ublue-os/image-template`'s, not comparing a version number — and
worth its own pass rather than bolting onto a version-pin script.

Filing (rather than just logging in Actions output) matters because CLAUDE.md
is explicit that Issues are the only place open work lives — a green Actions
run nobody reads isn't drift detection, it's a check nobody sees.

## What we turned down

| Option | Why not |
|---|---|
| Renovate `customManagers` for `PLASMAZONES_VERSION` too | ADR-0015 already decided PlasmaZones stays a **manual** bump (active/breaking upstream, KWin coupling); an auto-PR would often be one nobody should merge yet. It still needs *watching* (this PR), just not auto-bumping. |
| Leave `PWSH_VERSION` out until Renovate is built | Would mean months of zero drift signal on a pin ADR-0015 itself calls "high value (used daily)" while the Renovate manager sits unbuilt. Watching it here now, and dropping it once Renovate lands, costs one extra `check_pinned_version` call. |
| One script that also diffs `image-template` | Different shape of check (tree diff vs. version compare) and different noise profile (see the file-by-file table in the #19 comment). Folding it in now would make the script's one job two jobs. |
| Run the KWin-skew check via a full `just build` | The whole point is catching skew *before* a build, and a full build is the expensive path the watchlist explicitly says a `WARNING` already exists inside. Pulling the base image + the RPM directly and re-running the same comparison is materially cheaper and needs no image push. |
| Fail the Actions job on drift | Drift isn't a bug in this commit — failing a schedule-triggered run just produces a red workflow nobody is looking at. An issue is the correct-shaped signal; the script always exits 0. |

## What would change our mind

- **If the Renovate `customManagers` PR lands** for `PWSH_VERSION`, drop the
  PowerShell `check_pinned_version` call from `check-drift.sh` — Renovate's PR
  is a strictly better signal than an issue for the same pin.
- **If PlasmaZones stabilizes** enough that ADR-0015 promotes it to a
  Renovate-managed pin, drop the PlasmaZones version check from this script
  (the KWin-skew check stays; skew is a base-image relationship, not a
  version feed, and Renovate can't express it).
- **If the `drift-watch` issue starts flapping** (opened and closed
  repeatedly for the same transient mismatch) — tighten the comparison
  (e.g. only flag Fedora currency after the `stable` tag has been ahead for
  more than a few days) rather than disabling the check.
- **If template-drift detection is added later**, it likely deserves its own
  script and its own section of this same workflow, not a rewrite of this one
  — see the file-by-file guidance already recorded on #19.
