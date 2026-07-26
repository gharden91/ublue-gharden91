# Fonts (color emoji)

> **Status: mechanism confirmed on real hardware (2026-07-25); image-level fix
> awaiting a green build.** Installing this font at the user level restored
> emoji in both Microsoft Edge and VS Code. The first image-level attempt used
> a fontconfig reject rule instead of removing Fedora's font, and **CI proved
> it did not work** — see [Verification](#verification).

## Intent

Make emoji render in Chromium-based applications. On the stock base image they
do not: Microsoft Edge and Electron apps (VS Code) display every emoji as a
tofu box, while Qt/GTK applications and Firefox render them correctly.

## The problem

Fedora 43+ ships Noto Color Emoji as a
[COLRv1 font](https://fedoraproject.org/wiki/Changes/Use_COLR_for_Noto_Color_Emoji)
(`Noto-COLRv1.ttf`) instead of the older CBDT bitmap build. Chromium's font
stack on this image cannot resolve that font at all:

- emoji fall back to the page's body font (Noto Sans, Liberation Sans, …),
  which has no emoji glyphs, so the browser draws `.notdef` boxes;
- an explicit `font-family:'Noto Color Emoji'` **also** fails, which is what
  distinguishes this from an ordinary fallback-ordering problem. Chromium is
  not choosing the wrong emoji font, it cannot see that font at all.

Everything on the fontconfig side is correct and checks out on a running
machine, which is what makes this misleading to diagnose:

```bash
fc-match emoji                          # -> Noto-COLRv1.ttf, correct
fc-list :color=true family              # -> includes Noto Color Emoji
fc-match ":charset=1F9E0:color=true"    # -> Noto Color Emoji, correct
fc-list :lang=und-zsye family           # -> includes Noto Color Emoji
```

So the font is installed, flagged as a color font, tagged with the emoji
language, and resolved correctly by every query — and Chromium still can't use
it. The competing emoji fonts on the image (`Symbola`, `Twemoji`,
`Noto Emoji`, all pulled in by the base) are **not** the cause; they were
investigated and cleared.

### Why it looks like an Edge bug at first

Only Chromium-based apps are affected, and Edge is the most visible one. Two
things make the scope easy to misread:

- **Discord renders emoji fine** — but it ships its own emoji as images and
  never touches the system font, so it proves nothing either way.
- **VS Code is the useful test.** It is Electron (Chromium) installed natively
  from the same image, so if it breaks too the problem is Chromium-wide rather
  than Edge-specific. It does break.

## What this image does

1. `build_files/build.sh` installs upstream's CBDT (bitmap) build of Noto Color
   Emoji — a format Chromium has supported for years — to
   `/usr/share/fonts/noto-color-emoji-cbdt/NotoColorEmoji.ttf`.
2. It then **deletes** Fedora's `Noto-COLRv1.ttf` and rebuilds the font cache.
3. It asserts `fc-match emoji` resolves to the CBDT build, and **fails the
   build** if not.

**Step 2 is not optional.** Both files declare the identical family name
`Noto Color Emoji`, so with both present the winner is decided by fontconfig's
scan order — and it picks COLRv1, the broken one. Installing the font without
removing the other leaves emoji exactly as broken as before. (At the user level
this does not come up: `~/.local/share/fonts` outranks `/usr/share/fonts`,
which is why the confirmation test below works with no other change.)

### Why deletion and not a fontconfig rule

The first version of this fix kept Fedora's font and added a
`<selectfont><rejectfont><glob>` drop-in to `/etc/fonts/conf.d/` instead. That
is the tidier approach and it demonstrably works on some distributions'
fontconfig — but **it does not work on this base image**. The drop-in was
copied into place correctly and had no effect: `fc-match emoji` still resolved
to COLRv1. Deleting the file is behaviour rather than configuration, so it
doesn't depend on fontconfig semantics that vary between fontconfig builds.

## Decisions

- **Delete the font file, not the RPM.** `google-noto-color-emoji-fonts` is
  pulled in by `default-fonts-core-emoji`, so `dnf5 remove` would cascade into
  the desktop metapackages. Removing the single file achieves the same result
  with no dependency surprises, and reverting is deleting a few lines.
- **Upstream download, not a Fedora package.** Fedora has no CBDT subpackage
  to install, so the font comes from
  [googlefonts/noto-emoji](https://github.com/googlefonts/noto-emoji).
- **Deliberately unpinned, unlike PowerShell/PlasmaZones.** It tracks upstream's
  `main` (same stance as Discord — see [discord.md](./discord.md)). Emoji font
  releases add newly-standardized emoji and little else, so tracking latest
  means new emoji show up on rebuild instead of rotting behind a version and
  checksum nobody wants to hand-bump. `NOTO_EMOJI_REF` can pin a tag if
  upstream ever ships a bad build.
- **Validated at build time instead of by checksum.** Tracking a branch means
  there's no checksum to verify against, so the build runs `fc-scan` on the
  downloaded file and **fails** unless fontconfig reads it as the
  `Noto Color Emoji` color font. That catches a truncated download or an HTML
  error page saved as a `.ttf` — which would otherwise install silently and
  leave emoji broken in exactly the way this fix exists to prevent.
- **Everything moves to the bitmap build, not just Chromium.** fontconfig has
  no way to answer per-application, so Firefox and Qt/GTK get the CBDT font
  too. Bitmap emoji are slightly less crisp at very large sizes. That's the
  cost of one consistent, working emoji font system-wide.
- **The build fails, not warns, if the wrong font wins.** This is not
  hypothetical: the first attempt shipped a perfectly green CI build that still
  had broken emoji, and only the build-log check revealed it. A warning nobody
  reads is worth very little for a failure whose only other symptom is "emoji
  are broken again three weeks from now", so it exits non-zero.

## Verification

Confirmed on hardware (2026-07-25) by installing the same font file at the user
level and restarting the apps — emoji returned in both Edge and VS Code:

```bash
mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/NotoColorEmoji.ttf \
  https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/NotoColorEmoji.ttf
fc-cache -f
```

**The first image-level attempt failed, and CI caught it.** Using a fontconfig
reject rule instead of deleting the file produced a successful build whose log
contained:

```
WARNING: 'emoji' resolves to '/usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf',
         not /usr/share/fonts/noto-color-emoji-cbdt/NotoColorEmoji.ttf.
```

That is the entire reason the check now fails the build: green CI otherwise
means nothing here. The deletion approach was verified to resolve correctly
(including that the rebuilt cache stops advertising the removed file), but on
a different fontconfig than the image's — so the authoritative check is the
build log.

Still outstanding before rebasing hardware:

- Confirm the build log shows the font validating **and**
  `Emoji font check: 'emoji' resolves to the CBDT build`. With the check now
  fatal, a green build is sufficient evidence.
- Boot it (see [local-testing.md](./local-testing.md)) and confirm emoji render
  in Edge and VS Code from the image itself, with no user-level font installed.
- Make sure `~/.local/share/fonts/NotoColorEmoji.ttf` is gone from the test
  machine, or it will mask a failure of the image-level fix.

A quick in-app test page, once booted:

```
data:text/html;charset=utf-8,<div style="font-size:60px">🧠✨😀</div>
```

Note that the `charset=utf-8` is load-bearing — a `data:` URL without it
decodes as Latin-1 and renders mojibake (`ðŸ§ âœ¨`), which looks like a font
failure but isn't one.

## Maintenance

- **Recheck whether this workaround is still needed.** This exists because
  Chromium can't use Fedora's COLRv1 build. When either side fixes that, the
  right move is to delete the font install and the COLRv1 removal and go
  back to stock. Retest after major Edge/Electron updates and after each Fedora
  base bump.
- **Rebuild cadence carries font updates.** The font tracks upstream `main`, so
  emoji coverage advances whenever the image rebuilds — no version to bump. The
  flip side is that a bad upstream commit would land on the next rebuild; the
  build-time `fc-scan` validation is the guard, and setting the `NOTO_EMOJI_REF`
  repo variable to a tag (e.g. `v2.051`, the build this fix was confirmed
  against) pins it if that ever happens.
- **The removal keeps finding its target.** `build.sh` searches
  `/usr/share/fonts` for `Noto-COLRv1*.ttf`, so a Fedora directory change is
  handled, but a *rename* would slip past. The build then fails on the
  `fc-match` assertion rather than shipping broken emoji — if that happens, the
  fix is to update the filename pattern, not to disable the check.
