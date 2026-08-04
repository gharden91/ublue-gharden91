# Decision records

One file per decision — a choice made at a moment. Unlike a doc (which describes
how the system works *now* and is edited in place) or a session note (which goes
stale the day it's written), a decision record only ever claims to describe a
choice, so it stays true forever. Filed by topic, not date; findable by the
question you're asking.

**Read these before proposing a packaging approach, a repo/COPR, a substrate, or
a rewrite.** If a record covers it, build on it or supersede it — don't
re-litigate silently. The `Accepted` status and the *What would change our mind*
section tell you whether a record still binds.

## Index

| # | Title | Status | Scope |
|---|---|---|---|
| [0001](0001-bake-into-image-not-runtime-layering.md) | Bake customizations into the image, not per-machine layering | Accepted | repo |
| [0002](0002-powershell-into-usr-via-tarball.md) | Install PowerShell into `/usr` via tarball, not `/opt` via RPM | Accepted | powershell |
| [0003](0003-pin-base-to-fedora-versioned-tag.md) | Pin the base image to a Fedora-versioned tag, not floating `stable` | Accepted | repo |
| [0004](0004-plasmazones-from-copr.md) | Install PlasmaZones from the maintainer's COPR | Superseded by ADR-0005 | plasmazones |
| [0005](0005-plasmazones-from-pinned-release-rpm.md) | Install PlasmaZones from a pinned GitHub release RPM | Accepted | plasmazones |
| [0006](0006-native-rpms-not-flatpaks.md) | Ship desktop apps as native RPMs baked in, not Flatpaks | Accepted | repo |
| [0007](0007-make-opt-a-real-immutable-directory.md) | Make `/opt` a real immutable directory to allow native Edge | Superseded by ADR-0013 | edge |
| [0008](0008-vlc-from-negativo17-not-rpmfusion.md) | Install VLC from negativo17, not RPM Fusion | Accepted | vlc |
| [0009](0009-discord-unpinned-official-rpm.md) | Install Discord unpinned from the official latest RPM | Accepted | discord |
| [0010](0010-no-image-level-emoji-fix.md) | No image-level color-emoji fix; per-user workaround only | Accepted | fonts |
| [0011](0011-rendering-claims-require-a-boot-test.md) | Rendering/desktop-integration claims require a boot test, not a build signal | Accepted | repo |
| [0012](0012-knowledge-capture-is-a-skill-not-a-hook.md) | Knowledge capture is a skill (`/handoff`), not an enforcing hook | Accepted | repo |
| [0013](0013-drop-edge-and-revert-immutable-opt.md) | Drop native Edge and revert `/opt` to the base symlink | Accepted | edge |

> **Most of these were backfilled** in one pass (0001–0011) from `git log`, the
> `docs/` pages, and the code when the knowledge system was set up — the
> reasoning is reconstructed from what shipped, not a transcript of the moment.
> ADR-0012 was made live during that setup. Either way, the **Date** is when the
> decision was actually made, not when the record was written.

## The bar — keep it high or this folder becomes the old notes folder

**Earns a record:**
- A choice between real alternatives where the losing option was *plausible*.
- A decision **not** to do something. Highest value — no other trace exists.
- A constraint discovered the hard way that now governs future choices.
- A reversal of an earlier record.

**Does not:**
- How something works → that's `docs/`.
- Something we might do later → that's a [GitHub issue](https://github.com/gharden91/ublue-gharden91/issues).
- A choice with no real alternative ("we used the existing helper").
- Naming, formatting, anything you'd change without a second thought.

A dozen real records is valuable; sixty trivial ones is the old notes folder
wearing a new hat.

## Status and supersession

`Accepted` · `Superseded by ADR-NNNN` · `Reversed`

**Never delete or rewrite a record's substance.** If a decision changes, write a
new record and update the old one's status line to point at it (see 0004 → 0005
for the worked example). A superseded record is the only thing that stops the
same idea returning as if it were new. Keep the index above in sync when you add
one — `/handoff` reminds you.
