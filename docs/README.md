# Documentation

Notes on this image's customizations, decisions, and workflows.

- [local-testing.md](./local-testing.md) — how to build and test the image locally.
- [plasmazones.md](./plasmazones.md) — PlasmaZones install: intent, decisions, and maintenance.
- [powershell.md](./powershell.md) — PowerShell 7 install: intent, decisions, and maintenance.
- [edge.md](./edge.md) — Microsoft Edge: native-RPM install, the `/opt` blocker, and how it was resolved.

## Maintenance Watchlist

This image is built on top of `ghcr.io/ublue-os/bazzite-dx:stable-44`, a moving
target maintained upstream. The items below are things that can break
silently — the build still succeeds, but the customization stops doing what
it's supposed to — because the base image changed underneath us. Check these
periodically, and especially whenever bumping the base image tag or after a
build starts behaving oddly.

**Why `stable-44` and not the floating `stable` tag:** `bazzite-dx:stable`
tracks whatever Fedora release Bazzite currently ships, and jumps to the next
major version whenever upstream cuts over. PlasmaZones release assets are
built per Fedora version (`.fc44`, `.fc45`, …), so an unannounced Fedora bump
on `stable` could land before PlasmaZones has a matching build, breaking the
image build with no warning. Pinning to the version-suffixed tag (`stable-44`)
keeps the base image's Fedora version fixed until we deliberately choose to
move — see "Bumping the Fedora version" below.

Each customization's own doc has the full "Decisions"/"Maintenance" writeup;
this list is just the "what could rot" summary in one place.

### PlasmaZones (see [plasmazones.md](./plasmazones.md))

- **The pinned build still matches the base image's KWin.** The compiled KWin
  effect only loads under the exact KWin it was built against; on a mismatch
  it stays inert (with a desktop notification) even though the build succeeds.
  `build.sh` prints a `WARNING` in the build log when the installed plugin
  doesn't match the image's KWin — check for it after bumping
  `PLASMAZONES_VERSION` and whenever Bazzite moves to a new KWin point
  release. Expect to bump the pin shortly after each base-image KWin update.
- **New releases to pin.** `PLASMAZONES_VERSION` is pinned and does not
  auto-update. Check
  [PlasmaZones releases](https://github.com/fuddlesworth/PlasmaZones/releases)
  periodically and bump the `PLASMAZONES_VERSION` repo variable.
- **Release assets keep their current shape.** The download URL assumes a
  `plasmazones-<version>-1.fc<NN>.x86_64.rpm` asset per release. If upstream
  renames assets or stops publishing Fedora RPMs, the build breaks outright.
- **Base image still ships KDE Plasma.** PlasmaZones is a KWin extension and
  is dead weight (or a build failure) on a non-Plasma desktop. Confirm
  `bazzite-dx` hasn't switched its default DE before/after a base image bump.
- **Upstream project is still maintained.** It's a single-maintainer project;
  if it goes stale or disappears, the build breaks outright. Check
  [fuddlesworth/PlasmaZones](https://github.com/fuddlesworth/PlasmaZones) for
  activity periodically.

### Bumping the Fedora version

The `Containerfile`'s `FROM` line is pinned to `ghcr.io/ublue-os/bazzite-dx:stable-44`
specifically so it and the PlasmaZones COPR stay on the same Fedora release.
Before moving to `stable-45` (or later):

1. Confirm the pinned PlasmaZones release has an RPM asset for the target
   Fedora version on the
   [releases page](https://github.com/fuddlesworth/PlasmaZones/releases)
   (look for `plasmazones-<version>-1.fc<NN>.x86_64.rpm` — the download URL in
   `build.sh` derives `fc<NN>` from the base image automatically).
2. Confirm which Fedora version a candidate base image tag actually is before
   pointing the `Containerfile` at it — the tag name is the source of truth
   (Universal Blue's `stable-NN` suffix *is* the Fedora major version), but you
   can double check directly against the image:

   ```bash
   podman run --rm ghcr.io/ublue-os/bazzite-dx:<tag> sh -c 'grep VERSION_ID= /etc/os-release; uname -m'
   ```

   If you're already booted into this image (rebased and rebooted), you can
   run the same check directly on the machine instead of pulling anything:

   ```bash
   grep VERSION_ID= /etc/os-release; uname -m
   ```
3. Bump the `FROM` tag in the `Containerfile` and rebuild locally
   (see [local-testing.md](./local-testing.md)) to confirm `plasmazones` still
   installs and `pwsh` still runs.
4. Only merge the bump once all checks pass — don't let the base image and
   the COPR drift to different Fedora versions.

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
