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

Build with a specific PowerShell version (see `docs/powershell.md`):

```bash
PWSH_VERSION=7.5.2 just build
```

Changing `PWSH_VERSION` re-downloads that tarball; otherwise rebuilds are fast.

Raw equivalent if you don't have `just`:

```bash
podman build --pull=newer -t ublue-gharden91:latest -f Containerfile .
```

## Check Justfile syntax

```bash
just check
```

## Test the image

Print the PowerShell version table (the main smoke test for our changes):

```bash
podman run --rm -e HOME=/tmp ublue-gharden91:latest pwsh -c '$PSVersionTable'
```

Just the version string:

```bash
podman run --rm -e HOME=/tmp ublue-gharden91:latest pwsh -c '$PSVersionTable.PSVersion.ToString()'
```

Interactive PowerShell session:

```bash
podman run --rm -it -e HOME=/tmp ublue-gharden91:latest pwsh
```

Poke around the whole filesystem in a shell:

```bash
podman run --rm -it -e HOME=/tmp ublue-gharden91:latest bash
```

> **Note on `-e HOME=/tmp`:** running `pwsh` as root in a bare container fails
> with `Could not find a part of the path '/root/.cache'` because that dir
> doesn't exist. Pointing `HOME` at a writable path avoids it. This is a
> container-run artifact only — on a real booted system the path exists and
> `pwsh` starts normally.

## Build a bootable disk image (optional)

The container test above is enough to verify software installs. To actually
boot the image in a VM, build a disk image instead:

```bash
just build-qcow2   # VM disk image
just build-iso     # installer ISO
just build-raw     # raw disk image
```

## Verifying the whole thing built

A successful `just build` ends with `bootc container lint` passing and prints
`Successfully tagged localhost/ublue-gharden91:latest`.
