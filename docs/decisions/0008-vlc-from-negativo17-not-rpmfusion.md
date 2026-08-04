# ADR-0008: Install VLC from negativo17, not RPM Fusion

- **Status:** Accepted
- **Date:** 2026-07-20
- **Scope:** vlc
- **Shipped in:** #11

## The question

The usual Fedora recipe for a fully-codec'd VLC is `vlc` +
`vlc-plugins-freeworld` from RPM Fusion. The first attempt did exactly that and
the build failed: `No match for argument: vlc-plugins-freeworld`. Where does VLC
come from on this base?

## What we chose

Install `vlc` from negativo17's `fedora-multimedia` repo, enabled for that one
transaction: `dnf5 install -y --enable-repo="*fedora-multimedia*" vlc`. Bazzite
does **not** ship RPM Fusion — its entire multimedia stack (full ffmpeg and
friends) is negativo17's, and negativo17's `vlc` is built full-featured against
that same stack, so there's no `-freeworld` codec split to install at all. The
`.repo` file is baked in but left disabled; `--enable-repo` scopes it to the one
install with zero cleanup (the same pattern Bazzite's own Containerfile uses).

## What we turned down

| Option | Why not |
|---|---|
| RPM Fusion `vlc` + `vlc-plugins-freeworld` | Not present on Bazzite (build failed outright). Adding RPM Fusion on top would risk package conflicts — negativo17 explicitly documents the two multimedia ecosystems as incompatible. |
| Flatpak VLC | Loses the direct HW-accel integration and is inconsistent with the native-RPM stance (ADR-0006). |
| Global enable/disable of the repo (the Edge pattern) | Unnecessary here — `--enable-repo` per transaction is cleaner and leaves nothing enabled. |

## What would change our mind

- Bazzite renames `negativo17-fedora-multimedia.repo` or switches multimedia
  stacks — then the glob matches nothing and the build breaks loudly; re-point
  at whatever repo the base then carries.
- Bazzite adopts RPM Fusion as its multimedia base (unlikely) — the calculus
  flips. Until then, **keep RPM Fusion out** for any codec-adjacent package.
