# ADR-202611061451: Ship the stable-45 base bump on build-tier verification, without a VM boot

- **Status:** Accepted
- **Date:** 2026-11-06
- **Scope:** base image (`Containerfile` `BAZZITE_VERSION`)
- **Shipped in:** #72 (closes #71)

## The question

ADR-0011 says desktop-visible changes are verified by a boot, and the
base-image-bump template sets a VM boot as the minimum for a Fedora bump. The
44 → 45 bump got a green CI build but no boot. Should it wait for one?

## What we chose

Merge on the CI build alone; the owner chose to skip the VM boot. This is a
deliberate, one-off exception to ADR-0011, not a relaxation of it. What made
the risk acceptable:

- The build's PlasmaZones skew check, the one build-time signal aimed at the
  desktop, passed (`plugin embeds KWin 6.8.x=[6.8.2]` → matches image KWin
  6.8.2). On `stable-44`, `main` was already warning of a mismatch, so zones
  were probably already inert there. The bump fixes a likely-broken state
  instead of putting a working one at risk.
- `bootc container lint` showed the same four warnings as the `stable-44`
  build; nothing new.
- A bad deployment is undone with `bootc rollback` to the previous Fedora 44
  image.

What it means: until someone boots it, nobody has seen Plasma, PlasmaZones,
Edge, Discord, or VLC work on the Fedora 45 image. The first real-hardware
boot after merge is the verification. Treat any desktop regression from then
on as possibly this bump.

## What we turned down

| Option | Why not |
|---|---|
| VM boot before merge (ADR-0011's default) | Owner's call: not worth the time for this bump, given the skew check passed and rollback is one command |
| Stay on `stable-44` until a boot is done | Floating `stable` is already on 45, and the F44 image was likely shipping inert PlasmaZones |

## What would change our mind

- A desktop regression traced to this bump: then the next base bump gets a VM
  boot before merge, no exceptions.
- This is not a precedent. The next Fedora bump (`stable-46`) defaults back to
  ADR-0011 and the template's VM-boot minimum unless a new record says otherwise.
