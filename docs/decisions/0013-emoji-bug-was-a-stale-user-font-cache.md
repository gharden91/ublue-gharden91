# ADR-0013: The color-emoji bug was a stale per-user font cache, not the image

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** fonts
- **Supersedes:** ADR-0010
- **Shipped in:** *no image change* — the fix is a one-time user-side cache rebuild.

## The question

[ADR-0010](0010-no-image-level-emoji-fix.md) concluded that Chromium on this
image "cannot use" Fedora's COLRv1 Noto Color Emoji, and stopped image-level
fixes until the `/usr`-vs-`~/.local` mechanism was understood. It named the
verification that would settle it: **a boot test with no user-level font
installed.** [Issue #17](https://github.com/gharden91/ublue-gharden91/issues/17)
then proposed dropping Edge and reverting immutable `/opt`, on the theory that
Edge/`/opt` were implicated in the font problem.

That boot test finally happened, and it falsified the premise.

## What we chose

**Change nothing in the image.** The image was never broken. The bug was a stale
`~/.cache/fontconfig` in the affected user's home directory, masking the font set
the image actually provides. The remedy is a one-time, per-user cache rebuild,
documented in [fonts.md](../fonts.md):

```bash
rm -rf ~/.cache/fontconfig && fc-cache -f
```

followed by a **full restart of the Chromium app** (no lingering process).

Consequently we also **keep native Edge and immutable `/opt`** — the change
proposed in #17 was justified entirely by the font theory, and that theory is
dead. ADR-0007 stands.

### The evidence

Everything below used the same base build (`bazzite-deck-testing-44.20260802`)
and the same `code-1.131.0`, with only Fedora's COLRv1 font present and **no**
user-level font installed:

| Environment | `/opt` + Edge | Emoji |
|---|---|---|
| VM, fresh `$HOME` | immutable `/opt`, Edge present | **render** |
| VM, fresh `$HOME` | symlinked `/opt`, no Edge | **render** |
| Real hardware, 7-month-old `$HOME` | immutable `/opt`, Edge present | **tofu** |
| Real hardware, after `fc-cache` rebuild | unchanged | **render** |

The image variable makes no difference; the `$HOME` variable makes all of it.
The affected machine's cache held 174 entries, some dating to 2026-01-06;
rebuilding produced 67.

### Why it was misdiagnosed for so long

- **`fc-match` lied by omission.** Every diagnostic in ADR-0010 (`fc-match
  emoji`, `fc-list :color=true`) resolved correctly, because those rebuild their
  view on demand. Chromium enumerated the stale cache instead. Correct
  `fc-match` output was taken as proof the font layer was healthy; it only ever
  proved fontconfig's *query* path was healthy.
- **The workaround worked for the wrong reason.** Installing the CBDT font into
  `~/.local/share/fonts` fixed emoji because the documented step
  `fc-cache -f` **rebuilt the cache** — not because of where the font lived.
  That single misattribution produced the "`/usr` vs `~/.local`" crux that
  ADR-0010 called unexplained. There was no `/usr`-vs-`~/.local` mechanism.
- **It made a good image fix look broken.** Attempt 2 (ship CBDT, delete COLRv1)
  was correct at build time *and* correct in the image; it "failed" only because
  the tester's stale user cache masked it. It was reverted for the wrong reason.

## What we turned down

| Option | Why not |
|---|---|
| Ship the CBDT font / a fontconfig drop-in in the image (ADR-0010's attempts 1 & 2) | Fixes nothing that is broken. Fedora's COLRv1 font works; carrying a font override to paper over one machine's cache is pure maintenance debt. |
| Drop Edge and revert immutable `/opt` (issue #17) | Its whole rationale was "Edge shows the same tofu, so it buys the `/opt` risk for no gain." The tofu was not Edge's, not `/opt`'s, and not the image's. |
| Ship a systemd user unit that runs `fc-cache -f` on every login or image update | Treats a one-off stale cache as a recurring condition. fontconfig already invalidates on font-directory mtime changes; this was an artifact of a specific long-lived `$HOME`, not a design flaw. Reconsider only if it recurs on a machine with a fresh cache. |
| Keep the per-user font workaround as the documented remedy | It works, but by accident, and it leaves a redundant font in `$HOME` forever plus the false belief that the image's fonts are unusable. |

## What would change our mind

- Emoji break again on a machine whose `~/.cache/fontconfig` was rebuilt *after*
  the image's fonts last changed — that would mean a real image-side problem and
  reopens ADR-0010's territory.
- A Fedora base bump changes the emoji font again (COLRv1 → something else) and
  Chromium genuinely can't use it. Retest per
  [verifying-changes.md](../verifying-changes.md) at the real-hardware tier.
- The stale-cache failure turns out to hit multiple machines/users rather than
  one long-lived `$HOME` — then the rejected login-time `fc-cache` unit becomes
  worth its cost.
