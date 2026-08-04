# ADR-0001: Bake customizations into the image, not per-machine runtime layering

- **Status:** Accepted
- **Date:** 2026-07-03
- **Scope:** repo
- **Shipped in:** #3 (first customization; the principle governs all of them)

## The question

bootc gives two ways to add software: build it into the image (declarative, in
`build_files/build.sh`, deployed to every machine) or layer it per-machine at
runtime with `rpm-ostree install`. The first customization (PowerShell) forced
the choice, and every one since has followed it.

## What we chose

Bake permanent tools and apps into the image. Anything we want present on every
machine that rebases to this image — PowerShell, PlasmaZones, Edge, Discord,
VLC — is installed at build time: versioned in git, built once, deployed
everywhere, and reproducible from the `Containerfile`.

Runtime `rpm-ostree install` is reserved for throwaway experiments on a single
machine, not for anything the image is supposed to guarantee.

## What we turned down

| Option | Why not |
|---|---|
| Per-machine `rpm-ostree install` for everything | Undeclarative and unversioned — every machine drifts, nothing is reproducible, and "what's installed" lives nowhere in git. Defeats the point of shipping an image. |
| Flatpaks for the GUI apps | A real alternative for *desktop* apps specifically — split into its own decision (ADR-0006); rejected there for sandbox-integration reasons. |

## What would change our mind

- A tool that genuinely differs per machine (per-host licensing, hardware-keyed)
  and can't be baked in cleanly.
- An app whose native packaging is so hostile to an immutable `/usr` that
  layering or Flatpak is the only sane path — decided per app, not as a reversal
  of this principle.
