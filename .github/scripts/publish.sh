#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# publish.sh — publish packages to pub.dev, skipping already-published versions
#
# Iterates packages in dependency order, checks pub.dev API for each,
# and only publishes if the local version is not yet on pub.dev.
# Real publish errors (auth, validation) still fail the pipeline.
# ---------------------------------------------------------------------------

PACKAGES=(testwire_protocol testwire testwire_flutter testwire_mcp)

for pkg in "${PACKAGES[@]}"; do
  local_version=$(grep '^version:' "packages/$pkg/pubspec.yaml" | awk '{print $2}')
  published=$(curl -s "https://pub.dev/api/packages/$pkg" \
    | grep -o "\"version\":\"$local_version\"" || true)

  if [ -n "$published" ]; then
    echo "⏭ $pkg@$local_version already on pub.dev, skipping."
  else
    echo "📦 Publishing $pkg@$local_version..."
    (cd "packages/$pkg" && dart pub publish --force)
  fi
done
