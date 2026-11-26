# PlasmaZones

## Intent

Ship [PlasmaZones](https://github.com/phosphor-works/PlasmaZones) baked into the
image so KWin window-snapping zones are available on every machine that rebases
to this image, without per-machine setup or runtime package layering.

## What is installed

- The `plasmazones` RPM, downloaded from the upstream
  [GitHub releases](https://github.com/phosphor-works/PlasmaZones/releases)
  (`plasmazones-<version>-<pkgrel>.fc<NN>.x86_64.rpm` asset) and installed with
  `dnf5`, which resolves its dependencies from the image's normal repos.
  The project moved from `fuddlesworth/PlasmaZones` to
  `phosphor-works/PlasmaZones` in late 2026. `build.sh` uses the new path.
- Version is pinned via `PLASMAZONES_VERSION` in `build_files/build.sh`
  (overridable per build — see Maintenance below).

### Package revisions (`-rN` tags)

When a distro moves to a new KWin, upstream rebuilds the **unchanged source**
against it and publishes the result as a *package revision*. The release tag
gets an `-rN` suffix, and the RPM release field becomes `N`:

| Tag | Fedora 45 asset |
|---|---|
| `v3.5.5` | `plasmazones-3.5.5-1.fc45.x86_64.rpm` |
| `v3.5.5-r2` | `plasmazones-3.5.5-2.fc45.x86_64.rpm` |
| `v3.5.5-r3` | `plasmazones-3.5.5-3.fc45.x86_64.rpm` |

`PLASMAZONES_VERSION` is spelled **exactly like the tag, minus the `v`**:
`3.5.5` or `3.5.5-r3`. `build.sh` splits off a trailing `-rN` to build the
asset name. A bare version means release 1. Keeping one knob in tag form means
the drift check compares it to upstream's latest tag with no translation. It
also means a revision bump is the same one-variable edit as a version bump.
Before this, the URL hardcoded release `-1`, so revisions couldn't be pinned at
all.

Each release also publishes a `kwin-baseline.json` asset with the `pkgrel` and
the KWin version each distro's package was built against
(`"fedora-45": "6.8.3"`). It's the quickest way to find a matching release
without downloading an RPM:

```bash
curl -fsSL https://github.com/phosphor-works/PlasmaZones/releases/download/v3.5.5-r3/kwin-baseline.json
```

That file is upstream's claim. The build's skew check, which reads the version
embedded in the installed plugin, is still the ground truth. For 3.5.5 the two
agreed: r1 claims and embeds 6.8.2, and r3 claims and embeds 6.8.3.

The drift check (`.github/scripts/check-drift.sh`) uses the file in two ways.
It treats the file only as advice: a missing file or entry means "unknown",
never "mismatch".

- **On skew:** it walks upstream's 15 most recent releases, newest first, and
  names the first one whose `fedora-<NN>` entry equals the image's KWin (as
  the last build logged it). The drift issue then says "set
  `PLASMAZONES_VERSION` to `3.5.5-r3`". If none matches, it says there is
  nothing to pin yet.
- **On a newer upstream release:** it compares that release's `fedora-<NN>`
  KWin with the image's. It reports whether the bump would work, or that it
  should wait ("Don't bump yet") because upstream built for a KWin the base
  image hasn't reached.
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

### KWin version skew: current status

The `stable-45` base ships KWin **6.8.3**, and the pinned `3.5.5-r3` `.fc45`
asset embeds `6.8.3`. This was checked by extracting the RPM: the effect
plugin `kwin_effect_plasmazones.so` contains exactly one 6.8.x string,
`6.8.3`. The original `3.5.5` (release 1) embeds `6.8.2`. It went inert when
Bazzite moved from KWin 6.8.2 to 6.8.3, and the drift check caught it.

How it got here is the useful part. The original COPR install went inert on
deployed machines ("window manager integration inactive" notification)
because the COPR auto-rebuilt against Fedora's latest KWin, ahead of the base
image's; switching to a pinned release RPM fixed that. Later, on `stable-44`
(KWin 6.7.5), the pinned 3.5.4 `.fc44` asset embedded **no** 6.7.x version at
all — upstream had built it against a newer KWin than Bazzite's Fedora 44
shipped — so the effect was inert again until the move to `stable-45`
realigned them. **A per-Fedora asset (`.fcNN`) does not imply it was built
against the KWin Bazzite ships on that Fedora**; only the skew check says so.

This is a **version coincidence, not a permanent fix.** The release asset
happened to be built against the KWin the base image ships; nothing guarantees
that holds after the next KWin move, so treat the skew as a recurring
maintenance condition rather than a one-time bug:

- **The skew recurs on KWin bumps.** When Bazzite moves to a newer KWin
  (6.7.2, 6.8.x, …), the currently-pinned release becomes the mismatched one,
  and the release you'd bump *to* may be built against a KWin ahead of or
  behind the base image — upstream controls their build target, not us.
- **The build log is the signal.** On a mismatch the skew check prints
  `WARNING: PlasmaZones … is not built against this image's KWin …`. When you
  see it, bump `PLASMAZONES_VERSION` to a release built against the base
  image's KWin (see the workarounds below), or wait for one to exist. The
  weekly drift issue names that release for you when one exists (see
  `kwin-baseline.json` above).
- **Meanwhile a mismatch is harmless.** KWin never loads a non-matching
  plugin; the only symptom is the notification and zones not working.
- **Upstream is iterating on this.** 130+ releases; v3.0.17/v3.1.3 specifically
  reworked how the KWin version coupling is handled and notified. If a future
  release decouples the effect from an exact KWin version, the
  pin-must-track-KWin constraint relaxes and this section plus the skew check
  can be simplified.

### Workarounds considered

Evaluated during the July 2026 skew; recorded here so the next one doesn't
re-derive them.

**Pin a release built against the running KWin** *(current approach)*

- Pros: when such a release exists, zones work immediately — this is the main
  payoff of the pinned-release install, and it's what resolved the July 2026
  skew (the v3.1.3 release asset was built against 6.7.1, matching the base
  image, whereas the COPR build of the same version was 6.7.2). Check a
  candidate RPM without installing it:

  ```bash
  rpm2cpio plasmazones-<ver>-<pkgrel>.fc45.x86_64.rpm | cpio -i --to-stdout '*plasmazones.so' \
      | grep -aoE '6\.8\.[0-9]+' | sort | uniq -c
  ```

  The built-against version is the single `6.7.x` string the plugin embeds
  (verified: the COPR 6.7.2 build shows exactly `1 6.7.2`; the release build
  embeds `6.7.1` per the build-log skew check).
- Cons: only works when upstream cut a release against that exact KWin.
  Release assets are frozen point-in-time builds, so after a base-image KWin
  bump you may have to wait for upstream to publish a matching one — which is
  the fallback below.

**Wait for the base image and a matching release to line up** *(fallback)*

- Pros: zero code, zero new maintenance; Bazzite typically picks up KWin point
  releases within days–weeks, and upstream rebuilds around the same time; the
  skew is harmless in the meantime (plugin stays inert, nothing crashes).
- Cons: zones don't work during the window, which recurs whenever the base
  image's KWin and an available release's build target drift apart.

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

The `Containerfile` uses `ghcr.io/ublue-os/bazzite-dx:stable-45` rather than
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
  variable named `PLASMAZONES_VERSION` (e.g. `3.5.5-r3`) to a release tag
  (minus the `v`, *including* any `-rN` revision suffix) from
  https://github.com/phosphor-works/PlasmaZones/releases. The next CI build
  picks it up. Leaving it unset falls back to the default baked into
  `build_files/build.sh`.
- **Bump locally:** `PLASMAZONES_VERSION=3.5.5-r3 just build`.
- **Change the default:** edit `PLASMAZONES_VERSION="${PLASMAZONES_VERSION:-3.5.5-r3}"`
  in `build_files/build.sh` and `ARG PLASMAZONES_VERSION=` in `Containerfile`
  (keep them the same).
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
