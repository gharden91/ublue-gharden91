# ADR-202608222309: Watch PlasmaZones, PowerShell, KWin skew, Fedora currency, and template drift with a scheduled workflow that files an issue

- **Status:** Accepted
- **Date:** 2026-08-22
- **Scope:** repo
- **Shipped in:** the PR closing #19

## The question

#19 asked for the Maintenance Watchlist's silent-drift items to surface as
issues in this tracker instead of relying on someone remembering to check. It
sketched two non-exclusive mechanisms: a scheduled job that files issues, and
Renovate `customManagers` regex tracking for the version pins. Which to build
first, and what should the scheduled job actually watch?

## What we chose

**A weekly GitHub Actions workflow (`drift-check.yml`) that runs
`.github/scripts/check-drift.sh` and files or updates a single
`drift-watch`-labeled issue when it finds something**, covering five watch
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
- **Template drift** — whether `ublue-os/image-template` has touched, since a
  recorded baseline commit, any of the files this repo forked from it and now
  maintains by hand (`.github/workflows/build.yml`, `.github/workflows/build-disk.yml`,
  `Justfile`, `Containerfile`, `build_files/build.sh`, `disk_config/`).

**PowerShell is watched here even though
[ADR-0015](0015-update-cadence-tiers.md) assigns it a different long-term
mechanism** — a PR-gated Renovate `customManagers` bump (option 2 from #19).
That Renovate manager is separate follow-up work, not yet built. Until it
lands, `PWSH_VERSION` would otherwise have no drift signal at all, so this
watcher covers it in the meantime. The two mechanisms aren't a conflict: an
issue here says "look at this," a Renovate PR would say "here's the bump
already made" — once Renovate is watching `PWSH_VERSION`, drop it from this
script rather than run both (see *What would change our mind*).

**Template drift is a commit-range check, not a content diff.** The naive
version — diff our tree against the template's — is what ADR-202608042137
already ruled out for *merging*: unrelated histories, and (per that record's
finding 2) huge, permanently-noisy hunks because we've diverged on purpose.
What this check actually does instead: track a baseline commit SHA
(`.github/template-drift-baseline`) for the template repo, and on each run
ask only "has anything under the watched paths changed in the template's own
history since that baseline?" — via `git diff --name-only <baseline>
<head> -- <watched paths>` inside a throwaway clone of the template. That's
cheap, has no unrelated-history problem (it's the template diffing against
itself), and produces exactly the signal ADR-202608042137 asked #19 to
provide: "the template changed something in these files, go read it." A
human still applies the ignore-table judgment from that record and the #19
comment (dependency bumps vs. behavioral changes) — the check's job is
"did anything change," not "is it worth porting." The baseline file is
advanced by hand once a human has reviewed the range (ported or
consciously skipped) — the same pattern as bumping `PLASMAZONES_VERSION`
after acting on a PlasmaZones drift report, so the issue doesn't just
silently stop being true out from under the tracker.

Filing (rather than just logging in Actions output) matters because CLAUDE.md
is explicit that Issues are the only place open work lives — a green Actions
run nobody reads isn't drift detection, it's a check nobody sees.

## What we turned down

| Option | Why not |
|---|---|
| Renovate `customManagers` for `PLASMAZONES_VERSION` too | ADR-0015 already decided PlasmaZones stays a **manual** bump (active/breaking upstream, KWin coupling); an auto-PR would often be one nobody should merge yet. It still needs *watching* (this PR), just not auto-bumping. |
| Leave `PWSH_VERSION` out until Renovate is built | Would mean months of zero drift signal on a pin ADR-0015 itself calls "high value (used daily)" while the Renovate manager sits unbuilt. Watching it here now, and dropping it once Renovate lands, costs one extra `check_pinned_version` call. |
| Diff our tree against the template's tree (content diff, not commit range) | ADR-202608042137 already found this destructive for merging and near-permanently noisy for reading: unrelated histories, and files like `Containerfile` where "ours is heavily customized; expect big diffs" every single time. A commit-range check on the template's own history avoids both problems. |
| Auto-advance the baseline after every report | Would silently stop reporting a range nobody actually reviewed — the same failure mode the whole issue exists to prevent, just moved one level down. The baseline only moves when a human bumps it, mirroring how `PLASMAZONES_VERSION` only moves when a human bumps it. |
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
- **If the template-drift check starts missing real changes** (e.g. upstream
  restructures into files outside the watched-path list), extend
  `watched_paths` in `check_template_drift` — same fix as the file-by-file
  table on #19 already anticipates needing updates over time.
- **If `.github/template-drift-baseline` goes stale** (nobody bumps it after
  reviewing a reported range, so the same commits keep re-reporting for
  months) — that's a signal the review step itself needs a nudge (e.g. an
  explicit "reviewed, nothing to port" comment convention), not that the
  check is wrong.
