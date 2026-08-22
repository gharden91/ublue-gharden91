# Documentation

Notes on this image's customizations, decisions, and workflows.

**How knowledge is organised here** (full map in [`../CLAUDE.md`](../CLAUDE.md)):
these pages are *durable reference* — how each customization works, its
constraints, and the war stories. They are **edited in place, never dated**; a
page describing old behavior is worse than no page, so delete what stopped being
true. *Why* a choice was made (and what was turned down) lives as an immutable
record in [`decisions/`](./decisions/) — read those before re-opening a
settled call. *Open work* lives only in
[GitHub Issues](https://github.com/gharden91/ublue-gharden91/issues), never as a
"next steps" section in a doc.

- [decisions/](./decisions/) — immutable decision records (ADRs): why this and not that.
- [local-testing.md](./local-testing.md) — how to build and test the image locally.
- [verifying-changes.md](./verifying-changes.md) — what counts as verified: the tier ladder (container < VM boot < real hardware) and the boot-test rule.
- [provenance.md](./provenance.md) — which Bazzite an image was built on: the base-image labels and how to read them (registry, running system, local build).
- [plasmazones.md](./plasmazones.md) — PlasmaZones install: intent, decisions, and maintenance.
- [powershell.md](./powershell.md) — PowerShell 7 install: intent, decisions, and maintenance.
- [edge.md](./edge.md) — Microsoft Edge: native-RPM install and why `/opt` is a real directory.
- [discord.md](./discord.md) — Discord: official RPM, deliberately unpinned, and why rebuild cadence matters.
- [vlc.md](./vlc.md) — VLC: negativo17 fedora-multimedia install, why not RPM Fusion.
- [fonts.md](./fonts.md) — color emoji: resolved; the tofu was a stale per-user `fontconfig` cache, not the image.

## Maintenance Watchlist

This image is built on top of `ghcr.io/ublue-os/bazzite-dx:stable-44`, a moving
target maintained upstream. The items below are things that can break
silently — the build still succeeds, but the customization stops doing what
it's supposed to — because the base image changed underneath us. Check these
periodically, and especially whenever bumping the base image tag or after a
build starts behaving oddly.

**Three of these are checked for you.** `.github/workflows/drift-check.yml`
runs weekly (and on demand via `workflow_dispatch`) and files or updates a
`drift-watch`-labeled issue when it finds: a new PlasmaZones release, the
pinned PlasmaZones RPM no longer matching the base image's KWin, or the base
Fedora version becoming stale (`stable-44` behind what `stable` currently
resolves to). See
[ADR-202608222309](decisions/202608222309-scheduled-drift-check-workflow.md)
for what it watches and, as importantly, what it deliberately doesn't
(PowerShell — that's Renovate's job per ADR-0015 once built; template drift —
still manual, see ADR-202608042137). Everything else below is still a manual
check.

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

### Discord (see [discord.md](./discord.md))

- **Rebuild cadence is load-bearing.** Discord is installed from the official
  unpinned "latest" RPM and hard-gates outdated clients with a mandatory
  "update required" screen. If scheduled image rebuilds stall (broken CI,
  disabled workflow), Discord is the first user-visible breakage — "Discord
  won't start" usually means "the image hasn't rebuilt lately."
- **Download URL shape.** The build assumes
  `discord.com/api/download?platform=linux&format=rpm` keeps redirecting to an
  installable RPM. If Discord changes or drops the RPM flavor, the build
  breaks outright.
- **x86_64 only.** Discord publishes no Linux ARM64 build; an ARM64 image
  build would need this install made conditional on target arch.

### VLC (see [vlc.md](./vlc.md))

- **The base image keeps shipping negativo17's `fedora-multimedia` repo file.**
  VLC installs via `--enable-repo="*fedora-multimedia*"`, matching the
  disabled `negativo17-fedora-multimedia.repo` baked into bazzite. If bazzite
  renames that file or switches multimedia stacks, the build breaks outright.
- **RPM Fusion stays out.** Bazzite has no RPM Fusion; its multimedia stack is
  negativo17's, and the two are documented as incompatible. Don't add RPM
  Fusion for codec-adjacent packages in future customizations.

### Base-image provenance (see [provenance.md](./provenance.md))

- **The base labels can go missing without failing the build.** `just build`
  stamps `org.opencontainers.image.base.name`/`.base.digest` and
  `org.ublue-gharden91.base-image.version`; nothing asserts they survived.
  They currently come through `just ostree-rechunk` intact (verified on a
  published image), but a future rechunker — or a switch to the `chunkah`
  recipe, which rewrites labels explicitly — could drop them and the build
  would still go green. Reconciliation would quietly stop working. Spot-check
  with `skopeo inspect docker://ghcr.io/gharden91/ublue-gharden91:latest`.
- **`unknown` in the version label means upstream stopped setting theirs.**
  The version string is read from the base's own
  `org.opencontainers.image.version`; if Bazzite drops it, ours records
  `unknown` rather than failing. The digest is still exact, so nothing is
  really lost — but it's a signal to go read the base's labels directly.

### Local VM testing (see [local-testing.md](./local-testing.md))

- **The pinned VM runner tag never auto-updates.** `just run-vm` pins
  `docker.io/qemux/qemu:7.36` because 7.37+ rejects our compressed qcow2s and
  **silently boots Alpine instead of the image** (ADR-0014). The danger is that
  the VM comes up looking healthy, so a boot "test" can pass against the wrong
  OS entirely — check the GRUB entry says `Bazzite`. Recheck newer releases
  periodically and bump the pin once upstream fixes the probe.
- **The pin ages against the host.** An old runner can eventually break against
  a newer host kernel/KVM/podman. If it does, boot the qcow2 with host
  `qemu-system-x86_64` (documented in `local-testing.md`) while sorting out a
  newer runner.

### Microsoft Edge (see [edge.md](./edge.md))

- **The repo-disabling `sed` must keep matching.** Edge's RPM ships and
  re-enables its own `.repo` file; `build.sh` rewrites `enabled=1` to
  `enabled=0` afterwards. If Microsoft changes that file's shape, the `sed`
  silently no-ops and the image ships with a third-party repo **enabled** — the
  build still succeeds. Verify with
  `podman run --rm <image> grep enabled= /etc/yum.repos.d/microsoft-edge.repo`.
- **`repo_add_once` must stay `"false"`.** Edge ships
  `/etc/cron.daily/microsoft-edge`, which recreates the repo config *on running
  machines*. It is inert today only because no cron implementation exists in the
  base — **if `cronie` ever appears in `bazzite-dx`, that changes silently**.
  `build.sh` writes `repo_add_once="false"` to `/etc/default/microsoft-edge` to
  disarm it; check that file still exists and that Edge hasn't changed the
  mechanism after a version bump.
- **Edge depends on `/opt` being a real directory.** `Containerfile` carries
  `RUN rm /opt && mkdir /opt` (ADR-0007). Reverting `/opt` to the base symlink
  breaks the Edge install outright.
- **Unpinned by design.** Rebuilds install whatever `microsoft-edge-stable` is
  current, so a stalled rebuild cadence means an ageing browser.
- **x86_64 only.** The repo publishes no ARM64 build.

### Fonts (see [fonts.md](./fonts.md))

- **A long-lived `$HOME` can mask the image's fonts.** Emoji tofu in Chromium
  apps was traced to a stale `~/.cache/fontconfig`, not the image (ADR-0013).
  If rendering looks wrong after a base-image font change, test a **fresh user
  account** before suspecting the image; `fc-match` output is not evidence about
  what an app sees.

### Adding a new entry

When adding a new customization that could break as the base image evolves,
give it its own `docs/<feature>.md` (intent, decisions, maintenance — follow
the existing files as a template), link it in the list at the top of this
file, and add a subsection here with bullet points for whatever could
silently rot: upstream repo/COPR health, paths that assume current `/opt` or
`/usr` immutability behavior, hardcoded versions/architectures, and any
assumption about the base image's desktop environment or Fedora version.
