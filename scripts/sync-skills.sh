#!/usr/bin/env bash
# Syncs the canonical db-design-pipeline skill to every tool-specific
# location. Run this after editing the skill in .opencode/skills/.
#
# Usage: ./scripts/sync-skills.sh

set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE=".opencode/skills/db-design-pipeline"

if [ ! -d "$SOURCE" ]; then
  echo "Canonical skill not found at $SOURCE — aborting." >&2
  exit 1
fi

TARGETS=(
  ".claude/skills/db-design-pipeline"
  ".openclaw/skills/db-design-pipeline"
)

for target in "${TARGETS[@]}"; do
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  cp -r "$SOURCE" "$target"
  echo "Synced -> $target"
done

echo "Done. Antigravity and Codex CLI read the skill via the AGENTS.md"
echo "pointer to $SOURCE directly, so no copy is needed for them."
