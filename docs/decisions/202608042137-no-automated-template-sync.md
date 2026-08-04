# ADR-202608042137: Don't rebase or merge from the upstream template; port changes by hand

- **Status:** Accepted
- **Date:** 2026-08-04
- **Scope:** repo
- **Shipped in:** the PR closing #25

## The question

This image started from [`ublue-os/image-template`](https://github.com/ublue-os/image-template).
#25 asked whether we should periodically rebase or merge from that template to
pick up its improvements — and whether to automate it with an action. The
template keeps evolving (a "rewrite in just", a cosign v2→v3 migration, an
ostree-rechunk fix), so the pull is real: are we drifting away from fixes we'd
want?

## What we chose

**No automated sync, and no `git` merge/rebase from the template at all.** When
an upstream template change is genuinely worth having, port it **by hand** as
its own issue → PR, judged on its own merits.

Three findings, from actually fetching the template and diffing it against
`main`, drove this:

1. **The histories are unrelated.** Our root commit (`bd1536c`) and the
   template's (`3403039`) share no ancestor — `git merge-base main
   template/main` returns nothing. A rebase or merge is therefore only possible
   with `--allow-unrelated-histories`, which treats every shared file as a
   conflict against an empty base. There is no clean three-way merge to be had;
   the tool can't help us here even in principle.

2. **A blind merge is actively destructive, not just noisy.** Diffing the one
   file with the most upstream value — `.github/workflows/build.yml` — shows the
   template would *delete* our `PWSH_VERSION` / `PLASMAZONES_VERSION` repo-var
   plumbing and *downgrade* `docker/login-action` from our `v4.5.2` back to its
   `v4.5.1`. Taking template content wholesale moves us backward on the exact
   things we've deliberately customized. Every merge would need hand-review of
   every hunk anyway — which is just the manual-port workflow with a conflict
   marker tax bolted on.

3. **Renovate already covers most of the template's churn.** The bulk of the
   template's commit volume is `chore(deps)` action bumps. Renovate manages the
   GitHub Actions in *this* repo directly from their upstreams — that's why we
   were *ahead* of the template on `login-action`, not behind. Syncing from the
   template to get dependency bumps would be strictly worse than the feed we
   already have.

What's left after Renovate is a small number of **substantive** template
changes that need human judgment regardless — the cosign v3 migration
(`--new-bundle-format=false` so rpm-ostree can still verify, per
[containers/container-libs#388](https://github.com/containers/container-libs/issues/388)),
the ostree-rechunk source fix, first-run papercut fixes. Those are worth
porting, but each is a deliberate call about our CI, not a merge to rubber-stamp.
Catching them is **upstream-drift detection**, which already has a home: #19
(the Maintenance Watchlist automation). Watching the template's
`build.yml` / `Justfile` / `build_files/` for substantive (non-dependency)
changes belongs there, as one more drift source, producing an issue to port —
not an auto-merge.

## What we turned down

| Option | Why not |
|---|---|
| Scheduled action that `git merge`s / rebases `template/main` | Unrelated histories make it `--allow-unrelated-histories` conflict-on-everything; and even resolved, it deletes our customizations and downgrades pins (findings 1–2). Automating a merge that always needs full hand-review buys nothing. |
| Manual `git merge` from the template "from time to time" | Same conflict-on-everything problem, same destructive hunks. The git plumbing adds cost over just reading a diff and porting the one change we want. |
| Keep a template git remote and cherry-pick its commits | Cherry-pick across unrelated histories is a hand-applied patch with extra steps, and it still needs the per-hunk judgment. If we're hand-judging anyway, port from a read of the change, not from a SHA. |
| Rely on Renovate alone for everything | Renovate tracks *version feeds* (action digests, the base image), not *behavioral* template changes like the cosign-invocation rewrite. It's necessary but not sufficient — hence folding the substantive watch into #19. |
| Nothing — let the template drift away entirely | The substantive changes (cosign v3, rechunk fix) are real correctness/robustness improvements. Deciding to ignore them wholesale would be the wrong call; the answer is a watch + hand-port, not indifference. |

## What would change our mind

- If this repo were ever **re-forked to preserve the template's history** (a
  shared merge-base exists), finding 1 dissolves and a periodic merge becomes
  mechanically sane — revisit then. It isn't worth re-forking *for* this.
- If the template ever grew a **stable, machine-readable "shared CI" module**
  we consumed by reference (a reusable workflow, a pinned action) instead of by
  copy, drift would be a version bump Renovate handles — no sync policy needed.
- If porting-by-hand turns out to miss a class of important change repeatedly,
  that's evidence the #19 watcher's template coverage is too weak, not that an
  auto-merge is suddenly safe.
