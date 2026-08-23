# ADR-202608230454: Re-supply OCI labels explicitly in the rootless `ostree-rechunk`

- **Status:** Accepted
- **Date:** 2026-08-23
- **Scope:** repo
- **Shipped in:** #48

## The question

#45 ported the upstream template's rootless rewrite of `ostree-rechunk`: instead
of `--from localhost/${target_image}:${tag}` against a pulled
`quay.io/fedora/fedora-bootc:latest` helper image, it mounts the already-built
local image directly (`--mount=type=image` → `--rootfs /rpm-ostree`) so
`rpm-ostree compose build-chunked-oci` can run `--pull=never`, unprivileged.

Local testing on the merged port (`just build && just ostree-rechunk`, then
`podman image inspect`) showed the rechunked image had lost every custom OCI
label — not just the three base-provenance ones #33/#45 cared about
(`org.opencontainers.image.base.name`/`.base.digest`,
`org.ublue-gharden91.base-image.version`), all of them, including the
ArtifactHub metadata and `org.opencontainers.image.title`. Only rpm-ostree's
own auto-generated labels (`containers.bootc`, `ostree.commit`,
`ostree.final-diffid`) survived. CI's green build never caught this — it
doesn't inspect labels, only that the build succeeds — which is exactly the
gap #33 already flagged as open.

Root-caused against rpm-ostree's own source: `compose build-chunked-oci`'s
label-propagation fix (upstream rpm-ostree#5343) reads the source image's
`Config.Labels` and is gated on `self.from.is_some()` — it only fires in
`--from` mode. In `--rootfs` mode there is no OCI image config to read at
all; a mounted rootfs is just a filesystem tree, and labels are image
manifest/config metadata, not file content. The old recipe's `--from` mode
is *why* labels survived rechunk before, and switching to `--rootfs` for the
rootless win lost that as an unexamined side effect.

## What we chose

Read the source image's labels back explicitly with `podman image inspect`
before rechunking, and re-supply them to `compose build-chunked-oci` via
repeated `--label KEY=VALUE` flags (upstream rpm-ostree#5454, added
specifically for this gap), filtering out rpm-ostree's own auto-generated
labels (`containers.bootc`, `ostree.*`) so they don't collide with what the
tool (re)writes itself regardless of what's passed in.

Confirmed working on real hardware: `just build && just ostree-rechunk` then
`podman image inspect` shows the full label set intact, including all three
base-provenance labels.

## What we turned down

| Option | Why not |
|---|---|
| Revert `ostree-rechunk` to `--from` mode | Throws away #45's whole point — the rootless/`--pull=never` rewrite this port exists for. Would re-introduce the root requirement and the `sudo -E` CI wrapping #45 was written to remove. |
| Accept the label loss as a known limitation | Fails #45's own acceptance criteria and #33's concern outright — reconciliation (`docs/provenance.md`) silently stops working the moment this recipe runs, with no error or signal. Not a tradeoff worth making quietly. |
| Re-derive the labels from scratch inside `ostree-rechunk` (duplicate the `build` recipe's `LABELS` array) | Works but doubles the maintenance surface — two places computing the same label set, guaranteed to drift. Reading them back from the already-built image is one line and can't disagree with what `build` actually stamped. |

## What would change our mind

If a future rpm-ostree drops `--label` support from `compose build-chunked-oci`
or changes its semantics, this needs re-diagnosing — check the CLI's own
`--help` output against what this recipe assumes. If #33 ever adds an
automated CI check for label survival, that check should also cover *this*
mechanism specifically (a rechunk that "succeeds" but silently drops labels is
exactly the failure mode this record exists to prevent from recurring
unnoticed).
