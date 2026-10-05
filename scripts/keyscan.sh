#!/usr/bin/env bash
# Fails if any commit holds a key or a secret, or the tree a key marker.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> keys and secrets"
gitleaks git --no-banner --redact --log-level warn .
if git grep -nE 'PRIVATE KEY|WAYSEER-1\.|ws-dev-' -- ':!scripts/keyscan.sh'; then
	echo "keyscan: a key marker is in the tree" >&2
	exit 1
fi
