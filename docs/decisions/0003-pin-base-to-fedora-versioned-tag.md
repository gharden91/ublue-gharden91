# ADR-0003: Pin the base image to a Fedora-versioned tag, not floating `stable`

- **Status:** Accepted
- **Date:** 2026-07-04
- **Scope:** repo
- **Shipped in:** #5

## The question

The `Containerfile`'s `FROM` can track `bazzite-dx:stable` (whatever Fedora
release Bazzite currently ships) or a version-suffixed tag like `stable-44`
(Fedora 44, fixed). We download RPMs whose asset names are built per Fedora
version (`.fc44`, `.fc45`). Which tag do we pin to?

## What we chose

Pin to `ghcr.io/ublue-os/bazzite-dx:stable-44`. `build.sh` derives the Fedora
suffix from the image itself (`rpm -E %fedora`) for downloads like PlasmaZones,
so pinning keeps the base image's Fedora version and the RPM asset names in
lockstep until we deliberately move. Bumping is a checklist, not an accident —
see the Maintenance Watchlist in `docs/README.md`.

## What we turned down

| Option | Why not |
|---|---|
| Floating `bazzite-dx:stable` | Jumps to the next Fedora major whenever upstream cuts over, with no announcement. An unannounced bump can land before a version-matched RPM (e.g. PlasmaZones' `.fcNN` asset) exists, breaking the build with no warning — the worst kind: a silent base change. |
| Pin by digest | Maximally reproducible but freezes *all* base updates (security included) until a manual bump; too heavy for a rolling desktop image. The Fedora-versioned tag still gets base updates within the release. |

## What would change our mind

- We deliberately move to Fedora 45+ — that's a `stable-45` bump following the
  Watchlist, not an abandonment of this policy.
- Upstream stops publishing version-suffixed tags, forcing a different pinning
  strategy (digest pin becomes the fallback).
