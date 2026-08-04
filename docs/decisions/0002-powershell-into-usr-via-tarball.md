# ADR-0002: Install PowerShell into `/usr` via tarball, not `/opt` via RPM

- **Status:** Accepted
- **Date:** 2026-07-03
- **Scope:** powershell
- **Shipped in:** #3

## The question

PowerShell's official packaging is an RPM (and dnf repo) that installs into
`/opt/microsoft/powershell/7`. On a bootc/atomic image `/opt` is a symlink to
mutable, machine-persistent `/var/opt`, which changes what "installed" means.
How do we ship `pwsh` so it actually updates on every image rebuild?

## What we chose

Extract Microsoft's official `linux-x64` release **tarball** into
`/usr/lib/microsoft/powershell/7` and symlink `/usr/bin/pwsh`. `/usr` is
immutable and fully re-provisioned on every bootc deploy, so `pwsh` updates
cleanly with each rebuild, and `/opt` is left untouched for the base image's
apps. Version is pinned via `PWSH_VERSION`.

## What we turned down

| Option | Why not |
|---|---|
| Microsoft RPM into `/opt` | Files baked into `/var/opt` at build time are only seeded on *first boot* — later image updates wouldn't update them, stranding `pwsh` at whatever version first landed. |
| Make `/opt` immutable, then use the RPM | At the time, `bazzite-dx` bundles apps (docker-desktop, VS Code) that write to `/opt` at runtime, so we couldn't make it immutable without risking them. (This constraint later shifted for Edge — see ADR-0007 — but PowerShell had a clean tarball, so it never needed `/opt`.) |
| Add Microsoft's dnf repo | Hardcodes the `/opt` path anyway, and leaves Microsoft's repo config + GPG key enabled on the final image, which we don't want. |

The accepted tradeoff: the tarball does **not** auto-update; the pin is bumped
manually.

## What would change our mind

- Microsoft ships a tarball/RPM that installs into `/usr` (or a relocatable
  package), removing the `/opt` problem entirely.
- We build for ARM64 — the download URL hardcodes `linux-x64` and would need to
  become arch-conditional (this is a code fix, not a reversal of the decision).
