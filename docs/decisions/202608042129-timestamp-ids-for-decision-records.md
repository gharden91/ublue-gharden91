# ADR-202608042129: Timestamp-based IDs for decision records

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** repo
- **Shipped in:** #34 — demonstrated by this record's own ID

## The question

A sequential ADR number is assigned at *write* time but only becomes globally
unique at *merge* time, and branches are parallel. Two open branches both read
the same last number off `docs/decisions/` and both claim it. This has already
happened twice: PR #28 needed a fixup commit to renumber ADR-0015, and PR #29
took 0016 by hand because 0015 was already spoken for. The number is the
record's citation handle — cited from `CLAUDE.md`, from other records'
`Superseded by` lines, and from commit bodies — so a collision resolved *after*
those citations exist means editing a record's substance, which
`docs/decisions/README.md` forbids. The only thing preventing that today is
remembering to check open PRs before picking a number.

## What we chose

New records take a **UTC creation-minute timestamp** as their ID —
`ADR-YYYYMMDDHHMM` (e.g. `date -u +%Y%m%d%H%M`) — starting with this one, which
is the first. Two handoffs won't land in the same minute without coordination,
so the ID is unique the moment it's written, with no serialization point.

The switch is **forward-only**. Records 0001–0016 keep their sequential IDs and
every existing citation stays valid, because supersession only ever rewrites an
old record's **Status** line (verified: 0004→0005, 0010→0013) — never its
substance — so the back catalogue needs no migration. A timestamp also sorts
chronologically and lexically *after* the zero-padded numbers, so it drops into
the `SessionStart` hook's listing and the README index in order, with no
ordering logic to change (only the hook's ID column widened).

The accepted cost is ergonomic: `ADR-202608042129` is longer and less memorable
in prose than `ADR-0007`. Judged worth it — the tax is paid only on new records,
and it *removes* the collision class rather than mitigating it.

## What we turned down

| Option | Why not |
|---|---|
| Advisory: `/handoff` checks open PRs before claiming a number | Keeps short, memorable numbers but stays advisory — two branches can still race before either opens a PR, and the failure mode is exactly the one the README forbids (editing a cited record). Mitigates, doesn't remove. |
| Allocate the number at *merge*, placeholder until then | Still needs the real number to bake citations (`CLAUDE.md`, superseding lines, commit body), so it forces a post-merge fixup every time — the precise pain #28 hit, made mandatory. A placeholder filename also breaks the sorted listing until merge. |
| Renumber everything into a new scheme | Rejected as unnecessary. Forward-only costs zero migration; renumbering would rewrite the substance of 16 records and rewrite ~90 citations — the churn the README exists to prevent. |
| Date only, no time | Reproduces the bug: #28 and #29 were both dated 2026-08-04. The collision is intra-day. |
| Slug-based IDs (`ADR-timestamp-ids`) | Collision-free, but loses the free chronological ordering the timestamp keeps and is even more awkward to cite than a number. |

## What would change our mind

If the repo ever has enough concurrent authors that two handoffs in the same UTC
*minute* becomes plausible, widen the stamp to seconds. If the long IDs prove
genuinely painful to cite in practice, layer a short human alias on top while
keeping the timestamp as the canonical, sortable identity. And if tooling ever
assigns numbers at a real serialization point — a merge-queue bot handing out
the next number atomically — sequential numbering becomes safe again and this
can be reversed.
