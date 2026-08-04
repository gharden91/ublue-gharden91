---
name: Base image bump (Fedora / stable-NN)
about: Move the Containerfile FROM to a new bazzite-dx tag (e.g. stable-44 → stable-45)
title: "Bump base image to stable-NN"
labels: base-image
---

<!--
Why this has a template: the base image is a moving target and version-suffixed
RPMs (.fcNN) must stay in lockstep with it. Skipping a step here is how the
build breaks silently. Full reasoning: docs/README.md Maintenance Watchlist and
ADR-0003 (why we pin a Fedora-versioned tag at all).
-->

**Target tag:** `ghcr.io/ublue-os/bazzite-dx:stable-__`
**Current tag:** `ghcr.io/ublue-os/bazzite-dx:stable-44`

### Pre-bump checklist (from the Maintenance Watchlist)

- [ ] Confirm the pinned **PlasmaZones** release has an RPM asset for the target
  Fedora version (`plasmazones-<ver>-1.fc<NN>.x86_64.rpm`).
- [ ] Confirm which Fedora version the candidate tag actually is:
  `podman run --rm ghcr.io/ublue-os/bazzite-dx:<tag> sh -c 'grep VERSION_ID= /etc/os-release; uname -m'`
- [ ] Check the **PlasmaZones / KWin skew** — does the pinned release match the
  new base image's KWin? (`build.sh` prints a WARNING on mismatch.)
- [ ] Base image still ships **KDE Plasma** (PlasmaZones is dead weight otherwise).
- [ ] `bazzite-dx` still ships the `negativo17-fedora-multimedia` repo file (VLC).
- [ ] Rebuild locally and confirm `plasmazones` installs and `pwsh` runs
  (see `docs/local-testing.md`).

### Verification tier reached

<!-- See docs/verifying-changes.md. A base bump touches the desktop, so Tier 2
(VM boot) minimum. -->

### Notes
