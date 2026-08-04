# ADR-0014: Pin the local VM runner image instead of tracking `latest`

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** local testing
- **Shipped in:** this commit

## The question

`just run-vm` boots a built qcow2 inside the `docker.io/qemux/qemu` container,
which the recipe pulled with `--pull=newer` — i.e. it tracked `latest`. Version
**7.37** (2026-07-19) added a GPT probe to its boot detection that cannot read
`bootc-image-builder`'s compressed qcow2s. It rejects the disk with
`Failed to read the complete GPT partition entry array!`, then **downloads and
boots Alpine Linux instead**.

That failure mode is the dangerous part: the VM comes up fine, so a hurried
reading is "the image booted." It is not the image. [ADR-0011](0011-rendering-claims-require-a-boot-test.md)
makes a boot test the *only* acceptable evidence for desktop-visible changes, so
a runner that silently substitutes a different OS undermines the one check that
rule depends on.

## What we chose

Pin the runner to `docker.io/qemux/qemu:7.36` — the newest tag published before
the probe existed — and switch that `podman run` from `--pull=newer` to
`--pull=missing` so `latest` cannot quietly return. The tag is overridable
(`VM_RUNNER_IMAGE=… just run-vm`) so a newer release can be retested without
editing the `Justfile`.

The disk was never at fault: `qemu-img check` passes and host QEMU boots the
same file into Bazzite. Only the runner's probe is wrong, so the fix belongs at
the runner, not in how we build images.

Verified by booting a freshly built qcow2 under the pinned runner: GRUB shows
`Bazzite (ostree:0)` and the Fedora 44 kernel reaches systemd startup.

## What we turned down

| Option | Why not |
|---|---|
| Keep tracking `latest` | The bug is still present in `latest` (7.43, 2026-08-02) and upstream has no commit addressing it. Tracking a moving runner is what broke this in the first place. |
| Drop the runner; use host `qemu-system-x86_64` | Works, and is kept in the docs as a fallback, but loses the browser VNC console and the recipe's TPM/GPU/KVM wiring, making the documented test path harder to follow — the surest way to get boot tests skipped. |
| Fork or patch the runner image | Owning a fork of a 400 MB third-party image to work around one probe is far more maintenance than a pinned tag, for a local dev tool. |
| Build uncompressed qcow2s so the probe passes | Contorts the artifact we actually ship to satisfy a broken consumer, and would slow builds and inflate disk use for every developer. |

## What would change our mind

- Upstream fixes the probe for compressed qcow2s — verify with
  `podman run --rm --entrypoint bash docker.io/qemux/qemu:TAG -c 'grep -c "GPT partition entry array" /run/install.sh'`
  (or simply boot a real disk) and bump the pin to the fixed release.
- The pinned 7.36 stops working against a newer host kernel, KVM, or podman —
  then we need a newer runner regardless, and host QEMU becomes the fallback.
- We stop using `bootc-image-builder` output for VM tests, which is what the
  probe chokes on.
