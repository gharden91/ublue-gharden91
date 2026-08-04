# Provenance: which Bazzite is this image built on?

This image's output tags look like `latest-20260804-c0de3dc` — a date and a
commit of *this* repo. That says nothing about the **base** it was built on,
and the `Containerfile`'s `FROM` tag floats: `bazzite-dx:stable-44` is pinned
to a Fedora release (ADR-0003) but moves within it roughly daily, and
`--pull=newer` resolves it to a digest at build time.

So every image records the base it resolved, as labels. Answering "which
Bazzite am I actually running?" is a label lookup, not a guess from dates.

## The three labels

| Label | Holds | Example |
|---|---|---|
| `org.opencontainers.image.base.name` | The base ref as written in the `Containerfile` | `ghcr.io/ublue-os/bazzite-dx:stable-44` |
| `org.opencontainers.image.base.digest` | The digest that ref resolved to **at build time** — the exact bytes | `sha256:dd0e324d…` |
| `org.ublue-gharden91.base-image.version` | Bazzite's own version string, from the base's own `org.opencontainers.image.version` | `44.20260803` |

The first two are the OCI-standard keys, so `skopeo` and `podman` understand
them without being told. The third is custom because OCI has no key for "the
upstream's human-readable version" — and that string is the one that lines up
with what Bazzite publishes.

Read alongside `org.opencontainers.image.version` (this image's own output tag)
you get the full link: **this output ← that base**.

These three are stamped unconditionally. The source/version labels are skipped
when the git tree is dirty, but base provenance is true regardless of local
state, so it's always recorded.

## What you're looking for

The answer to issue #18: given an output tag, find the Bazzite it came from.

```console
$ skopeo inspect docker://ghcr.io/gharden91/ublue-gharden91:latest \
    | jq '.Labels | {
        mine:  ."org.opencontainers.image.version",
        base:  ."org.opencontainers.image.base.name",
        ver:   ."org.ublue-gharden91.base-image.version",
        digest:."org.opencontainers.image.base.digest"
      }'
{
  "mine":   "latest.20260804-c1a542e",
  "base":   "ghcr.io/ublue-os/bazzite-dx:stable-44",
  "ver":    "44.20260803",
  "digest": "sha256:dd0e324d33b651a3e4b23af1739fd54abed597cd4d4a7727fa67f797caf893ed"
}
```

Read that as: *`ublue-gharden91` `latest.20260804-c1a542e` is built on
`bazzite-dx` `stable-44.20260803`.* That's the sentence #18 asked for. (That
output is real, copied from the first image built with these labels.)

Two things worth noticing in that example, because both are normal:

- **The dates don't match, and shouldn't.** Our build ran on 2026-08-04; the
  newest Bazzite at that moment was `44.20260803`. The base is published, then
  we build on it — expect the base version to lag our tag by a day or so. This
  offset is exactly why guessing from dates was unreliable and the labels
  exist.
- **`base.name` is the floating tag, not a digest.** It records what the
  `Containerfile` asked for; `base.digest` records what that resolved to. The
  digest is the authoritative identity — a tag can be re-pointed later, a
  digest can't.

To go the other way — from a digest back to the base image — inspect it
directly:

```bash
skopeo inspect docker://ghcr.io/ublue-os/bazzite-dx@sha256:dd0e324d…
```

That still works even after `stable-44` has moved on, which a tag lookup
wouldn't.

## On this machine, once it's installed

You don't need root, network, or a registry pull. The image config is cached
in the deployment's commit metadata, so the labels of the **running** system
are readable locally:

```bash
rpm-ostree status --json \
  | jq -r '[.deployments[]|select(.booted==true)][0]."base-commit-meta"."ostree.container.image-config"' \
  | jq '.config.Labels | with_entries(select(.key|test("base|image.version")))'
```

This reports what you are *actually booted into*, which is the number that
matters when debugging — not what the registry currently calls `:latest`.
Those drift apart the moment a new build lands and you haven't rebooted.

The same metadata blob also carries the manifest digest of the image you
booted, useful for pinning down a rollback:

```bash
rpm-ostree status --json \
  | jq -r '[.deployments[]|select(.booted==true)][0] |
           ."base-commit-meta"."ostree.manifest-digest", .version'
```

`bootc status --format json` shows the booted image ref and digest too, but it
needs root and doesn't surface the labels — `rpm-ostree status` is the better
tool for this particular question.

### A locally-built image

`just build` prints the resolution as it happens:

```
Base image: ghcr.io/ublue-os/bazzite-dx:stable-44@sha256:dd0e324d… (upstream version 44.20260803)
```

and the built image carries the same labels:

```bash
podman image inspect ublue-gharden91:latest \
  --format '{{ json .Config.Labels }}' | jq
```

## Caveats

- **Images built before this landed have no base labels.** Anything older than
  `latest.20260804-c1a542e` predates the stamping; for those, the date-guessing
  problem from #18 still applies. Nothing can retroactively add them.
- **The labels survive rechunking.** `just ostree-rechunk` rewrites the image
  config, but build-time labels come through intact — confirmed on the
  published `latest.20260804-c1a542e`, which is post-rechunk and post-push.
- **The version string is whatever upstream set.** If a base build ever ships
  without `org.opencontainers.image.version`, ours records `unknown` rather
  than failing the build. The digest is still exact, so reconciliation is never
  actually lost — fall back to inspecting the digest directly.

## Why the base isn't just pinned instead

Digest-pinning the `FROM` line would make provenance trivial, and it was
considered and turned down — see
[ADR-0015](decisions/0015-update-cadence-tiers.md). In short: Bazzite moves
roughly daily, so pinning means either a daily bump PR of pure noise or an
ageing base, and it would put base **security** updates behind a manual merge.
The base is the one layer that should never wait on a human. These labels are
what make that safe: reconciliation after the fact, without a pin.
