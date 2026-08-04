# Fonts (color emoji) — known issue, manual workaround

> **Status: not fixed in the image (2026-07-27).** An image-level fix was built,
> merged, and did **not** work on real hardware; it has been reverted. The
> per-user workaround below does work. See
> [Why there is no image-level fix](#why-there-is-no-image-level-fix).

## Symptom

Emoji render as tofu boxes (□) in Chromium-based applications — Electron apps
such as VS Code, and any Chromium browser you add (e.g. Edge from distrobox) —
while Qt/GTK applications and Firefox render them correctly.

Two things make the scope easy to misread when diagnosing this:

- **Discord looks fine.** It ships its own emoji as images and never touches
  the system font, so it proves nothing either way.
- **VS Code is the useful test.** It is Electron (Chromium) installed natively
  from the base image, so its breakage shows the problem is Chromium-wide, not
  specific to any one browser. (Native Edge used to be the other in-image test
  case; it was removed in #17 — see [edge.md](edge.md) — but VS Code alone is
  enough to reproduce and verify this.)

## Workaround

Install upstream's CBDT (bitmap) build of Noto Color Emoji into your user font
directory:

```bash
mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/NotoColorEmoji.ttf \
  https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/NotoColorEmoji.ttf
fc-cache -f
```

Then fully quit the affected app and reopen it — make sure no background
process of it is still running (e.g. `pgrep -f code` for VS Code, or
`pgrep msedge` if you've added Edge), since a lingering process keeps the old
font set. Verify with:

```
data:text/html;charset=utf-8,<div style="font-size:60px">🧠✨😀</div>
```

The `charset=utf-8` is load-bearing. A `data:` URL without it decodes as
Latin-1 and renders mojibake (`ðŸ§ âœ¨`), which looks like a font failure but
is a completely different problem.

This is per-user and lives in `$HOME`, so it survives image rebases and
updates. Remove the file once the underlying issue is fixed upstream —
see [When to drop this](#when-to-drop-this).

## Root cause

Fedora 43+ ships Noto Color Emoji as a
[COLRv1 font](https://fedoraproject.org/wiki/Changes/Use_COLR_for_Noto_Color_Emoji)
(`Noto-COLRv1.ttf`) instead of the older CBDT bitmap build. Chromium's font
stack on this image cannot use that font:

- emoji fall back to the page's body font (Noto Sans, Liberation Sans, …),
  which has no emoji glyphs, so the browser draws `.notdef` boxes;
- an explicit `font-family:'Noto Color Emoji'` **also** fails, which
  distinguishes this from an ordinary fallback-ordering problem. Chromium is
  not picking the wrong emoji font — it cannot use that font at all.

Everything on the fontconfig side is correct on a running machine, which is
what makes this misleading:

```bash
fc-match emoji                          # -> Noto-COLRv1.ttf, correct
fc-list :color=true family              # -> includes Noto Color Emoji
fc-match ":charset=1F9E0:color=true"    # -> Noto Color Emoji, correct
fc-list :lang=und-zsye family           # -> includes Noto Color Emoji
```

The font is installed, flagged as a color font, tagged with the emoji
language, and resolved correctly by every query — and Chromium still can't use
it. The other emoji fonts the base image ships (`Symbola`, `Twemoji`,
`Noto Emoji`) are **not** the cause; they were investigated and cleared.

## Why there is no image-level fix

Two image-level approaches were tried and both failed. Neither is worth
repeating.

**Attempt 1 — install the CBDT font, reject COLRv1 in fontconfig.** Added the
CBDT font to `/usr/share/fonts/` plus a
`<selectfont><rejectfont><glob>` drop-in in `/etc/fonts/conf.d/`. Both files
declare the identical family name `Noto Color Emoji`, so something has to break
the tie. The drop-in was copied into place correctly and had **no effect** on
this base image: the build log showed `fc-match emoji` still resolving to
COLRv1. (The same drop-in does work on other distributions' fontconfig, which
is what made it look correct when it was tested off-image.)

**Attempt 2 — install the CBDT font, delete Fedora's COLRv1 file.** Deletion is
behaviour rather than configuration, so it doesn't depend on fontconfig
semantics. This worked *at build time* — the build log confirmed the removal
and that `fc-match emoji` resolved to the CBDT build inside the image:

```
Noto Color Emoji (CBDT) from ref 'main': 10673480 bytes, validated.
Removing Fedora's COLRv1 emoji font: /usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf
Emoji font check: 'emoji' resolves to the CBDT build — Chromium-based apps OK.
```

It was merged, and **emoji were still broken on the booted machine.** Adding
the identical font file to `~/.local/share/fonts` on that same machine fixed
it immediately.

### The unexplained part

The same font file works from `~/.local/share/fonts` and does not work from
`/usr/share/fonts/`. That is the crux, and it is not yet understood. Whatever
the mechanism is, it means:

- correct font resolution at *build* time does not imply correct rendering at
  *runtime*, so the build-time `fc-match` assertion used in attempt 2 was not
  the safety net it appeared to be;
- the problem is about how the image exposes fonts under `/usr` to Chromium,
  not about the font file, the font format, or fontconfig's matching rules —
  all of which were verified correct.

Plausible leads for a future attempt, none of them tested:

- the font cache generated at build time versus what a Chromium font service
  reads at runtime (`/usr/lib/fontconfig/cache`), possibly interacting with
  the `ostree-rechunk` step;
- a stale per-user cache in `~/.cache/fontconfig` masking the image's fonts —
  worth trying `fc-cache -f` alone, before installing anything, on a machine
  freshly rebased onto an image that includes the font;
- Chromium's sandbox and which font directories it can open on a bootc image.
  **Note (2026-08-04):** when this lead was written, `/opt` was a real immutable
  directory (for native Edge). #17 removed Edge and reverted `/opt` to the base's
  `/opt -> /var/opt` symlink, so if the immutable `/opt` ever affected Chromium's
  font-directory access, VS Code emoji may behave differently on the #17 build.
  Untested — check with no user-level font installed. See ADR-0013's asterisk.

## When to drop this

The workaround exists only because Chromium-based apps can't use Fedora's
COLRv1 build. When either side fixes that, delete
`~/.local/share/fonts/NotoColorEmoji.ttf`, run `fc-cache -f`, and check the
test page again. Worth retesting after major Chromium/Electron updates and after
each Fedora base bump.

If you retry an image-level fix, note that the *only* trustworthy verification
is booting the image with no user-level font installed and looking at emoji in
VS Code (and any Chromium browser you've added). A green build proves nothing
here — that was already demonstrated once.
