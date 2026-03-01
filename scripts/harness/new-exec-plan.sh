#!/usr/bin/env bash
set -euo pipefail

slug="${1:-}"
title="${2:-}"

if [[ -z "$slug" ]]; then
  echo "Usage: scripts/harness/new-exec-plan.sh slug [title]" >&2
  exit 1
fi

if [[ -z "$title" ]]; then
  title="$slug"
fi

date_str="$(date +%Y-%m-%d)"
path="docs/exec-plans/active/${date_str}--${slug}.md"

if [[ -e "$path" ]]; then
  echo "Already exists: $path" >&2
  exit 1
fi

template="docs/exec-plans/template.md"
if [[ ! -f "$template" ]]; then
  echo "Missing template: $template" >&2
  exit 1
fi

sed \
  -e "s/__TITLE__/${title}/g" \
  -e "s/__DATE__/${date_str}/g" \
  -e "s/__OWNER__/TBD/g" \
  -e "s/__ISSUE_OR_PR__/TBD/g" \
  "$template" > "$path"

echo "Created $path"