---
name: Customization regressed (likely upstream drift)
about: A baked-in customization stopped doing its job, even though the build still succeeds
title: "<feature> stopped working"
labels: regression
---

<!--
The signature failure mode of this repo: the build stays green but a
customization silently stops doing what it should, because the base image or an
upstream project moved underneath the pin. Start from that assumption.
-->

**Affected customization:** <!-- PlasmaZones / PowerShell / Discord / VLC / fonts -->
**Symptom:** <!-- e.g. "zones don't snap", "Discord won't launch", "emoji are tofu" -->

### Drift triage

- [ ] Did the **base image** move recently? (New `stable-44` build / KWin point
  release.) Compare `kwin_wayland --version` (or the base's labels) against what
  the pinned RPM was built for.
- [ ] For **PlasmaZones**: check the build log for the KWin skew `WARNING`
  (`build.sh`) — an inert effect is almost always a KWin mismatch, not a bug.
- [ ] For **Discord**: is it the "update required" screen? That means image
  rebuilds have stalled (cadence is load-bearing — ADR-0009), not a code fault.
- [ ] For **fonts/rendering**: this is Chromium/Electron-specific and *not*
  fixable at build time — see ADR-0010 / `docs/fonts.md` before proposing an
  image change.
- [ ] Check the relevant `docs/` page and its ADR — the failure may already be a
  documented, known condition.

### Where was this seen?

<!-- Container (podman run) / VM boot / real hardware. See docs/verifying-changes.md
— note that fonts and desktop integration only show up on a boot. -->

### Notes
