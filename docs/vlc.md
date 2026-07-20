# VLC Media Player

## Intent

Ship VLC in the image with full codec support (including patent-encumbered
formats like H.264/H.265) so media playback works out of the box on every
machine, without per-machine Flatpak installs or codec hunting.

## What it does

`build_files/build.sh` installs two packages straight from repos already
enabled in the base image:

```bash
dnf5 install -y vlc vlc-plugins-freeworld
```

- `vlc` — from the regular Fedora repos (VLC moved from RPM Fusion into
  Fedora proper as of Fedora 38+).
- `vlc-plugins-freeworld` — from RPM Fusion free, which the bazzite base
  image ships enabled. Adds the patent-encumbered codec plugins Fedora cannot
  legally carry.

This is also what VideoLAN's own
[Fedora download page](https://www.videolan.org/vlc/download-fedora.html)
prescribes — there is no separate VideoLAN repo or vendor package for Fedora.

## Decisions

- **Native RPM, not Flatpak.** Consistent with the rest of this image
  (Edge, Discord): everything ships baked into the image. Also gives VLC
  direct access to system codecs and hardware video acceleration
  (VA-API/VDPAU) that bazzite already configures.
- **No new repos, no pinning.** Both packages come from repos the base image
  already trusts and updates with it; the version simply tracks Fedora 44's
  package set on each rebuild. Nothing to pin, no third-party repo to
  disable afterwards.

## Maintenance

Very low. The only assumptions that could rot:

- **RPM Fusion free stays enabled in the base image.** If bazzite ever drops
  or renames its RPM Fusion setup, `vlc-plugins-freeworld` stops resolving and
  the build breaks outright (loudly, not silently).
- **Package split stays as-is.** If Fedora/RPM Fusion reshuffle the
  `vlc`/`vlc-plugins-freeworld` split (as happened when VLC entered Fedora
  proper), the package names here may need updating.
