# ADR-0012: Knowledge capture is a skill (`/handoff`), not an enforcing hook

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** repo
- **Shipped in:** the knowledge-system setup (`.claude/skills/handoff/`, `.claude/hooks/session-start.sh`)

## The question

The durable-knowledge system needs a *mechanism* — structure alone rots. Two
shapes were available for the capture step: a `/handoff` **skill** the agent
invokes when wrapping up, or an **enforcing hook** (e.g. a `Stop` hook that
blocks or nags when `build_files/build.sh` or `Containerfile` changed but no
`docs/` or `docs/decisions/` file did). Which mechanism captures session
knowledge?

## What we chose

A skill. `/handoff` walks the routing (decisions → `docs/decisions/`, discovered
work → issues, changed behavior → in-place doc edits) but leaves the *judgment*
— is this a real decision? was the rejected alternative plausible? — to the
agent. The `SessionStart` hook does the opposite job (surfacing, not enforcing):
it prints the docs/decision index so the non-auto-loaded layers are seen.

Recording this so the enforcing-hook idea, which is the natural thing to reach
for next, isn't re-proposed and re-argued from scratch.

## What we turned down

| Option | Why not |
|---|---|
| A `Stop` hook that hard-blocks a session ending with code changed but docs untouched | It can see *that* files changed, never *whether a decision was made* or whether the alternative was plausible. So it can only fire on a crude proxy — and it fires on the many sessions that produced nothing worth recording too, training the agent to dismiss it. Then it gets dismissed on the one session that mattered. |
| The same hook, but only nagging (non-blocking) | Same failure: a nag on every code change is noise, and enforcement-without-judgment produces *compliance artifacts* — decision records written to satisfy a check, which are worse than none. |

## What would change our mind

The brief's own narrower version becomes worth building **if `/handoff` turns out
to be skipped in practice**: a `Stop` hook that fires **only** when
`build_files/build.sh` or `Containerfile` changed and *neither* `docs/` nor
`docs/decisions/` was touched — a targeted reminder on exactly the change class
that has always carried a doc update in this repo, not a blanket gate. Adopt it
only on evidence of skipping, not preemptively.
