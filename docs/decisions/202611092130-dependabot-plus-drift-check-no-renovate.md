# ADR-202611092130: Keep versions current with Dependabot and the drift check; don't run Renovate

- **Status:** Accepted
- **Date:** 2026-11-09
- **Scope:** repo (update tooling)
- **Shipped in:** the PR closing #76

## The question

`.github/renovate.json5` came over from the template. Several records were
written on the assumption that Renovate keeps this repo's versions current:
- ADR-202608042137, finding 3: "Renovate already covers most of the template's churn"
- ADR-0015: a Renovate custom-manager PR is PowerShell's long-term bump gate
- ADR-202608222309: drop the PowerShell drift watch once that Renovate PR lands

Reviewing the #74 drift range showed that Renovate had never run here. Every
bot PR in `git log` came from `dependabot[bot]`, and no Renovate onboarding
PR ever existed. The gap became visible with template `7d6f8495`, a cosign
binary bump through the `cosign-release:` action input. Upstream's Renovate
proposed it. Dependabot only bumps `uses:` refs, so it never would have.
Should we install Renovate, or accept what's actually been running?

## What we chose

Keep what has actually been running, and delete the Renovate config.

- **Dependabot** bumps the `uses:` refs in `.github/workflows/`, weekly.
  `.github/dependabot.yml` already does this, and it's what moved
  `login-action` and `upload-artifact` ahead of the template.
- **The drift check** (`check-drift.sh`, ADR-202608222309) catches everything
  else. Upstream's Renovate does run, so a version it tracks in a file we
  share (e.g. `cosign-release:`) shows up as a template commit in the next
  drift issue. A person then ports it by hand, as with #75. So upstream's bot
  works as our Renovate, one review step removed. That fits a repo where every
  ported template change gets read before it lands anyway
  (ADR-202608042137).
- **`PWSH_VERSION` and `PLASMAZONES_VERSION` stay watched by the drift check
  for good.** The Renovate custom-manager PR that ADR-0015 planned for
  PowerShell won't be built. ADR-0015's tiers still hold. Only PowerShell's
  mechanism changes: a drift issue, then a human bumps it.
- **`.github/renovate.json5` is deleted.** A config for a bot that isn't
  installed implies coverage that doesn't exist, and that's what let three
  ADRs rest on a false premise. The drift check still watches the
  *template's* `renovate.json5`: its rules decide which bumps upstream's bot
  proposes, and so which ones reach us through drift issues.

## What we turned down

| Option | Why not |
|---|---|
| Install the Renovate app and keep `renovate.json5` | Its extra coverage over Dependabot is small here: action inputs like `cosign-release:`, and custom managers we'd still have to write. Upstream already runs Renovate on the same files, and the drift check already relays its results. A second bot means a second stream of PRs to triage for a handful of pins. Owner's call. |
| Run both bots | Duplicate PRs for every `uses:` bump, from two bots with different grouping rules. |
| Keep `renovate.json5` in case Renovate is installed someday | Dead config is what created the false premise in the first place. It's a two-minute restore from git or the template if that day comes. |
| Write Renovate-style regex tracking for `cosign-release:` into `dependabot.yml` | Dependabot has no custom/regex managers. |

## What would change our mind

- **A Renovate-only bump reaches us late enough to matter.** For example, a
  cosign or PowerShell security fix sits unported because the drift issue
  didn't land or nobody acted on it in time. Then install Renovate and write
  the custom managers.
- **Upstream stops running Renovate** or narrows its rules (the drift check
  watches the template's `renovate.json5` to catch this). Upstream's bot is
  doing the version tracking we rely on.
- **This repo grows pins the template doesn't share**, beyond `PWSH_VERSION`
  and `PLASMAZONES_VERSION`, so that the drift check's per-pin
  `check_pinned_version` calls become the bigger maintenance cost.
