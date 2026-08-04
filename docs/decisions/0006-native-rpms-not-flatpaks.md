# ADR-0006: Ship desktop apps as native RPMs baked in, not Flatpaks

- **Status:** Accepted
- **Date:** 2026-07-19
- **Scope:** repo
- **Shipped in:** #10 (Edge established the pattern; Discord and VLC followed).
  Edge was later dropped entirely — see ADR-0013 — but the native-RPM decision
  stands for Discord and VLC.

## The question

For the GUI apps (Edge, Discord, VLC), the default Universal Blue path is a
Flatpak. The alternative is a native RPM installed into the image. ADR-0001
already settled *bake-in vs. runtime layering*; this settles *native RPM vs.
Flatpak* for desktop apps specifically.

## What we chose

Install desktop apps as native RPMs in `build_files/build.sh`. Native packaging
gives full system integration that the Flatpak sandbox degrades: Edge's native
messaging (password managers, SSO/PIV/smartcard), Discord's tray/keybinds/rich
presence from local games, and VLC's direct access to the hardware video
acceleration (VA-API/VDPAU) the base image already configures.

## What we turned down

| Option | Why not |
|---|---|
| Flatpak for each app | The sandbox degrades exactly the integration these apps are wanted for (native messaging, tray, rich presence, direct HW accel). Remains a documented *fallback* per app (see `docs/edge.md` Options) if a native RPM path becomes untenable. |

## What would change our mind

Decided per app, not as a blanket reversal:

- An app's native RPM fights the immutable image badly enough that Flatpak is
  the only clean path (the Edge `/opt` fight, ADR-0007, came close — and Edge
  was ultimately removed from the image altogether, ADR-0013, rather than
  switched to Flatpak).
- An app only ships a Flatpak, or drops its RPM.
