# ADR-202608230207: Reviewed the Aug 2026 template range commit-by-commit; ported cosign and the rechunk rewrites as separate issues, skipped the rest

- **Status:** Accepted
- **Date:** 2026-08-23
- **Scope:** repo
- **Shipped in:** #43, #45, #47, PR #46 (baseline advance + trivial cleanups); #36/PR #41 (cosign, already in flight before this review)

## The question

#43 (the drift-check watcher) flagged that `ublue-os/image-template` moved
`3d68ac893a31`→`b9783f6a1e2d` and touched `build.yml`/`Justfile`, both files
this repo forked and now maintains by hand per
[ADR-202608042137](202608042137-no-automated-template-sync.md). That ADR
established the *policy* — port substantive changes by hand, each judged on
its own merits, never merge/rebase wholesale. This record is that policy
actually applied: a commit-by-commit review of the eight commits making up
the range, requested explicitly so the reasoning behind each accept/skip call
is on record rather than living only in a PR thread.

The eight commits, oldest first:

| Commit | Date | What it did |
|---|---|---|
| [`b6ae7043`](https://github.com/ublue-os/image-template/commit/b6ae70437f2471cf139a3508e5d2e0b96a1ee8aa) | 2026-08-01 | `build.yml`: cosign v2.6.3 → v3.1.2, add `--new-bundle-format=false --use-signing-config=false` so rpm-ostree can still verify the signature. |
| [`715d4b2d`](https://github.com/ublue-os/image-template/commit/715d4b2d29ed6a717396b23e145f7a64db11a4c0) | 2026-08-01 | `Justfile`'s `rechunk` (chunkah) recipe: switch from an env-var config (`CHUNKAH_CONFIG_STR`, which overflows on base images with large package labels) to a mounted config file; switch output from a `podman load` pipe to an `oci:` directory + explicit `pull`/`tag`; set `SOURCE_DATE_EPOCH=0` for reproducibility. |
| [`ac6ef404`](https://github.com/ublue-os/image-template/commit/ac6ef404abe50fd2e401614268b2cef8c6e054f6) | 2026-08-01 | `build.yml`: `docker/login-action` v4.5.0 → v4.5.1 (Renovate-style digest bump). |
| [`a18ae9b5`](https://github.com/ublue-os/image-template/commit/a18ae9b5ce6429bbb25a99e25dc59afbf836dde9) | 2026-08-03 | `Justfile`'s `ostree-rechunk` recipe: use the already-built local image (`localhost/${target_image}:${tag}`, `--pull=never`) instead of pulling `quay.io/fedora/fedora-bootc:latest` fresh each run. Root still required at this point. |
| [`94e9423c`](https://github.com/ublue-os/image-template/commit/94e9423c7b3167370f7a0b680959edff6bd081c1) | 2026-08-09 | `Justfile`'s `rechunk` recipe: un-set `SOURCE_DATE_EPOCH` — a follow-up fix reverting part of `715d4b2d`. |
| [`dcafc268`](https://github.com/ublue-os/image-template/commit/dcafc2683b720b55ae51b3e33f24160aeeda4e80) | 2026-08-09 | `README.md`: typo fix, `[jq])(url)` → `[jq](url)`. |
| [`3430fb69`](https://github.com/ublue-os/image-template/commit/3430fb692292cc1aec6c134913816bfc42094c81) | 2026-08-14 | `Justfile`'s `ostree-rechunk`: drop the `if [[ ! "${UID}" -eq 0 ]]; exit 1; fi` root guard entirely, output via `oci-archive:` + explicit pull/tag instead of `containers-storage:` directly. `build.yml`: drop the `sudo -E $(command -v just) …` wrapping on the `build`, `ostree-rechunk`, `tag-images` steps and `sudo -E podman push`, now that none of them need root. |
| [`b9783f6a`](https://github.com/ublue-os/image-template/commit/b9783f6a1e2d320fec09cf76430f723ed44984b2) | 2026-08-18 | `Justfile`'s `ostree-rechunk`: replace the `3430fb69` oci-archive round-trip with direct writes to the host's container graphroot via `--mount=type=bind` + a tmpfs overlay (`containers-storage:[overlay@…+…]`) — faster, same rootless property. |

`a18ae9b5` → `3430fb69` → `b9783f6a` are one continuous rewrite of
`ostree-rechunk` (make it rootless, then make it fast); `715d4b2d` → `94e9423c`
are one continuous rewrite of `rechunk`/chunkah (fix the env-var overflow,
then walk back the reproducibility flag that broke something else). Reviewing
each final shape, not each intermediate commit in isolation, is what actually
matters for a port decision.

## What we chose

| Commit(s) | Decision | Reasoning | Reference |
|---|---|---|---|
| `b6ae7043` | **Port** | The one already-flagged substantive change (ADR-202608042137 called it out by name). Directly needed: rpm-ostree/bootc can't verify cosign 3.x's new default bundle format, so the flags are load-bearing, not cosmetic. | Issue #36, open as PR #41 |
| `715d4b2d` + `94e9423c` | **Port** (as one unit — the final shape, not the intermediate `SOURCE_DATE_EPOCH` detour) | Real robustness fix (avoids the exact env-var-overflow class of bug that hit `bluefin`), but the recipe it touches (`rechunk`, the chunkah path) is dormant here — `build.yml` only ever calls `ostree-rechunk`; the chunkah invocation is commented out. Ported for the record so the drift baseline can move past it, not because anything currently depends on it. | Issue #47 |
| `ac6ef404` | **Skip** | Pure action-digest bump. Renovate manages `docker/login-action` here directly from upstream, and we're already ahead of the template on it (`v4.6.0` vs. the template's `v4.5.1` at this point in its history) — exactly the case ADR-202608042137 already reasoned through. | ADR-202608042137, finding 3 |
| `a18ae9b5` + `3430fb69` + `b9783f6a` | **Port** (final shape — mount-based, containers-storage output, no root requirement) | `ostree-rechunk` is the recipe our CI actually calls every build. The root requirement it drops is the exact `# TODO: This is the only blocker for rootless CI` comment already sitting in our own copy of the recipe — this is upstream fixing the thing we were already waiting on. Genuinely behavioral (not a version bump) and touches the load-bearing recipe, so it gets its own issue with a real build+boot verification rather than landing speculatively. | Issue #45 |
| `dcafc268` | **Skip** | Our `README.md` doesn't carry the "Requirements" section this typo lives in — content has already diverged enough that the fix has nothing to apply to. | n/a |

One nuance worth recording: `3430fb69`'s `build.yml` change — dropping
`sudo -E $(command -v just) …` from the `build`, `ostree-rechunk`, and
`tag-images` steps, and `sudo -E` from the `podman push` step — is a
consequence of `ostree-rechunk` no longer needing root. **Porting #45 alone
does not let us drop all of our `sudo` wrapping.** Our `generate-build-tags`
step is *also* sudo-wrapped, for an unrelated reason recorded in the `#39`
comment already in our `build.yml` (it inspects the built image, which needs
root visibility into podman's storage) — a problem the template's rewrite
doesn't touch at all, since the template never sudo-wraps that step in the
first place. Whoever picks up #45 should re-derive which steps can actually
drop `sudo` on our own CI, not copy the template's `build.yml` diff verbatim.

## What we turned down

| Option | Why not |
|---|---|
| Port the whole range as one PR, since it's "just one template drift review" | Two of the eight commits (the `ostree-rechunk` and `rechunk` rewrites) are real behavioral changes to CI-relevant recipes; bundling them with the cosmetic ones would gate trivial cleanups behind a build+boot verification tier they don't need, and violates [ADR-0016](0016-one-idea-per-issue-one-issue-per-pr.md). |
| Treat each of the 8 commits as its own issue | Several are incremental steps toward one final shape (`a18ae9b5`→`3430fb69`→`b9783f6a`; `715d4b2d`→`94e9423c`). An issue per intermediate commit would ask a reviewer to evaluate states upstream itself abandoned days later. Grouped by final shape instead. |
| Skip the review entirely and let #43's next scheduled run just re-report the same range | Defeats the purpose of the watcher — the range would sit unreviewed indefinitely, which is the exact failure mode ADR-202608042137 was written to avoid ("the answer is a watch + hand-port, not indifference"). |
| Port `ac6ef404`'s login-action bump anyway, "to stay closer to upstream" | We're already ahead of it (`v4.6.0` > `v4.5.1`); applying it would be a downgrade. Renovate is a better feed for this class of change than reading template commits by hand. |

## What would change our mind

- If a future range shows the same recipe rewritten a third time before we've
  finished porting the second, that's a signal to wait for upstream to settle
  before porting mid-stream — not evidence to abandon hand-review.
- If `#45`'s rootless `ostree-rechunk` port turns out to also let
  `generate-build-tags` drop its own `sudo` wrapping (contrary to the "one
  nuance" note above), update this record's table rather than silently
  fixing it in the `#45` PR only.
- If dormant recipes like `rechunk`/chunkah accumulate several more unported
  upstream revisions before ever being called from `build.yml`, that's a
  signal to either commit to switching CI to chunkah or stop tracking its
  drift at all — not to keep porting a recipe nothing exercises.
