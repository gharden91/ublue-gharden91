# ADR-0013: Drop native Edge and revert `/opt` to the base symlink

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** edge
- **Supersedes:** ADR-0007
- **Shipped in:** #17

## The question

ADR-0007 made `/opt` a real immutable directory (`RUN rm /opt && mkdir /opt`)
solely so Microsoft Edge's RPM — which hardcodes `/opt/microsoft/msedge` and has
no tarball alternative — could unpack at build time. That was the riskiest
single change in the image: it replaces the base `/opt -> /var/opt` symlink that
`bazzite-dx` itself uses for `/var/opt` container state. ADR-0007 accepted that
risk *because Edge was worth it*. Issue #17 reports Edge is not: the native
install shows the **same** Chromium color-emoji tofu as the distrobox build
(root cause is COLRv1, image-wide — ADR-0010 / `docs/fonts.md`), so shipping it
natively buys the `/opt` risk for no gain over distrobox.

## What we chose

**Remove `microsoft-edge-stable` from `build_files/build.sh` and revert `/opt`
to the base's `/opt -> /var/opt` symlink** (delete the `rm /opt && mkdir /opt`
line). No other packaged app installs into `/opt` — PowerShell goes to `/usr`
(ADR-0002), VLC/Discord/tmux land under `/usr` — so once Edge is gone the real
immutable `/opt` has no remaining reason to exist, and reverting it removes the
containerd/`/var/opt` risk ADR-0007 was carrying. Edge remains available via
distrobox for anyone who wants it, exactly as before ADR-0007.

This is the exact reversal ADR-0007 named in its own *What would change our
mind*: "Edge is dropped from the image … the `rm /opt && mkdir /opt` line should
go with it."

## What we turned down

| Option | Why not |
|---|---|
| Keep native Edge, keep immutable `/opt` (status quo, ADR-0007) | Carries the `/var/opt`/containerd risk for an app that doesn't escape the font problem it was partly wanted to dodge. |
| Drop Edge but keep immutable `/opt` | Keeps the risk with nothing left that needs it — pure downside. |
| Ship Edge as a Flatpak instead | Avoids `/opt`, but reintroduces the sandbox integration loss ADR-0006 exists to avoid, for an app we've decided isn't pulling its weight. Still the documented fallback if native Edge is ever wanted again. |

## Notes on the font issue

Removing Edge does **not** fix the color-emoji bug: it is Chromium-wide and VS
Code (Electron, shipped by the base image) still exhibits it — see ADR-0010 and
`docs/fonts.md`. Removing Edge shrinks the affected surface, it doesn't cure it.

There is a **thin, untested possibility** that reverting immutable `/opt` also
improves VS Code: `docs/fonts.md` records that the same emoji font works from
`~/.local/share/fonts` but not from `/usr/share/fonts`, and lists Chromium's
sandbox font-directory access on a bootc image "where Edge lives in `/opt`" as
an unexplored lead. Making `/opt` real may have had unforeseen downstream
effects on how Chromium apps see fonts. This is a hypothesis, not a claim —
only a boot test with no user-level font installed can confirm or kill it.

## What would change our mind

- A future app only ships an RPM that installs into `/opt` and is worth having —
  then immutable `/opt` comes back (revisiting the ADR-0007 containerd concern),
  and Edge could ride along again.
- Edge fixes the Chromium emoji rendering (or Fedora reverts to CBDT), removing
  the "no gain over distrobox" argument — then native Edge is worth reconsidering
  under ADR-0006's per-app native-RPM rule.
