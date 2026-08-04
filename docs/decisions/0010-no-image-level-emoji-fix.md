# ADR-0010: No image-level color-emoji fix; per-user workaround only

- **Status:** Accepted
- **Date:** 2026-07-26
- **Scope:** fonts
- **Shipped in:** *nothing shipped* — the image-level fix (#14) was reverted (#15). This records the decision **not** to carry one.

## The question

Color emoji render as tofu boxes in Chromium-based apps (Edge, VS Code /
Electron) because Fedora 43+ ships Noto Color Emoji as a COLRv1 font that this
image's Chromium stack cannot use. Should the *image* fix this, or not?

## What we chose

**Do not ship an image-level fix.** Document the symptom and root cause in
`docs/fonts.md`, and give users a per-user workaround (drop the CBDT
`NotoColorEmoji.ttf` into `~/.local/share/fonts` + `fc-cache -f`), which
demonstrably works and survives rebases. This is a decision to *stop trying*
image-level fixes until the underlying mechanism is understood — recorded here
precisely because a reverted attempt leaves no other trace, so without this
record the same two approaches get proposed again.

## What we turned down

Two image-level attempts were built, and both failed:

| Option | Why not |
|---|---|
| Install CBDT font + reject COLRv1 via a fontconfig `<rejectfont>` drop-in (#14, attempt 1) | Had **no effect** on this base's fontconfig — `fc-match emoji` still resolved to COLRv1 in the build. (The same drop-in works on other distros, which is what made it look correct off-image.) |
| Install CBDT font + delete Fedora's COLRv1 file (attempt 2) | Worked *at build time* (build log confirmed `fc-match emoji` → CBDT) but emoji were **still broken on the booted machine**. Merged, then reverted in #15. |
| Ship nothing, not even docs | Leaves users staring at tofu with no explanation and invites a third re-attempt of the above. |

**The unexplained crux:** the identical font file works from
`~/.local/share/fonts` and not from `/usr/share/fonts/`. A green build proves
nothing here — that was demonstrated once already.

## What would change our mind

- The `/usr`-vs-`~/.local` font-exposure mechanism gets understood (leads in
  `docs/fonts.md`: build-time vs runtime font cache, the `ostree-rechunk` step,
  Chromium's sandbox font-dir access). **Only** a boot test with no user-level
  font installed counts as verification.
- Upstream fixes either side — Chromium learns to use Fedora's COLRv1 build, or
  Fedora reverts to CBDT. Then drop the workaround entirely (retest after major
  Edge/Electron updates and each Fedora base bump).
- Note the interaction with [issue #17](https://github.com/gharden91/ublue-gharden91/issues/17):
  if Edge is dropped over these font quirks, the Chromium surface shrinks but
  VS Code/Electron keep the problem.
