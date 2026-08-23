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

Build with a specific PowerShell or PlasmaZones version (see
`docs/powershell.md` / `docs/plasmazones.md`):

```bash
PWSH_VERSION=7.5.2 just build
PLASMAZONES_VERSION=3.1.3 just build
```

Changing either version re-downloads that release; otherwise rebuilds are fast.

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

## Poke around inside the built image

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

> **For local iteration, prefer `build-raw` over `build-qcow2`.** Both run the
> same `bootc-image-builder` pipeline; `build-qcow2` adds a `qemu-img convert
> -c` compression pass afterward, which is usually the single biggest chunk of
> wall-clock time for a disk this size (`minsize = 20 GiB` in
> `disk_config/disk.toml`) — skipping it is what actually makes local testing
> fast. Trade-off: `output/raw/disk.raw` is the disk's full uncompressed size
> on disk instead of qcow2's compressed size, so it eats more local space
> while you iterate (see "Clean up local build artifacts" below). Reach for
> `build-qcow2` only when you specifically need the compact file.

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

### Boot the raw image instead — the fast path

```bash
just run-vm-raw
```

Same `_run-vm` recipe as `run-vm-qcow2` and every note above applies
unchanged (web VNC, hardcoded specs, ephemeral, boots whatever you built
last) — it's just pointed at `output/raw/disk.raw` instead of
`output/qcow2/disk.qcow2`, and builds that with `build-raw` first if it's
missing. There's no `run-vm`-style short alias for it, so type the full name.
This is the pairing to reach for while iterating: `just run-vm-raw` alone
builds (skipping the qcow2 compression pass) and boots in one command.

The Alpine-boot bug below is specific to `bootc-image-builder`'s *compressed*
qcow2s, so it doesn't apply to raw images — moot in practice either way,
since `_run-vm` pins the same known-good runner tag for every image type.

### If the VM boots Alpine instead of the image

**Fixed by pinning — see below if it recurs.** `qemux/qemu` **7.37**
(2026-07-19) added a GPT probe to its boot detection that rejects
`bootc-image-builder`'s compressed qcow2s with:

```
ERROR: Failed to read the complete GPT partition entry array!
❯ Retrieving latest Alpine Linux version...
```

It then silently downloads and boots Alpine, so you land at an Alpine login
prompt instead of the image. **The disk is fine** — `qemu-img check` passes; the
probe is what's wrong. Rebuilding the image does not help.

`_run-vm` therefore pins `docker.io/qemux/qemu:7.36`, the newest tag that
predates the probe (7.33–7.36 have no such code), and uses `--pull=missing` so
`latest` is not silently pulled back in. As of 2026-08-04 the bug is still
present in `latest` (7.43), and upstream has no commit addressing it.

To retest a newer release without editing the Justfile:

```bash
VM_RUNNER_IMAGE=docker.io/qemux/qemu:latest just run-vm
```

If a fixed release appears, bump the pinned tag in `_run-vm`. To confirm whether
a given tag has the offending probe:

```bash
podman run --rm --entrypoint bash docker.io/qemux/qemu:TAG \
  -c 'grep -c "GPT partition entry array" /run/install.sh'
```

`0` means the tag is safe.

Fallback that bypasses the runner container entirely — boot the disk with host
QEMU from the repo root:

```bash
qemu-system-x86_64 -enable-kvm -m 8G -smp 4 -cpu host \
  -drive file=output/qcow2/disk.qcow2,format=qcow2 \
  -bios /usr/share/OVMF/OVMF_CODE.fd
```

(UEFI firmware is required; no web VNC — QEMU opens a native window.)

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

## Clean up local build artifacts

Disk-image builds are big — each qcow2 is ~7–8 GB, and a raw image runs
larger still (`output/raw/disk.raw` is uncompressed, closer to the
`minsize = 20 GiB` filesystem itself) — and they accumulate fast. Two things
pile up in the repo root:

- `output/` — the finished disk images (`output/qcow2/disk.qcow2`,
  `output/raw/disk.raw`).
- `_build-bib.*` — temp dirs `bootc-image-builder` creates. Normally moved into
  `output/` and removed at the end of a build, but an **interrupted or failed
  build leaves them behind**, each holding a full-size disk image.

Both are gitignored, so `git status` will not warn you about tens of GB sitting
there. Check with `du -sh output _build-bib.*` and clean up with:

```bash
just sudo-clean
```

Use `sudo-clean`, not plain `just clean`: the temp dirs are created by a rootful
`podman run`, so their contents are root-owned and an unprivileged `rm` fails on
them. (`just clean` is fine when only `output/` exists.) Both also remove
`previous.manifest.json`, `changelog.md`, and `output.env`.

> **Why a stale `output/` matters:** `just build-qcow2` finishes by moving its
> temp dir into `output/`, which fails with `mv: cannot overwrite 'output/qcow2':
> Directory not empty` if a previous build's output is still there. The build
> itself succeeds and then the recipe exits 1 at the very last step — so a
> "failed" qcow2 build is often just this. Run `just sudo-clean` and rebuild.

Podman image layers are separate and not touched by `just clean`. To reclaim
that space:

```bash
podman image prune          # dangling layers only
podman rmi localhost/ublue-gharden91:latest
```

Removing the base image forces a multi-GB re-pull on the next build, so keep it
unless you actually need the space.
