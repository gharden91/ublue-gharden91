# Discord

## Intent

Ship the official Discord client natively in the image so it is present on
every machine without per-machine setup, with working system integration
(tray icon, notifications, keybinds, rich presence from local games) that the
Flatpak sandbox can degrade.

## What it does

`build_files/build.sh` downloads Discord's official RPM from the stable
"latest" endpoint and installs it with `dnf5`:

```
https://discord.com/api/download?platform=linux&format=rpm
```

The endpoint redirects to the current release on `dl.discordapp.net`
(`discord-<version>.rpm`); `curl -fL` follows the redirect. The installed
version is echoed into the build log (`Installed Discord version: ...`).

## Decisions

- **Official RPM, not Flatpak.** Matches the pattern used for Edge: native
  packaging for full desktop/system integration. The Flatpak remains a valid
  fallback if the RPM path ever becomes a problem (see Options in
  [edge.md](./edge.md) for the same trade-off discussion).
- **Official RPM, not RPM Fusion's `discord` package.** RPM Fusion nonfree
  repackages the same client, but lags upstream releases. Because Discord
  hard-gates outdated clients (see below), a lagging package means a client
  that refuses to launch until RPM Fusion catches up. The official endpoint is
  always current at build time.
- **Deliberately NOT version-pinned** — the one exception to this repo's
  pinning convention (PowerShell, PlasmaZones). Discord requires the current
  client version: when a new release ships, older clients show a mandatory
  "update required" screen and refuse to run. A pinned version would therefore
  brick the app between manual bumps. Fetching latest at build time means each
  image rebuild carries the then-current client.
- **No self-updating.** The RPM's update path on a mutable distro is to
  download the next RPM manually; on this image `/usr` is immutable, so the
  client updates only via image rebuilds — which is exactly the behavior we
  want (same stance as Edge with its repo disabled).

## Maintenance

- **Rebuild cadence is load-bearing.** Because Discord gates old clients,
  users get the "update required" screen whenever Discord releases a new
  version and the machine hasn't yet rebased onto a rebuilt image. Discord
  releases land every few weeks. If the scheduled image rebuilds ever stop
  (broken CI, disabled workflow), Discord is the first thing users will notice
  breaking — a stalled pipeline shows up as "Discord won't start."
- **Unpinned download = non-reproducible builds.** Two builds of the same git
  commit can contain different Discord versions. Accepted consequence of the
  gating behavior above.
- **URL shape.** The build assumes
  `https://discord.com/api/download?platform=linux&format=rpm` keeps
  redirecting to an installable RPM. If Discord renames or drops the RPM
  flavor, the build breaks outright (loudly, thanks to `curl -f`).
- **No GPG verification.** The endpoint serves the RPM over HTTPS but the
  package is installed as a local RPM without a vendor GPG key (Discord does
  not publish a yum repo or signing key). Trust anchor is TLS to discord.com,
  same as the PlasmaZones GitHub-release RPM.
- **x86_64 only.** Discord publishes no Linux ARM64 build; if this image is
  ever built for ARM64, this install must be made conditional on target arch.
