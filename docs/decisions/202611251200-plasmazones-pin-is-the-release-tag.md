# ADR-202611251200: Pin PlasmaZones by its full release tag, revision suffix included

- **Status:** Accepted
- **Date:** 2026-11-25
- **Scope:** plasmazones
- **Shipped in:** the PR closing #82

## The question

Upstream began publishing KWin-only rebuilds as *package revisions*. The tags
are `v3.5.5-r2` and `v3.5.5-r3`, and the RPMs are named
`plasmazones-3.5.5-<N>.fc45…`. Our download URL hardcoded RPM release `-1`
and built the tag from the version alone. So a revision could not be pinned,
and when Bazzite moved to KWin 6.8.3 (#82) only the 6.8.2-built `3.5.5-1`
was installable. How should the pin express a revision?

## What we chose

`PLASMAZONES_VERSION` holds the release tag minus the `v`, so `3.5.5` or
`3.5.5-r3`. `build.sh` splits a trailing `-rN` into the RPM release field, and
a bare version means release 1. The pin stays one knob, spelled the way
upstream's releases page spells it. The drift check already compares the pin
to upstream's latest tag string, so it handles revisions with no change: a new
`-r4` shows up as drift because it is a new latest tag. Bumping a revision is
the same one-variable edit (repo variable or default) as bumping a version.

## What we turned down

| Option | Why not |
|---|---|
| A separate `PLASMAZONES_RELEASE` variable alongside the version | Two knobs that must move together, through the repo variable, `build.yml`, `Justfile`, `Containerfile` and `build.sh`. Setting one without the other gives a 404 or the wrong build. The drift check would have to recombine them to compare against the tag. |
| Read `pkgrel` at build time from the release's `kwin-baseline.json` asset | Adds a second fetch at build time, and the build would depend on a metadata file that older releases may not have and upstream may reshape. The tag already carries the revision. The file is more useful for *choosing* a release (see #83) than for installing one. |
| Hardcode the newest revision in the URL | That is the bug this record fixes, with a different number in it. |

## What would change our mind

- Upstream changes its revision naming, for example `-r3` stops mapping to RPM
  release `3`, or revisions get their own version numbers. The asset-name
  derivation then needs revisiting.
- Upstream starts publishing a stable, documented "latest asset for distro X"
  index, so the URL no longer has to be built by hand.
