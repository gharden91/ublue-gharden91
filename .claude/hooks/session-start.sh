#!/bin/bash
# SessionStart hook — orientation, not setup.
# CLAUDE.md loads automatically; docs/, decisions/ and the tracker do not.
# This prints a short index into context so they're seen, not just present.
# Keep it short — every session pays for it. Facts belong in docs/, not here.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"

REPO=$(git config --get remote.origin.url 2>/dev/null \
       | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')

echo "── Where knowledge lives ────────────────────────────────────────"
echo "durable → CLAUDE.md + docs/  |  why → docs/decisions/  |  open work → Issues  |  history → git log"
echo

if [ -d docs ]; then
  echo "docs/ — current reference, edited in place:"
  for f in docs/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "README.md" ] && continue
    title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //')
    printf '  %-28s %s\n' "$(basename "$f")" "$title"
  done
  echo
fi

# Printed in FULL, not linked. The point is that settled questions are seen
# before one gets re-proposed. A pointer nobody follows is the old notes folder.
if [ -d docs/decisions ]; then
  echo "docs/decisions/ — settled; read before proposing a packaging approach, repo/COPR, substrate or rewrite:"
  for f in docs/decisions/[0-9]*.md; do
    [ -e "$f" ] || continue
    title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# ADR-[0-9]*: //')
    status=$(grep -m1 '^- \*\*Status:\*\*' "$f" 2>/dev/null | sed 's/.*Status:\*\* //; s/\[\([^]]*\)\]([^)]*)/\1/g')
    case "$status" in
      Accepted) mark="" ;;
      *)        mark=" [$status]" ;;
    esac
    printf '  %-6s %s%s\n' "$(basename "$f" | cut -d- -f1)" "$title" "$mark"
  done
  echo "  → disagree with one? supersede it with a new record; don't re-litigate silently."
  echo
fi

echo "Open work: GitHub Issues on ${REPO:-this repo} — list them before planning anything."
echo

# Work in flight. A session that doesn't know a PR is already open for its
# branch either duplicates it or force-pushes over a review in progress.
if command -v gh >/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  # timeout: an offline or rate-limited gh must not stall every session start.
  PRS=$(timeout 5 gh pr list --state open --limit 10 \
          --json number,title,isDraft,headRefName,reviewDecision \
          --template '{{range .}}  #{{.number}} {{.title}}{{if .isDraft}} [draft]{{end}}{{if .reviewDecision}} [{{.reviewDecision}}]{{end}}
    └ {{.headRefName}}
{{end}}' 2>/dev/null) || PRS=""
  if [ -n "$PRS" ]; then
    echo "In flight — open PRs (review or update these; don't open a second one):"
    printf '%s\n' "$PRS"
    MINE=$(timeout 5 gh pr list --state open --head "$BRANCH" --json number \
             --jq '.[0].number' 2>/dev/null) || MINE=""
    if [ -n "$MINE" ] && [ "$MINE" != "null" ]; then
      echo "  ↳ this branch ($BRANCH) is PR #$MINE — push to it, don't branch again."
    fi
    echo
  fi
fi

echo "Recently shipped:"
git log --date=short --pretty='  %ad  %s' -5 2>/dev/null || true
echo

echo "Before you finish: run /handoff — it writes decision records, files discovered"
echo "work, updates docs in the same commit, and opens or updates the PR."
echo "Distill, don't dump."
echo "─────────────────────────────────────────────────────────────────"
