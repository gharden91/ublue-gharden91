# ADR-0011: Rendering and desktop-integration claims require a boot test, not a build signal

- **Status:** Accepted
- **Date:** 2026-07-26
- **Scope:** repo
- **Shipped in:** *nothing shipped* — this is the rule extracted from reverting the emoji fix (#14 → #15). Codified in [`docs/verifying-changes.md`](../verifying-changes.md).

## The question

The image-level color-emoji fix (#14) was built, passed a build-time
`fc-match emoji` assertion that resolved to the correct font, merged — and emoji
were **still broken on the booted machine**, forcing a revert (#15). So: what
counts as evidence that a *desktop-visible* change actually works?

## What we chose

For anything about rendering or desktop integration (fonts, Chromium/Electron
behavior, KWin effects, GUI-app system integration), **only a boot verifies it**
— a VM boot at minimum, real hardware for the font/rendering class. Build success,
`fc-match`, `fc-list`, and `podman run` are explicitly *not* verification for
these changes; they are all known to report green while the booted result is
broken. Verification is tiered by change kind; the full ladder and the
minimum-tier-per-change table live in
[`docs/verifying-changes.md`](../verifying-changes.md).

This is a rule about *evidence*, not about any one feature — it governs how every
future desktop-facing change is signed off.

## What we turned down

| Option | Why not |
|---|---|
| Trust the build-time `fc-match`/build-log assertion | It was the assertion that lied: green in the build, broken on the machine. The `/usr`-vs-`~/.local` font-exposure gap (unexplained, see `fonts.md`) means build-time font resolution ≠ runtime rendering. |
| Add more build-time checks (more `fc-*` queries, cache rebuilds) | More of the same category of signal that already failed. They'd raise confidence without raising *evidence*. |
| Require real-hardware boot for *every* change | Too expensive and unnecessary for CLI/package changes that `podman run` fully covers. The tiering exists precisely so the bar matches the risk. |

## What would change our mind

- The `/usr`-vs-`~/.local` font mechanism gets understood well enough that a
  *build-time* check provably predicts runtime rendering — then that check could
  re-earn trust for the font class specifically.
- CI gains an automated boot-and-screenshot stage (bootc-image-builder + a headed
  VM in the pipeline). If a boot test becomes cheap and automatic, "require a
  boot" stops being a manual-discipline rule and becomes a gate.
