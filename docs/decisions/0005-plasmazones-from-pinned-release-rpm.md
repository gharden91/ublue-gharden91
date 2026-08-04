# ADR-0005: Install PlasmaZones from a pinned GitHub release RPM

- **Status:** Accepted
- **Date:** 2026-07-11
- **Scope:** plasmazones
- **Shipped in:** #7 (supersedes [ADR-0004](0004-plasmazones-from-copr.md))

## The question

Installing PlasmaZones from the COPR ([ADR-0004](0004-plasmazones-from-copr.md))
put the effect inert on deployed machines: the COPR auto-rebuilds against
Fedora's newest KWin, the effect only loads under the exact KWin it was compiled
against, and the base image's KWin lagged. How do we regain control over *which*
build lands?

## What we chose

Download the pinned GitHub **release** RPM
(`plasmazones-<version>-1.fc<NN>.x86_64.rpm`) and install it with `dnf5`, version
controlled by `PLASMAZONES_VERSION`. Release assets are frozen point-in-time
builds, so the version only moves when we move it — same philosophy as
`PWSH_VERSION` (ADR-0002). `build.sh` also prints a build-log WARNING when the
plugin's embedded KWin version doesn't match the image's KWin, so a future skew
is loud instead of a silent desktop notification. No third-party repo file is
left on the image.

This resolved the July 2026 skew because the v3.1.3 *release* asset happened to
be built against KWin 6.7.1 (matching the base image), whereas the COPR build of
the same version was 6.7.2 — a version coincidence, not a permanent fix. The
skew is a recurring maintenance condition; see `docs/plasmazones.md`.

## What we turned down

| Option | Why not |
|---|---|
| Stay on the COPR (ADR-0004) | Auto-takes latest → non-deterministic builds and the KWin mismatch that started this. |
| Build PlasmaZones from source against the base image's KWin | Correct-by-construction match, but needs `kwin-devel` at the *exact* base KWin version — Fedora repos only carry the latest, so during a skew window (exactly when you'd need it) the matching devel package has rotated to Koji archives. More machinery for a guarantee that fails when needed. |
| Switch to KZones (a KWin *script*, no compiled plugin) | Immune to this whole class of breakage, but mainline lacks multi-zone spanning — the feature that motivated PlasmaZones over KDE's built-in tiling. Kept as the fallback if upstream goes stale. |

## What would change our mind

- Upstream decouples the effect from an exact KWin version — then the
  pin-must-track-KWin constraint and the skew check relax.
- The PlasmaZones project goes stale/disappears — switch to KZones (the
  documented fallback).
- We build for ARM64 — the asset name hardcodes `x86_64` (code fix).
