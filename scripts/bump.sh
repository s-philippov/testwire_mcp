#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# bump.sh — version bump for the testwire monorepo
#
# Uses melos to bump all packages together (fixed versioning mode).
# Melos reads conventional commits since the last version tag to decide
# the bump type and generate changelogs.
#
# How melos determines the bump:
#   fix:              → patch  (0.1.2 → 0.1.3)
#   feat:             → minor  (0.1.2 → 0.2.0)
#   BREAKING CHANGE:  → major  (0.1.2 → 1.0.0)
#   chore/docs/ci:    → ignored (no bump)
#
# Usage:
#   ./scripts/bump.sh              # auto-detect from commits
#   ./scripts/bump.sh patch        # force patch bump
#   ./scripts/bump.sh minor        # force minor bump
#   ./scripts/bump.sh major        # force major bump
#   ./scripts/bump.sh 0.3.0        # force exact version
# ---------------------------------------------------------------------------

cd "$(git rev-parse --show-toplevel)"

PACKAGES=(testwire_protocol testwire testwire_flutter testwire_mcp)

current_version() {
  grep '^version:' packages/testwire/pubspec.yaml | awk '{print $2}'
}

# Show current state
echo "Current version: $(current_version)"
echo ""

if [[ $# -eq 0 ]]; then
  # Auto mode — let melos decide from conventional commits
  echo "Mode: auto (from conventional commits)"
  echo "Commits since last tag:"
  git log "$(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~10)..HEAD" \
    --oneline --no-decorate | head -20
  echo ""

  melos version --yes --all
else
  BUMP="$1"

  # Resolve bump type to next version
  CURRENT=$(current_version)
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

  case "$BUMP" in
    patch) NEXT="$MAJOR.$MINOR.$((PATCH + 1))" ;;
    minor) NEXT="$MAJOR.$((MINOR + 1)).0" ;;
    major) NEXT="$((MAJOR + 1)).0.0" ;;
    *)     NEXT="$BUMP" ;;  # exact version
  esac

  echo "Mode: manual → $NEXT"
  echo ""

  MANUAL_ARGS=()
  for pkg in "${PACKAGES[@]}"; do
    MANUAL_ARGS+=(--manual-version "$pkg:$NEXT")
  done

  melos version --yes --all "${MANUAL_ARGS[@]}"
fi

echo ""
echo "New version: $(current_version)"
echo ""
echo "Next steps:"
echo "  git push --follow-tags    # push commit + tags (triggers CI publish)"
