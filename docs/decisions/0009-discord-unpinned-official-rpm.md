# ADR-0009: Install Discord unpinned from the official latest RPM

- **Status:** Accepted
- **Date:** 2026-07-20
- **Scope:** discord
- **Shipped in:** #11

## The question

Every other pinned install in this repo (PowerShell, PlasmaZones) is version-
pinned and bumped deliberately. Discord hard-gates outdated clients: when a new
version ships, older clients show a mandatory "update required" screen and
refuse to run. So how do we version Discord — and where do we get it?

## What we chose

Fetch the official RPM from Discord's stable "latest" endpoint
(`https://discord.com/api/download?platform=linux&format=rpm`) on every build,
**deliberately unpinned** — the one exception to this repo's pinning convention.
Each image rebuild carries the then-current client, which is exactly what
Discord's gating requires. Because `/usr` is immutable, Discord never
self-updates; updates arrive only via image rebuilds.

## What we turned down

| Option | Why not |
|---|---|
| Pin a Discord version (repo convention) | A pinned client would hit the "update required" wall and stop launching between manual bumps — i.e. pinning actively *bricks* this app. |
| RPM Fusion's `discord` package | Repackages the same client but lags upstream; combined with the gating, a lagging package = a client that refuses to launch until RPM Fusion catches up. |
| Flatpak Discord | Sandbox degrades tray/keybinds/rich-presence (ADR-0006). |

Accepted consequences: builds are **non-reproducible** (two builds of the same
commit can differ), and there's no vendor GPG repo (trust anchor is TLS to
discord.com). Both are spelled out in `docs/discord.md`.

## What would change our mind

- **Rebuild cadence is load-bearing.** This decision only works while scheduled
  image rebuilds keep running — if CI stalls, Discord is the first user-visible
  breakage ("Discord won't start" = the image hasn't rebuilt lately). If we ever
  can't guarantee cadence, revisit.
- Discord starts publishing a signed repo, or stops gating old clients — then
  pinning becomes viable again.
- Discord renames/drops the RPM flavor — the endpoint assumption breaks (loudly,
  thanks to `curl -f`).
