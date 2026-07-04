# Microsoft Edge

> **Status: ON HOLD (not merged).** Work-in-progress lives on the `add-edge`
> branch. The native-RPM approach works but forces `/opt` immutable, which is
> risky on the current `bazzite-dx` base (see the blocker below). Held pending a
> decision. Continue to use Edge via distrobox until this is resolved.

## Intent

Ship Microsoft Edge (stable) so it is present on every machine that rebases to
this image, without per-machine setup — ideally as a native RPM so features like
native messaging (password managers, SSO/PIV/smartcard) and system integration
work, which the Flatpak sandbox degrades.

## What the `add-edge` branch does

- `build_files/build.sh`: adds Microsoft's Edge RPM repo
  (`https://packages.microsoft.com/yumrepos/edge`), installs
  `microsoft-edge-stable`, then force-disables the repo with
  `sed -i 's/^enabled=1/enabled=0/'` (the Edge package ships and re-enables its
  own `.repo` for self-update, so `dnf5 config-manager setopt` was not enough).
- `Containerfile`: `RUN rm /opt && mkdir /opt` — makes `/opt` a real directory.

Both build successfully and produce a working `microsoft-edge-stable`
(symlinked at `/usr/bin/microsoft-edge-stable`) with the repo left `enabled=0`.

## The blocker: `/opt` immutability vs. bazzite-dx

The Edge RPM hardcodes its install path to `/opt/microsoft/msedge` and has no
tarball alternative (unlike PowerShell, which we put in `/usr` — see
[powershell.md](./powershell.md)). On atomic images `/opt` is a symlink to the
mutable `/var/opt`, and the Edge RPM's cpio unpack fails against that symlink:

```
[RPM] failed to open dir opt of /opt/microsoft/: cpio: mkdir failed - File exists
```

The only clean fix is `RUN rm /opt && mkdir /opt`, making `/opt` a real,
immutable directory (re-provisioned every deploy, so Edge stays updatable across
rebuilds).

**Why that is risky on this base:** `bazzite-dx` itself uses `/var/opt`. On a
running machine:

```
$ ls -la /opt && ls -la /var/opt
lrwxrwxrwx  /opt -> var/opt
drwx--x--x  /var/opt/containerd
```

`/var/opt/containerd` is container-runtime state that bazzite-dx put there
through the `/opt` symlink. If we replace the symlink with an empty real `/opt`,
anything expecting to reach that data at `/opt/containerd` may break (the data
still exists in persistent `/var/opt`, but is no longer reachable via `/opt`).

The Containerfile's own comment about making `/opt` immutable assumed a base
where only *we* write to `/opt` — bazzite-dx violates that assumption.

## Options (decision pending)

1. **Test immutable `/opt` in a VM first.** Boot the `add-edge` image and verify
   the container runtime survives:
   ```bash
   systemctl status containerd docker
   docker info        # or: podman info
   ls -la /opt /var/opt
   ```
   If containerd/docker still work → immutable `/opt` is safe here; merge as-is
   and get native Edge. If they break → abandon this approach.

2. **Ship Edge as a Flatpak instead.** Flatpaks live in `/var/lib/flatpak`, so
   this avoids `/opt` entirely and leaves bazzite-dx's `/var/opt`/containerd
   untouched. The image would ship a Flatpak *list* (via `system_files/` + the
   ublue flatpak-manager) or a first-boot systemd unit running
   `flatpak install flathub com.microsoft.Edge` — Edge is not baked into the
   image, it is installed on first boot. Downside: the sandbox integration
   compromises we were trying to avoid.

3. **Keep Edge in distrobox** (current state). Zero image risk; no change.

## Longer-term idea: roll our own `-dx`

The `/opt`/containerd conflict exists because `bazzite-dx` brings the dev/container
tooling that populates `/var/opt`. A future option is to base off plain
`bazzite` (empty `/var/opt`) and add back only the dev tools actually used —
which would make immutable `/opt` (and native-RPM Edge) clean again. This trades
inherited complexity for explicit, self-maintained complexity, so it is only
worthwhile if we use a thin slice of `-dx`. Deferred as a deliberate future
project, not an Edge-driven emergency.

## Maintenance (if the native-RPM path is eventually adopted)

- **Update:** Edge follows Microsoft's `edge` repo; rebuilding the image installs
  whatever `microsoft-edge-stable` is current at build time. With the repo
  disabled, Edge's own self-updater will not run — updates come from image
  rebuilds only.
- **GPG key:** imported from `https://packages.microsoft.com/keys/microsoft.asc`.
