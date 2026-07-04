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

Confirm a package installed (e.g. PlasmaZones — see `docs/plasmazones.md`):

```bash
podman run --rm ublue-gharden91:latest rpm -q plasmazones
```

List the files a package installed:

```bash
podman run --rm ublue-gharden91:latest rpm -ql plasmazones
```

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
podman run --rm -it ublue-gharden91:latest bash
```

> **Note:** desktop components like KWin extensions can't be exercised in a
> headless container — the container test only confirms the package and its
> files are present. To see PlasmaZones actually working you need to boot the
> image (see below) into a Plasma session.

## Build a bootable disk image (optional)

The container test above is enough to verify a package installs. To actually see if the gui works, run.

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

## Boot the image in a VM

Boot the built qcow2 in an ephemeral QEMU VM:

```bash
just run-vm-qcow2   # alias: just run-vm
```

Notes:

- It builds the qcow2 first if `output/qcow2/disk.qcow2` doesn't exist, so this
  one command covers both build and boot.
- The VM is served over a **web VNC console in your browser**, not a native
  window. It prints `Connect to http://localhost:<port>` (port starts at 8006)
  and auto-opens that URL after ~30s. If the browser doesn't open, visit the URL
  manually.
- Specs are hardcoded in the recipe: 4 cores, 8G RAM, 64G disk, TPM + GPU
  enabled, using `/dev/kvm` (virtualization must be enabled on the host).
- The VM is ephemeral (`--rm`) — Ctrl-C in the terminal discards it.
- It boots `localhost/ublue-gharden91:latest`, i.e. whichever branch you built
  last. To test features from multiple branches together, merge them first, then
  rebuild.

What to check once it boots:

1. It reaches a Plasma login/desktop (confirms the image boots).
2. PlasmaZones loads — *System Settings > Window Management > KWin Scripts /
   Effects*, or drag a window to a screen edge to see zones. This can only be
   verified in a real session, not a container.
3. Any CLI tools run as a normal user (e.g. open a terminal and run the tool
   directly).

## Verifying the whole thing built

A successful `just build` ends with `bootc container lint` passing and prints
`Successfully tagged localhost/ublue-gharden91:latest`.
