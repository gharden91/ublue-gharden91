# Microsoft Edge

Microsoft Edge (stable) ships in this image as a **native RPM**, installed from
Microsoft's own repo at build time. It is the reason `/opt` is a real directory
rather than the base's symlink — see [ADR-0007](decisions/0007-make-opt-a-real-immutable-directory.md).

## Intent

Ship Edge so it is present on every machine that rebases to this image, without
per-machine setup, and as a native RPM so features the Flatpak sandbox degrades
— native messaging (password managers, SSO/PIV/smartcard) and desktop
integration — work normally. This follows the general rule in
[ADR-0006](decisions/0006-native-rpms-not-flatpaks.md).

## How it is installed

`build_files/build.sh`:

- imports Microsoft's GPG key from `https://packages.microsoft.com/keys/microsoft.asc`;
- writes `/etc/yum.repos.d/microsoft-edge.repo` pointing at
  `https://packages.microsoft.com/yumrepos/edge`;
- installs `microsoft-edge-stable`;
- force-disables the repo afterwards with `sed -i 's/^enabled=1/enabled=0/'`.

The `sed` is deliberate and load-bearing: the Edge package **ships and re-enables
its own `.repo` file** for self-updating, so `dnf5 config-manager setopt` is not
enough. Leaving it enabled would violate the repo-wide invariant that no
third-party repo stays enabled on the final image.

`Containerfile` carries `RUN rm /opt && mkdir /opt`.

The result is `microsoft-edge-stable` on `PATH` via
`/usr/bin/microsoft-edge-stable -> /opt/microsoft/msedge/microsoft-edge`.

## Why `/opt` has to be a real directory

The Edge RPM hardcodes its install path to `/opt/microsoft/msedge` and offers no
tarball alternative (unlike PowerShell, which we put in `/usr` —
[powershell.md](./powershell.md), [ADR-0002](decisions/0002-powershell-into-usr-via-tarball.md)).
On atomic images `/opt` is a symlink to the mutable `/var/opt`, and the RPM's
cpio unpack fails against that symlink:

```
[RPM] failed to open dir opt of /opt/microsoft/: cpio: mkdir failed - File exists
```

`RUN rm /opt && mkdir /opt` makes `/opt` a real, immutable directory,
re-provisioned every deploy, so Edge stays updatable across rebuilds.

### The containerd concern — checked, not a problem

`bazzite-dx` itself uses `/var/opt`, so replacing the symlink could in principle
strand data that the base wrote through `/opt`. Both halves were tested:

- **Fresh install (VM boot).** `/opt` contains only `microsoft/`; `/var/opt` is
  empty. `docker` and `containerd` are inactive at first boot (normal on-demand
  activation) and start cleanly on `sudo docker info`.
- **Existing machine.** `/var/opt/containerd` is 0 bytes — empty `bin/` and
  `lib/` directories that containerd's managed-opt plugin
  (`io.containerd.internal.v1.opt`) recreates at startup. No data, and nothing
  in the docker, containerd, or systemd configuration references
  `/opt/containerd` by path.

So rebasing an existing machine does not strand anything, and containerd runs
fine when it cannot create `/opt/containerd` at all.

## Edge and the color-emoji bug

Edge was once suspected of causing — or being implicated in — emoji tofu in
Chromium apps, and [issue #17](https://github.com/gharden91/ublue-gharden91/issues/17)
proposed dropping Edge and reverting `/opt` because of it. That was wrong: the
cause was a stale per-user `~/.cache/fontconfig`, unrelated to Edge or `/opt`.
See [fonts.md](./fonts.md) and
[ADR-0013](decisions/0013-emoji-bug-was-a-stale-user-font-cache.md).

## Maintenance

- **Updates come from image rebuilds only.** Edge is installed from Microsoft's
  repo at build time, and that repo is disabled on the final image, so Edge's
  own self-updater never runs. A rebuild installs whatever
  `microsoft-edge-stable` is current — the version is deliberately unpinned,
  like Discord ([ADR-0009](decisions/0009-discord-unpinned-official-rpm.md)).
- **The repo-disabling `sed` must keep matching.** It rewrites `enabled=1` in
  `/etc/yum.repos.d/microsoft-edge.repo`. If Microsoft changes that file's
  shape, the repo could silently ship enabled. Verify with
  `podman run --rm <image> grep enabled= /etc/yum.repos.d/microsoft-edge.repo`.
- **`/opt` stays real.** Anything that reverts `/opt` to the base symlink breaks
  the Edge install outright. See ADR-0007 before touching it.
- **x86_64 only.** The Microsoft repo used here publishes no ARM64 build; an
  ARM64 image would need this install made conditional on target arch.
