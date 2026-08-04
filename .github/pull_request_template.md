<!--
Keep this short. The diff and commit body are the record; this is just the
knowledge-system checklist so nothing that outlives the diff gets dropped.
See CLAUDE.md → "Finishing a piece of work" and /handoff.
-->

## What & why

<!-- One or two sentences. The *why* matters more than the *what*. -->

## Knowledge captured

- [ ] **Decision record** — did this choose between real alternatives, or decide
  *not* to do something? If so, added/updated a record in
  [`docs/decisions/`](../blob/main/docs/decisions/) (and its index).
  <!-- Link it, or write "n/a — no real alternative". -->
- [ ] **Docs updated in place** — changed behavior, a path, or an invariant? The
  relevant [`docs/`](../blob/main/docs/) page and `CLAUDE.md` are updated in the
  *same* commit (not a dated note).
- [ ] **Watchlist** — could this rot silently when the base image moves? Its
  bullet is added/adjusted in the
  [Maintenance Watchlist](../blob/main/docs/README.md#maintenance-watchlist).
- [ ] **Open work is filed as issues**, not left as TODO comments.

## Verification

Which tier did you actually reach? (See
[`docs/verifying-changes.md`](../blob/main/docs/verifying-changes.md).)

- [ ] Tier 0 — `just check`
- [ ] Tier 1 — `just build` + `podman run` (package/CLI present)
- [ ] Tier 2 — VM boot (desktop / integration / fresh-install `/opt`)
- [ ] Tier 3 — real hardware (fonts, rendering, existing-machine state)

<!-- Rendering/font/KWin changes need Tier 2+ — a green build is not
verification for those. -->

## Issues

<!-- "Closes #NN", or leave blank. -->
