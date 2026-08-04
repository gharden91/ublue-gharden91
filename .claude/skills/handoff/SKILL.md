---
name: handoff
description: Memorialize a work session into the repo's knowledge system before context is lost — decision records for choices made, issues for discovered work, docs updates for changed behavior. Use at the end of a session that produced anything worth keeping, when the user says "wrap up", "hand off", "write this up", "capture this", or when a long discussion has settled on decisions that produced no code. Also use proactively before ending a session where a real choice was made or a non-obvious thing was learned.
---

# Handoff

Distill this session into the knowledge system. **Distill, not dump.**

The test for every candidate: **will a future session be worse off without
this?** If not, let it go. Most of a session is not worth keeping, and saying
so is part of the job.

## 1. Work out what actually happened

    git status --short
    git diff --stat HEAD
    git log --oneline origin/main..HEAD

Then re-read the conversation for things that left **no trace in the diff** —
that's where the value is, and the part that dies at session end:

- Options weighed and rejected, and why (the negativo17-vs-RPM-Fusion or
  COPR-vs-release-RPM kind of call).
- A decision to *not* build something (the reverted emoji fix is the canonical
  one).
- A constraint discovered the hard way (a base-image quirk, an `/opt`/immutable
  gotcha, a build-log signal that only shows up on real hardware).
- A user preference stated once that should govern future work.
- An assumption that turned out wrong.

## 2. Route each item to its home

| What you have | Where it goes |
|---|---|
| A choice between real alternatives | A new record in `docs/decisions/` |
| A decision *not* to do something | A record — highest value, no other trace |
| Changed behavior, data shape, or invariant | Edit `CLAUDE.md` / the `docs/` page **in place** |
| Something learned that cost an hour | The relevant `docs/` page (+ the Watchlist in `docs/README.md` if it can rot silently) |
| Work discovered but not done | A [GitHub issue](https://github.com/gharden91/ublue-gharden91/issues) |
| What happened, blow by blow | **Nowhere.** That's the diff and the commit message. |

## 3. Write decision records

Copy `docs/decisions/TEMPLATE.md`, number it next in sequence, one screen max.
Get **What we turned down** and **What would change our mind** right — they
carry the weight. Add a row to the index table in `docs/decisions/README.md`.

If this session reversed or replaced an earlier decision: write a **new** record
and set the old one's status line to `Superseded by ADR-NNNN` (see 0004 → 0005
for the worked example). **Never edit or delete an existing record's
substance.**

## 4. Update docs in place

Edit the page. Don't append a note, don't add an "as of" clause, don't date
anything. Delete what stopped being true. Check `CLAUDE.md`'s invariants too —
they drift just as easily. If the change is something that can break silently as
the base image moves, add/adjust its bullet in the Maintenance Watchlist.

## 5. File issues, don't leave TODOs

Anything discovered and not done becomes an issue. Never a code comment, a doc,
or the conversation. If the session closed something already filed, close it and
reference it in the commit body.

## 6. Commit

One commit, with a body explaining **why**, not just what. Reference issues
closed. Run `just check` (and `just build` if the build changed), then push.

## What to push back on

If the user asks to record something below the bar (see
`docs/decisions/README.md`), say so rather than filing it. A decisions folder
with a dozen real records is useful; sixty trivial ones is the old notes folder
wearing a new hat.

Equally: if a session produced nothing worth memorializing, say that and skip
the ceremony. Not every session needs an artifact.
