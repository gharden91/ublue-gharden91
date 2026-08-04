# ADR-0004: Install PlasmaZones from the maintainer's COPR

- **Status:** Superseded by [ADR-0005](0005-plasmazones-from-pinned-release-rpm.md)
- **Date:** 2026-07-03
- **Scope:** plasmazones
- **Shipped in:** #4

## The question

PlasmaZones (KWin snapping zones) ships from the maintainer's
`fuddlesworth/PlasmaZones` COPR and, separately, as versioned GitHub release
RPMs. How do we install it into the image?

## What we chose

Enable the `fuddlesworth/PlasmaZones` COPR for the install transaction, install
`plasmazones`, then disable the COPR. Standard, low-effort ublue pattern; picks
up upstream builds automatically.

## What we turned down

| Option | Why not |
|---|---|
| Pinned GitHub release RPM | More setup (manual version pin, derive the `.fcNN` asset URL) for a benefit — deliberate versioning — we didn't yet know we needed. |

## Why this was superseded

The COPR always installs its *latest* build, so the daily image rebuild silently
takes whatever upstream last pushed. PlasmaZones' KWin effect plugin is compiled
against an exact KWin version and stays inert under any other; the COPR
auto-rebuilds against Fedora's newest KWin, which moved ahead of the base
image's KWin, so the effect went inert on deployed machines ("window manager
integration inactive"). Two other problems compounded it: the daily rebuild
became non-deterministic, and the COPR left a disabled `.repo` file on the
image. [ADR-0005](0005-plasmazones-from-pinned-release-rpm.md) replaced this
with a pinned release RPM. See `docs/plasmazones.md` for the full KWin-skew
story.

## What would change our mind

Superseded — reopening means revisiting ADR-0005, not this record.
