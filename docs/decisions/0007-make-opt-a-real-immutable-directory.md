# ADR-0007: Make `/opt` a real immutable directory to allow native Edge

- **Status:** Accepted
- **Date:** 2026-07-19
- **Scope:** edge
- **Shipped in:** #10

## The question

Microsoft Edge's RPM hardcodes its install into `/opt/microsoft/msedge` with no
tarball alternative (unlike PowerShell, ADR-0002). On this base `/opt` is a
symlink to `/var/opt`, and the RPM's cpio unpack fails against it
(`mkdir failed - File exists`). To ship Edge as a native RPM (ADR-0006) we have
to change what `/opt` is.

## What we chose

`RUN rm /opt && mkdir /opt` in the `Containerfile` — replace the symlink with a
real, immutable `/opt` directory that's re-provisioned every deploy, so Edge
stays updatable across rebuilds. This directly contradicts the constraint that
blocked the same move for PowerShell in ADR-0002; the difference is that
PowerShell *had* a `/usr` tarball and Edge does not, so Edge is worth the risk
that PowerShell wasn't.

**Validated in a VM (2026-07-19):** on a fresh install, docker/containerd work,
`/var/opt` is empty, and Edge runs. The existing-machine caveat
(`/var/opt/containerd` becoming unreachable via `/opt`) was checked on real
hardware and cleared — it's 0-byte auto-created dirs, nothing references
`/opt/containerd` by path. Full evidence in `docs/edge.md`.

## What we turned down

| Option | Why not |
|---|---|
| Leave `/opt` as the `/var/opt` symlink | Edge's RPM can't unpack into it at build time — no native Edge at all. |
| Ship Edge as a Flatpak | Avoids `/opt` entirely, but reintroduces the sandbox integration loss ADR-0006 exists to avoid. Kept as the fallback. |
| Keep Edge in distrobox (prior state) | Zero image risk, but not present out-of-the-box and same sandbox-ish limitations. |

## What would change our mind

- A base app turns out to depend on reaching `/var/opt` state through `/opt`
  (the containerd concern) — then the immutable `/opt` breaks it and this
  reverts.
- **Edge is dropped from the image.** [Issue #17](https://github.com/gharden91/ublue-gharden91/issues/17)
  is actively weighing removing Edge over persistent Chromium font issues (see
  ADR-0010 / `docs/fonts.md`); if Edge goes and nothing else needs `/opt`, the
  `rm /opt && mkdir /opt` line should go with it. This decision is genuinely
  live, tracked in the issue — not settled dogma.
