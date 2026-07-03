# Local build & testing

How to build this image on your own machine and verify changes before pushing.

## Prerequisites

- `podman` and `just` installed (both ship on the ublue base images).
- Disk space and time for the first build: it pulls the multi-GB
  `bazzite-dx:stable` base image. Subsequent builds reuse the cache.

## Build the image

```bash
just build
```

This wraps `podman build` and tags the result `localhost/ublue-gharden91:latest`
(name/tag come from `image-template.env`).

Raw equivalent if you don't have `just`:

```bash
podman build --pull=newer -t ublue-gharden91:latest -f Containerfile .
```

## Check Justfile syntax

```bash
just check
```

## Test the image

Confirm a package installed (e.g. PlasmaZones — see `docs/plasmazones.md`):

```bash
podman run --rm ublue-gharden91:latest rpm -q plasmazones
```

List the files a package installed:

```bash
podman run --rm ublue-gharden91:latest rpm -ql plasmazones
```

Poke around the whole filesystem in a shell:

```bash
podman run --rm -it ublue-gharden91:latest bash
```

> **Note:** desktop components like KWin extensions can't be exercised in a
> headless container — the container test only confirms the package and its
> files are present. To see PlasmaZones actually working you need to boot the
> image (see below) into a Plasma session.

## Build a bootable disk image (optional)

The container test above is enough to verify a package installs. To actually
boot the image in a VM, build a disk image instead:

```bash
just build-qcow2   # VM disk image
just build-iso     # installer ISO
just build-raw     # raw disk image
```

## Verifying the whole thing built

A successful `just build` ends with `bootc container lint` passing and prints
`Successfully tagged localhost/ublue-gharden91:latest`.
