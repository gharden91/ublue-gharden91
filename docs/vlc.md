# VLC Media Player

## Intent

Ship VLC in the image with full codec support (including patent-encumbered
formats like H.264/H.265) so media playback works out of the box on every
machine, without per-machine Flatpak installs or codec hunting.

## What it does

`build_files/build.sh` installs VLC from negativo17's `fedora-multimedia`
repo, enabled for that single transaction:

```bash
dnf5 install -y --enable-repo="*fedora-multimedia*" vlc
```

## Decisions

- **negativo17, not RPM Fusion.** The first attempt installed
  `vlc` + `vlc-plugins-freeworld` per the usual Fedora recipe (and what
  [VideoLAN's Fedora page](https://www.videolan.org/vlc/download-fedora.html)
  prescribes) — and the build failed: `No match for argument:
  vlc-plugins-freeworld`. Bazzite does **not** ship RPM Fusion. Its entire
  multimedia stack (full ffmpeg and friends) comes from
  [negativo17's fedora-multimedia repo](https://negativo17.org/multimedia/)
  instead, and negativo17 explicitly documents the two ecosystems as
  incompatible — adding RPM Fusion on top would risk package conflicts with
  the base image. negativo17's own `vlc` build is fully featured against that
  same stack, so there is no codec add-on package to install at all.
- **Per-transaction repo enable.** The `fedora-multimedia` `.repo` file is
  baked into the bazzite image but left `enabled=0` (bazzite disables all
  third-party repos at the end of its build). Rather than re-enabling it
  globally and disabling it again (the Edge pattern), `--enable-repo` scopes
  it to the one install — this is the same pattern bazzite's own Containerfile
  uses for its multimedia installs, and the repo stays disabled in the final
  image with zero cleanup.
- **Native RPM, not Flatpak.** Consistent with the rest of this image (Edge,
  Discord): everything ships baked in, with direct access to the system's
  hardware video acceleration (VA-API/VDPAU) that bazzite already configures.
- **No pinning.** The version tracks whatever `fedora-multimedia` carries at
  build time, same as the rest of the base image's multimedia stack it must
  stay in lockstep with.

## Maintenance

- **The baked-in repo file keeps its name.** `--enable-repo="*fedora-multimedia*"`
  matches the `negativo17-fedora-multimedia.repo` file bazzite ships. If
  bazzite renames it or drops negativo17 entirely (e.g. moves back to RPM
  Fusion), the glob matches nothing, `vlc` won't resolve from it, and the
  build breaks outright — loudly, not silently. Re-check which multimedia
  repo the base image carries and adjust.
- **Stay off RPM Fusion for multimedia.** Any future customization that
  enables RPM Fusion for codec-adjacent packages can conflict with the
  negativo17 stack the base image is built on. Prefer `fedora-multimedia`
  (or plain Fedora repos) for anything touching ffmpeg/codecs.
