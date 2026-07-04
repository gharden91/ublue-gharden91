# PlasmaZones

## Intent

Ship [PlasmaZones](https://github.com/fuddlesworth/PlasmaZones) baked into the
image so KWin window-snapping zones are available on every machine that rebases
to this image, without per-machine setup or runtime package layering.

## What is installed

- The `plasmazones` package, installed from the maintainer's Fedora COPR
  `fuddlesworth/PlasmaZones`.
- The COPR is enabled only long enough to install, then disabled so it is **not**
  left enabled on the final image.

See [local-testing.md](./local-testing.md) for full build/test commands. Verify
the package landed in a built image with:

```bash
podman run --rm <image>:<tag> rpm -q plasmazones
```

## Decisions

### Install from the COPR, then disable it

PlasmaZones is distributed through the maintainer's COPR rather than the Fedora
repos, so we enable it, install, and disable it in `build_files/build.sh`:

```bash
dnf5 -y copr enable fuddlesworth/PlasmaZones
dnf5 -y install plasmazones
dnf5 -y copr disable fuddlesworth/PlasmaZones
```

Disabling the COPR afterward leaves its repo file in place but marked
`enabled=0`, so it does not silently pull further updates from a third-party
repo on deployed systems — package updates come from rebuilding the image
instead.

### Layering vs. image

PlasmaZones is a permanent desktop feature we want on every machine, so it
belongs in the image (declarative, versioned, built once, deployed everywhere)
rather than applied per-machine via `rpm-ostree install`. Reserve runtime
layering for throwaway experiments.

## Maintenance

- **Update:** PlasmaZones follows the COPR's latest build. Rebuilding the image
  pulls whatever version is current in `fuddlesworth/PlasmaZones` at build time.
- **Pin a version (optional):** if you need a specific release, replace the
  `dnf5 -y install plasmazones` line with an explicit versioned package, e.g.
  `dnf5 -y install plasmazones-<version>`.
- **Requires a KDE Plasma base.** PlasmaZones is a KWin extension, so it only
  makes sense on a Plasma-based image (this image's base, `bazzite-dx`, ships
  KDE Plasma).
