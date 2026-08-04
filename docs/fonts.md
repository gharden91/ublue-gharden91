# Fonts (color emoji) — resolved: stale user font cache

> **Status: resolved (2026-08-04).** Emoji tofu in Chromium apps was never an
> image problem. It was a stale `~/.cache/fontconfig` in one long-lived home
> directory. The image needs no fix, and the old "install a CBDT font"
> workaround should be undone — see [The fix](#the-fix) and ADR-0013.

## Symptom

Emoji render as tofu boxes (□) in Chromium-based applications — Microsoft Edge
and Electron apps such as VS Code — while Qt/GTK applications and Firefox
render them correctly.

Two things make the scope easy to misread when diagnosing this:

- **Discord looks fine.** It ships its own emoji as images and never touches the
  system font, so it proves nothing either way.
- **VS Code is the useful test.** It is Electron (Chromium) and ships in the
  base image, so it reproduces the problem without installing anything.

## The fix

Rebuild the user font cache, then fully restart the affected app:

```bash
rm -rf ~/.cache/fontconfig
fc-cache -f
```

**Fully quit the Chromium app** — a lingering background process keeps the old
font set. Confirm with `pgrep -f /usr/share/code` (VS Code) or `pgrep msedge`
(Edge) before reopening.

Verify by pasting 🧠✨😀 into an editor, or in a browser:

```
data:text/html;charset=utf-8,<div style="font-size:60px">🧠✨😀</div>
```

The `charset=utf-8` is load-bearing. A `data:` URL without it decodes as
Latin-1 and renders mojibake (`ðŸ§ âœ¨`), which looks like a font failure but
is a completely different problem.

**If you previously applied the old workaround**, remove the now-redundant font
so the machine matches a clean install, then rebuild the cache again:

```bash
rm -f ~/.local/share/fonts/NotoColorEmoji.ttf
fc-cache -f
```

## Root cause

`fontconfig` caches font metadata per user in `~/.cache/fontconfig`. On a home
directory that has survived many image rebases, that cache can end up describing
a font set the system no longer has. Chromium enumerates fonts through that
cache, so it searched a stale picture of the world for emoji glyphs and drew
`.notdef` boxes. Qt/GTK apps and Firefox resolve fonts differently and were
unaffected — which is exactly what made this look like a Chromium-specific
COLRv1 incompatibility.

The affected machine held 174 cache entries, the oldest seven months old; a
rebuild produced 67.

Fedora 43+ shipping Noto Color Emoji as a
[COLRv1 font](https://fedoraproject.org/wiki/Changes/Use_COLR_for_Noto_Color_Emoji)
is real, but it is **not** the cause. Chromium renders COLRv1 emoji correctly on
this image with no user-level font installed — verified by VM boot.

## Why the diagnosis took three attempts

Worth reading before trusting a font diagnostic again.

**`fc-match` is not evidence about what an app sees.** Every check looked
correct on the broken machine:

```bash
fc-match emoji                          # -> Noto-COLRv1.ttf, correct
fc-list :color=true family              # -> includes Noto Color Emoji
fc-match ":charset=1F9E0:color=true"    # -> Noto Color Emoji, correct
```

These rebuild their view on demand, so they reported the *correct* font set
while Chromium read the *stale* one. Healthy `fc-match` output proves
fontconfig's query path works — nothing more.

**The old workaround worked for the wrong reason.** Dropping a CBDT
`NotoColorEmoji.ttf` into `~/.local/share/fonts` fixed emoji because the
instructions ended in `fc-cache -f`, which rebuilt the cache. The font's
location was irrelevant. That misattribution created the phantom "same font
works from `~/.local/share/fonts` but not `/usr/share/fonts`" mystery that
blocked progress for weeks — there was no such mechanism.

**It made a working image fix look broken.** An image-level attempt (ship CBDT,
delete Fedora's COLRv1) was correct at build time and in the image, but was
tested on the machine with the stale cache, appeared to fail, and was reverted.
ADR-0010 (superseded) records what was tried.

**False leads, now closed:** immutable `/opt` and native Edge were both
suspected of interfering with Chromium's font access, and issue #17 proposed
removing both. Neither is involved — emoji render identically with `/opt`
immutable + Edge installed and with `/opt` symlinked + Edge absent. ADR-0013 has
the comparison table.

## If it comes back

A recurrence on a machine whose cache was rebuilt *after* the image's fonts last
changed would be genuinely new information, not a repeat of this. Check a fresh
user account first: if a new user renders emoji correctly and an existing one
doesn't, it is user cache state again, not the image. Reproduce at the
real-hardware tier ([verifying-changes.md](./verifying-changes.md)) — a green
build proves nothing about rendering (ADR-0011).
