# PlasmaZones

## Intent

Ship [PlasmaZones](https://github.com/fuddlesworth/PlasmaZones) baked into the
image so KWin window-snapping zones are available on every machine that rebases
to this image, without per-machine setup or runtime package layering.

## What is installed

- The `plasmazones` RPM, downloaded from the upstream
  [GitHub releases](https://github.com/fuddlesworth/PlasmaZones/releases)
  (`plasmazones-<version>-1.fc<NN>.x86_64.rpm` asset) and installed with
  `dnf5`, which resolves its dependencies from the image's normal repos.
- Version is pinned via `PLASMAZONES_VERSION` in `build_files/build.sh`
  (overridable per build — see Maintenance below).
- No third-party repo (COPR or otherwise) is added to the image.

See [local-testing.md](./local-testing.md) for full build/test commands. Verify
the package landed in a built image with:

```bash
podman run --rm <image>:<tag> rpm -q plasmazones
```

## The KWin version-match constraint

PlasmaZones includes a compiled KWin effect plugin stamped with the exact KWin
version it was built against, and KWin only loads a plugin whose stamp matches
the running KWin. A mismatched plugin is harmless — it stays inert and (as of
PlasmaZones 3.1.3) posts a desktop notification — but zones do not work until
the versions align.

This matters because the two sides move on different clocks:

- Release RPMs are built against whatever KWin **Fedora updates** ships at
  release time.
- This image runs whatever KWin **Bazzite stable** ships, which typically lags
  Fedora's KWin point releases by days to weeks.

`build_files/build.sh` checks for this skew after installing and prints a
`WARNING` in the build log on mismatch (it deliberately does not fail the
build, so an inert PlasmaZones never blocks other image updates). When bumping
`PLASMAZONES_VERSION`, prefer a release built against the KWin your base image
actually ships; when Bazzite moves to a newer KWin, expect to bump PlasmaZones
shortly after.

To see what a machine is actually running, compare:

```bash
kwin_wayland --version   # running KWin
rpm -q plasmazones       # installed PlasmaZones build
```

### Known break (July 2026): zones inert on KWin 6.7.1

As of 2026-07-11 the effect is inert on deployed machines ("window manager
integration inactive" notification). The base image ships KWin **6.7.1**, and
no PlasmaZones release was built against it — upstream's builds jump straight
from 6.7.0 (v3.1.2, June 26) to 6.7.2 (v3.1.3, July 1), so there is nothing to
pin that would load. This is a known, accepted break, not a packaging bug on
our side:

- **It resolves on its own.** Bazzite's testing channel picked up KWin 6.7.2
  on July 9; once it reaches stable, the daily rebuild aligns the pinned
  v3.1.3 with the running KWin and zones start working after an update +
  reboot. The build log's skew check flips from `WARNING` to
  `PlasmaZones effect plugin matches image KWin ...` — that's the signal it's
  over.
- **Meanwhile it's harmless.** KWin never loads the mismatched plugin; the
  only symptom is the notification and zones not working.
- **Revisit later.** Upstream is under very active development (130+ releases;
  v3.0.17/v3.1.3 specifically reworked how the KWin version coupling is
  handled and notified). If a future release decouples the effect from exact
  KWin versions, the pin-must-track-KWin constraint documented above relaxes
  and this section plus the skew check can be simplified. Delete this section
  once the break has resolved.

### Workarounds considered

Evaluated during the July 2026 break; recorded here so the next skew window
doesn't re-derive them.

**Wait for the base image to catch up** *(chosen)*

- Pros: zero code, zero new maintenance; Bazzite typically picks up KWin point
  releases within days–weeks; the break is harmless in the meantime (plugin
  stays inert, nothing crashes).
- Cons: zones don't work during the window, which recurs on every KWin point
  release where upstream rebuilds before Bazzite rebases.

**Pin a release built against the running KWin**

- Pros: when such a release exists, it makes zones work *immediately* — this
  is the main payoff of the pinned-release install. Check a candidate RPM
  without installing it:

  ```bash
  rpm2cpio plasmazones-<ver>-1.fc44.x86_64.rpm | cpio -i --to-stdout '*kwin*.so' \
      | grep -ao '6\.7\.[0-9]*' | sort | uniq -c
  ```

  (Beware the `kwin >= 6.7.0` minimum-dependency string also matches; the
  built-for stamp is the version that appears alongside it.)
- Cons: only works if upstream happened to cut a release against that exact
  KWin. In July 2026 they didn't — builds jumped 6.7.0 → 6.7.2 straight over
  the base image's 6.7.1.

**Build from source against the base image's KWin**

- Pros: a correct-by-construction match every build; standard CMake project,
  cleanly done as a multi-stage `Containerfile` build (~30–50 lines, +5–10 min
  per build, no size impact on the final image).
- Cons: the guarantee depends on installing `kwin-devel` at the *exact*
  version the base image runs, and Fedora's repos only carry the latest —
  during a skew window (precisely when you need it) the matching devel package
  has already rotated out to Koji archives. Also forfeits upstream's packaging
  (manual tag bumps, tracking their cmake flags/paths), and their build system
  moves fast. Rejected as more machinery for a guarantee that fails exactly
  when needed.

**Switch to [KZones](https://github.com/gerritdevriese/kzones)**

- Pros: it's a KWin *script* (JavaScript), so this entire class of
  compiled-against-the-wrong-KWin breakage cannot happen; would also drop the
  external RPM from the build entirely (plain files under
  `/usr/share/kwin/scripts/` via `system_files/`).
- Cons: mainline KZones lacks multi-zone spanning — the feature that motivated
  PlasmaZones over KDE's built-in tiling in the first place. A fork adds it,
  but depending on a fork of a hobby project is a worse maintenance bet than
  the skew window. Kept as the fallback if the PlasmaZones COPR/releases ever
  go stale (see the [watchlist](./README.md#maintenance-watchlist)).

## Decisions

### Pinned release RPM, not the COPR

Originally installed from the maintainer's `fuddlesworth/PlasmaZones` COPR
(enable, install, disable). Switched to the pinned GitHub release RPM because:

- **Deliberate versioning.** The COPR always installs its latest build, so the
  daily image rebuild silently takes whatever upstream last pushed — including
  builds compiled against a newer KWin than the base image ships (see above),
  which is exactly how the effect went inert on deployed machines once. A pin
  only moves when we move it, same philosophy as `PWSH_VERSION`.
- **No third-party repo config on the image.** The COPR flow left a (disabled)
  repo file behind; the release RPM leaves nothing.
- The tradeoff is the same as PowerShell's: no auto-updates. New PlasmaZones
  releases (including rebuilds for new KWin versions) are taken by bumping the
  pin.

### Layering vs. image

PlasmaZones is a permanent desktop feature we want on every machine, so it
belongs in the image (declarative, versioned, built once, deployed everywhere)
rather than applied per-machine via `rpm-ostree install`. Reserve runtime
layering for throwaway experiments.

### Pin the base image to a Fedora-versioned tag

The `Containerfile` uses `ghcr.io/ublue-os/bazzite-dx:stable-44` rather than
the floating `bazzite-dx:stable` tag. `stable` jumps to whatever Fedora
release Bazzite currently ships, but upstream's release assets are built per
Fedora version (`.fc44`, `.fc45`, …) — the download URL in `build.sh` derives
the suffix from the image's own Fedora release (`rpm -E %fedora`), so both
sides stay in lockstep until we deliberately bump. See the
[Maintenance Watchlist](./README.md#maintenance-watchlist) for the checklist
to run through before bumping.

## Maintenance

- **Bump the version (recommended, no code change):** in GitHub go to
  *Settings > Secrets and variables > Actions > Variables* and set a repo
  variable named `PLASMAZONES_VERSION` (e.g. `3.1.3`) to a release tag (minus
  the `v`) from
  https://github.com/fuddlesworth/PlasmaZones/releases. The next CI build
  picks it up. Leaving it unset falls back to the default baked into
  `build_files/build.sh`.
- **Bump locally:** `PLASMAZONES_VERSION=3.1.3 just build`.
- **Change the default:** edit `PLASMAZONES_VERSION="${PLASMAZONES_VERSION:-3.1.3}"`
  in `build_files/build.sh`.
- **After any bump or base-image KWin change:** check the build log for the
  PlasmaZones/KWin skew `WARNING` (see above).

The version flows: repo variable `PLASMAZONES_VERSION` → `build.yml` env →
`just build` (`--build-arg`) → `Containerfile` (`ARG PLASMAZONES_VERSION`) →
`build.sh`.

- **Architecture:** the release asset name is hardcoded to `x86_64`. If this
  image is ever built for ARM64, check upstream publishes an aarch64 asset and
  make the URL conditional on target arch.
- **Requires a KDE Plasma base.** PlasmaZones is a KWin extension, so it only
  makes sense on a Plasma-based image (this image's base, `bazzite-dx`, ships
  KDE Plasma).
