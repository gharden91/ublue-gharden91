# Documentation

Notes on this image's customizations, decisions, and workflows.

- [local-testing.md](./local-testing.md) — how to build and test the image locally.
- [plasmazones.md](./plasmazones.md) — PlasmaZones install: intent, decisions, and maintenance.
- [powershell.md](./powershell.md) — PowerShell 7 install: intent, decisions, and maintenance.

## Maintenance Watchlist

This image is built on top of `ghcr.io/ublue-os/bazzite-dx:stable`, a moving
target maintained upstream. The items below are things that can break
silently — the build still succeeds, but the customization stops doing what
it's supposed to — because the base image changed underneath us. Check these
periodically, and especially whenever bumping the base image tag or after a
build starts behaving oddly.

Each customization's own doc has the full "Decisions"/"Maintenance" writeup;
this list is just the "what could rot" summary in one place.

### PlasmaZones (see [plasmazones.md](./plasmazones.md))

- **Base image still ships KDE Plasma.** PlasmaZones is a KWin extension and
  is dead weight (or a build failure) on a non-Plasma desktop. Confirm
  `bazzite-dx` hasn't switched its default DE before/after a base image bump.
- **The COPR still builds for the Fedora version `bazzite-dx` tracks.** When
  `bazzite-dx` bumps its underlying Fedora release, `fuddlesworth/PlasmaZones`
  needs a matching COPR build or `dnf5 -y install plasmazones` will fail during
  the image build. Check the COPR page before/after a Fedora version bump.
- **Upstream project is still maintained.** It's a single-maintainer COPR; if
  it goes stale or disappears, the build breaks outright. Check
  [fuddlesworth/PlasmaZones](https://github.com/fuddlesworth/PlasmaZones) for
  activity periodically.

### PowerShell 7 (see [powershell.md](./powershell.md))

- **New releases to pin.** `PWSH_VERSION` is pinned and does not auto-update.
  Check [PowerShell/PowerShell releases](https://github.com/PowerShell/PowerShell/releases)
  periodically for security fixes and bump the `PWSH_VERSION` repo variable.
- **`/opt` immutability stays untouched.** PowerShell is deliberately installed
  into `/usr` (not `/opt`) because `bazzite-dx` ships apps that write to `/opt`
  at runtime. If a future customization ever uncomments the
  `RUN rm /opt && mkdir /opt` line in the `Containerfile`, double check it
  doesn't conflict with those apps — and that it doesn't accidentally change
  where `pwsh` should live.
- **Architecture stays x86_64.** The download URL in `build_files/build.sh` is
  hardcoded to `linux-x64`. If this image is ever built for ARM64, that string
  must be made conditional on target arch or PowerShell installation will
  silently fetch the wrong binary.

### Adding a new entry

When adding a new customization that could break as the base image evolves,
give it its own `docs/<feature>.md` (intent, decisions, maintenance — follow
the existing files as a template), link it in the list at the top of this
file, and add a subsection here with bullet points for whatever could
silently rot: upstream repo/COPR health, paths that assume current `/opt` or
`/usr` immutability behavior, hardcoded versions/architectures, and any
assumption about the base image's desktop environment or Fedora version.
