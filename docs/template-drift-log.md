# Upstream template drift log

A single running ledger of every [`ublue-os/image-template`](https://github.com/ublue-os/image-template)
commit this repo has reviewed for drift (per
[ADR-202608042137](decisions/202608042137-no-automated-template-sync.md): no
auto-merge, substantive changes get read and ported by hand). **Edited in
place, append-only** — a new row per commit reviewed, oldest first, never
reordered or deleted.

This is not a replacement for the [decision records](decisions/) — a range
that includes a real behavioral change still gets its own dated ADR laying
out the full reasoning (see
[ADR-202608230207](decisions/202608230207-review-template-range-aug2026.md)
for the worked example). This table is the flat index across *all* of those
ADRs plus every commit that was skipped without needing one: check here first
for "have we already looked at this commit," then follow the **ADR/Issue**
column for the *why* on anything more than a one-line dependency-bump skip.

## How this gets updated

`.github/scripts/check-drift.sh`'s template-drift check lists every commit in
the baseline→head range in its report (see its "Doing the review" section).
When reviewing a reported range:

1. Add one row per commit below (or one row per *group* of commits that are a
   single continuous rewrite — see the log's own entries for the pattern).
2. Substantive changes get their own issue (port) or a one-line reason
   (skip), same as always — the row here just indexes that decision, it
   doesn't replace filing it.
3. A range worth explaining in depth still gets an ADR; link it in this
   table's **ADR/Issue** column rather than duplicating its reasoning here.
4. Advance `.github/template-drift-baseline` once every commit in the range
   has a row.

## Log

| Commit | Date | File(s) | What it did | Decision | ADR/Issue |
|---|---|---|---|---|---|
| [`57faa3ae`](https://github.com/ublue-os/image-template/commit/57faa3aea4a46e0a12a82e956c117b5373c2bc9f) | 2026-08-01 | `Justfile`, `README.md` | Replace `#!/usr/bin/bash` shebangs with `#!/usr/bin/env bash`; drop hardcoded `/usr/bin/{sudo,find,numfmt}` for `$PATH` lookups; add a "Required Utilities" README section. | **Ported** directly (zero-behavior-change) | PR #46, [ADR-202608230207](decisions/202608230207-review-template-range-aug2026.md) |
| [`b6ae7043`](https://github.com/ublue-os/image-template/commit/b6ae70437f2471cf139a3508e5d2e0b96a1ee8aa) | 2026-08-01 | `build.yml` | cosign v2.6.3 → v3.1.2 with `--new-bundle-format=false --use-signing-config=false` so rpm-ostree can still verify the signature. | **Ported** | #36, merged via PR #41, [ADR-202608230207](decisions/202608230207-review-template-range-aug2026.md) |
| [`715d4b2d`](https://github.com/ublue-os/image-template/commit/715d4b2d29ed6a717396b23e145f7a64db11a4c0) → [`94e9423c`](https://github.com/ublue-os/image-template/commit/94e9423c7b3167370f7a0b680959edff6bd081c1) | 2026-08-01 – 2026-08-09 | `Justfile` | `rechunk` (chunkah) recipe: env-var config → mounted config file + `oci:` dir output (avoids an env-var size overflow), then a follow-up un-setting `SOURCE_DATE_EPOCH`. | **Ported** (final shape; dormant recipe) | #47, merged via PR #48, [ADR-202608230207](decisions/202608230207-review-template-range-aug2026.md) |
| [`ac6ef404`](https://github.com/ublue-os/image-template/commit/ac6ef404abe50fd2e401614268b2cef8c6e054f6) | 2026-08-01 | `build.yml` | `docker/login-action` v4.5.0 → v4.5.1 (digest bump). | **Skipped** — Renovate-managed here, already ahead at v4.6.0 | [ADR-202608042137](decisions/202608042137-no-automated-template-sync.md) |
| [`a18ae9b5`](https://github.com/ublue-os/image-template/commit/a18ae9b5ce6429bbb25a99e25dc59afbf836dde9) → [`3430fb69`](https://github.com/ublue-os/image-template/commit/3430fb692292cc1aec6c134913816bfc42094c81) → [`b9783f6a`](https://github.com/ublue-os/image-template/commit/b9783f6a1e2d320fec09cf76430f723ed44984b2) | 2026-08-03 – 2026-08-18 | `Justfile`, `build.yml` | `ostree-rechunk`: use the local image instead of pulling `fedora-bootc`, drop the root requirement entirely, then swap an oci-archive round-trip for direct containers-storage writes (perf). `build.yml` drops `sudo` wrapping on steps that no longer need it. | **Ported** (final shape; found and fixed a real label-loss bug in verification — see ADR-202608230454) | #45, merged via PR #48, [ADR-202608230207](decisions/202608230207-review-template-range-aug2026.md) |
| [`dcafc268`](https://github.com/ublue-os/image-template/commit/dcafc2683b720b55ae51b3e33f24160aeeda4e80) | 2026-08-09 | `README.md` | Typo fix, `[jq])(url)` → `[jq](url)`. | **Skipped** — our README no longer carries that section | [ADR-202608230207](decisions/202608230207-review-template-range-aug2026.md) |

> **Before `57faa3ae`:** [ADR-202608042137](decisions/202608042137-no-automated-template-sync.md)
> (2026-08-04) and [issue #19](https://github.com/gharden91/ublue-gharden91/issues/19)
> record an earlier, pre-tooling manual diff against the template that
> surfaced the same cosign v2→v3 migration and the `ostree-rechunk` fix by
> reading `build.yml`/`Justfile` directly rather than walking a commit range
> — no baseline commit was recorded at that point to anchor specific hashes
> to, so this log starts at the first commit the `.github/template-drift-baseline`
> mechanism actually tracked.
