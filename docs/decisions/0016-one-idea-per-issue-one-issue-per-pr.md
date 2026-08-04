# ADR-0016: One idea per issue, one issue per PR

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** repo
- **Shipped in:** #29

## The question

The knowledge system had a home for *what should happen* (Issues) and for *what
shipped* (`git log`), but none for **what's proposed and sitting in review**.
Adding pull requests as a first-class home forces a second question
immediately: what is the unit of work a PR implements? Issue #17 had already
answered it badly in both directions, so the granularity rule needed settling
at the same time as the PR conventions.

## What we chose

An issue is **one idea**; a PR is that one idea's implementation. Separable
ideas get separate issues. Something genuinely small may ride along with the
idea it touches; a second real idea may not. **When the split isn't obvious,
ask the author** — neither silently carving up nor silently bundling someone
else's request.

The reasoning is the cost already paid, not a preference for tidiness. #17
bundled four things: a premise (*Edge isn't worth keeping*), a docs update, an
`/opt` audit, and a removal. PR #21 implemented the batch and was **discarded
whole** when PR #26 established the premise was false — the emoji bug was a
stale per-user font cache (ADR-0013), not the image. Filed as its own issue,
that premise would have cost an investigation to kill instead of a completed
removal. PR #26 then failed the other way, carrying the font finding plus
unrelated VM-testing and `just clean` fixes in one diff.

So each failure mode has a distinct cost: a bundled **issue** takes its whole
batch down when one premise fails, and partial progress can't be merged or
closed cleanly. A bundled **PR** makes the reviewer accept or reject unrelated
changes together, with the riskiest part's verification tier (ADR-0011) gating
all of it.

The rule lives in `CLAUDE.md` (planning time) and the `/handoff` skill (filing
time) so it binds at both ends. Consistent with ADR-0012, it is guidance the
agent applies with judgment — the `SessionStart` hook surfaces open PRs but
gates nothing.

## What we turned down

| Option | Why not |
|---|---|
| One issue per *theme*, with a checklist of sub-items | Exactly what #17 was. A checklist looks like decomposition but shares one fate: kill the premise and the whole thread dies, including the items that were still valid. It also has no clean close state when three of five boxes ship. |
| Let PR scope follow the session, not the issue | This is how #26 came to carry `just clean` fixes. Sessions wander; review units shouldn't. It pushes the reviewer into approving things they never asked about, and buries a real finding inside unrelated diff noise. |
| Decompose aggressively without asking | Splitting is not free — it fragments a thread the author deliberately wrote as one, and cross-linked issues cost real attention to follow. Whether work gets divvied up is the author's call, so ambiguity resolves by asking, not by inferring. |
| A `gh` template or hook that rejects multi-idea issues | "One idea" isn't machine-checkable — nothing can tell a small rider from a second idea. Same trap ADR-0012 documents: enforcement without judgment produces compliance artifacts. |

## What would change our mind

If asking about the split becomes the friction rather than the fix — the author
answering "just bundle it" often enough that the question is noise — drop the
ask and default to bundling with an explicit note in the issue body. Likewise,
if the repo ever takes routine multi-part work where the parts genuinely can't
ship independently (a base-image bump touching several customizations at once
is the plausible case), a stated exception for that class beats stretching this
rule to cover it.
