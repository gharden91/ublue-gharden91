# CLAUDE.md

This is a custom [bootc](https://github.com/bootc-dev/bootc) / Universal Blue OS
image. It layers a handful of customizations on top of
`ghcr.io/ublue-os/bazzite-dx:stable-44` and publishes
`ghcr.io/gharden91/ublue-gharden91`. Almost everything the image *does* beyond
the base is in **`build_files/build.sh`**; how it's wired is in `Containerfile`,
`Justfile`, and `.github/workflows/`.

## Where knowledge lives — read this first

| Kind | Home | Rule |
|---|---|---|
| **Durable** — how it works, why, what not to break | **This file** (invariants) + [`docs/`](docs/) (depth) | Edited in place. Never dated. |
| **Decisions** — why this and not that | [`docs/decisions/`](docs/decisions/) | Immutable. Superseded, never edited. |
| **Open intent** — what's next, what was deferred | **[GitHub Issues](https://github.com/gharden91/ublue-gharden91/issues)** | The only place open work lives |
| **History** — what shipped, blow by blow | `git log` | Frozen. Never the source of truth. |

Depth pages, each edited in place:

- [`docs/local-testing.md`](docs/local-testing.md) — build & test the image locally (podman/just/VM).
- [`docs/verifying-changes.md`](docs/verifying-changes.md) — what counts as verified: container < VM boot < real hardware.
- [`docs/plasmazones.md`](docs/plasmazones.md) — PlasmaZones install; the KWin version-match constraint.
- [`docs/powershell.md`](docs/powershell.md) — PowerShell 7 into `/usr`; how to bump the pin.
- [`docs/edge.md`](docs/edge.md) — Microsoft Edge native RPM; the `/opt` immutability story.
- [`docs/discord.md`](docs/discord.md) — Discord official RPM, deliberately unpinned.
- [`docs/vlc.md`](docs/vlc.md) — VLC from negativo17 fedora-multimedia, not RPM Fusion.
- [`docs/fonts.md`](docs/fonts.md) — color-emoji tofu: resolved; it was a stale per-user font cache.
- [`docs/README.md`](docs/README.md) — docs index + the **Maintenance Watchlist** of what can rot silently.

**Before proposing a substrate, a packaging approach, a repo/COPR, or a rewrite —
check [`docs/decisions/`](docs/decisions/).** If a record covers it, build on that
decision or make the case for superseding it; don't re-litigate silently. Every
record carries a *What would change our mind* section saying when reopening is
legitimate.

**Never put open work in a doc.** No "TODO", no "next steps", no "still open"
section in `CLAUDE.md`, `docs/`, or a code comment. That is how roadmaps rot.
[File an issue](https://github.com/gharden91/ublue-gharden91/issues) instead.

**The code outranks every document, including this one.** Prose drifts; the
source doesn't. When a doc and `build_files/build.sh` (or the `Containerfile`)
disagree, the code is right — fix the doc in the same commit. Verify against the
source before restating anything you read in a doc.

## Invariants — what not to break

These hold across the whole image; the per-feature reasoning is in `docs/` and
`docs/decisions/`.

- **The base image tag is Fedora-versioned on purpose.** `Containerfile` pins
  `bazzite-dx:stable-44`, not the floating `stable`, so the image's Fedora
  release can't jump underneath the version-suffixed RPMs we download
  (`.fc44`). Don't switch to `stable` — see ADR-0003 and the Watchlist before
  bumping to `stable-45`.
- **`x86_64` is assumed everywhere.** Download URLs in `build.sh` hardcode
  `linux-x64` / `x86_64`. Any ARM64 build must make each install conditional
  on target arch.
- **`/opt` is a real, immutable directory** (`RUN rm /opt && mkdir /opt`),
  which native Edge's RPM needs. This overrides the base's `/opt -> /var/opt`
  symlink; see ADR-0007 and `docs/edge.md` for the containerd caveat.
  **Edge is the only package that installs there** (verified: nothing else in
  the image owns a file under `/opt`), so dropping Edge means dropping this
  line too — and keeping Edge means keeping it.
- **Third-party repos are never left enabled** on the final image. Edge's repo
  is force-disabled after install; VLC and negativo17 use per-transaction
  `--enable-repo`. Keep it that way.
- **Pinned versions bump deliberately, not automatically** — `PWSH_VERSION`,
  `PLASMAZONES_VERSION`. Discord is the *one* deliberate exception (ADR-0009).
- **A green build never verifies a desktop-visible change.** Rendering, fonts,
  KWin effects, and GUI integration are verified by a *boot*, not by a build log
  or `podman run` — ADR-0011 and [`docs/verifying-changes.md`](docs/verifying-changes.md)
  (the tier ladder). This rule was written because the opposite was tried once
  and shipped a bug.

## Finishing a piece of work

Docs drift because nothing makes updating them part of shipping. So they are
part of shipping. **Run `/handoff`** and it walks this list.

1. **Did behavior, a data shape, or an invariant change?** Update `CLAUDE.md`
   and/or the relevant `docs/` page **in the same commit** — editing in place,
   not appending a note. A doc describing old behavior is worse than no doc.
2. **Did you choose between real alternatives — or decide *not* to do
   something?** Write a record in [`docs/decisions/`](docs/decisions/). The
   "decided not to" case matters most: it's the only work that leaves no trace
   anywhere else.
3. **Did you close something from the backlog?** Close the issue and reference
   it in the commit body.
4. **Did you discover work you're not doing now?** File an issue. Not a comment,
   not a doc, not the conversation — those are all places it dies.
5. **Did you learn something that cost you an hour?** A base-image quirk, a
   packaging gotcha, a wrong assumption (the fonts saga is the canonical
   example). Highest-value thing you can write down. Put it in the relevant
   `docs/` page.
6. **Verify at the right tier and report it honestly.** `just check` (syntax),
   `just build` + `podman run` (packages/CLI), VM boot (desktop/integration),
   real hardware (fonts/rendering) — pick the minimum tier for the change and
   state which you reached. See [`docs/verifying-changes.md`](docs/verifying-changes.md).

Distill, don't dump. A session's blow-by-blow belongs in the diff and the commit
message, nowhere else.
