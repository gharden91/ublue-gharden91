# Verifying changes — what actually counts

The most expensive lesson this repo has learned is epistemic: **a green build
proves almost nothing about a desktop image.** The image-level color-emoji fix
passed its build, passed a build-time `fc-match emoji` assertion, merged — and
emoji were still broken on the booted machine (see [`fonts.md`](./fonts.md) and
[ADR-0010](./decisions/0010-no-image-level-emoji-fix.md)). The rule that came
out of it is [ADR-0011](./decisions/0011-rendering-claims-require-a-boot-test.md):
**rendering and desktop-integration claims are verified by a boot, never by a
build signal.**

Because verification here has real cost (a VM boot is minutes and gigabytes; a
real-hardware rebase is a reboot), match the *tier* to the *kind of change* —
don't over-verify a Justfile tweak, and don't under-verify a font change.

## The tiers

| Tier | How | Proves | Does **not** prove |
|---|---|---|---|
| **0 — Syntax** | `just check` | The Justfile parses. | Nothing about the image. |
| **1 — Container** | `just build` then `podman run --rm <img> …` (`rpm -q`, `rpm -ql`, `pwsh -c '$PSVersionTable'`) | A package/file is present; a headless CLI runs. | Anything desktop, graphical, or first-boot. |
| **2 — VM boot** | `just build-qcow2` + `just run-vm` (or direct `qemu-system-x86_64`) | Reaches a Plasma session; services (docker/containerd) start; GUI apps launch; **fresh-install** filesystem shape (`/opt` vs `/var/opt`). | Rendering that depends on the real font stack; **existing-machine** migration state. |
| **3 — Real hardware** | Rebase a machine onto the image and reboot | Chromium/Electron font rendering; existing-machine `/var/opt` migration; the KWin effect actually loading in a live session. | — (this is the top of the ladder) |

See [`local-testing.md`](./local-testing.md) for the exact commands behind each
tier, including the `qemux/qemu` runner regression workaround for Tier 2.

## Minimum tier per kind of change

- **Justfile / CI / docs only** → Tier 0 (+ Tier 1 if it touches the build path).
- **A new CLI package** (tmux, PowerShell) → Tier 1. `podman run … pwsh -c
  '$PSVersionTable'` is the real smoke test.
- **A KWin / desktop-effect change** (PlasmaZones) → **Tier 2 minimum** — the
  effect can't load headless, so Tier 1 can't see it. The build-log skew check
  (`build.sh`) is a Tier-1 *proxy* for the version match, not proof the effect
  loads; a live session (Tier 3) is the only place you *see* zones work.
- **A filesystem-shape change** (`/opt` immutability, anything under `/var`) →
  Tier 2 for the fresh install **and** an explicit Tier-3 check for existing
  machines. Edge's `/opt` move was cleared exactly this way — fresh install in a
  VM, then the `/var/opt/containerd` state inspected on real hardware
  ([ADR-0007](./decisions/0007-make-opt-a-real-immutable-directory.md)).
- **Anything about rendering or fonts in a Chromium/Electron app** → **Tier 3
  only.** A build log, `fc-match`, `fc-list`, and `podman run` are all *known
  liars* for this class — every one of them was green while emoji were broken.
  Boot a machine with no user-level font installed and look at Edge and VS Code.

## Reporting what you verified

State the tier you actually reached, not the one you wish you'd reached. "Builds
and `rpm -q` confirms the package (Tier 1); desktop integration not booted" is an
honest, useful hand-off. "Verified" with no tier is the sentence that shipped the
emoji bug — don't write it.
