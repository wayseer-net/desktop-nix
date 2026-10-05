#!/usr/bin/env bash
# What CI runs: the scripts' lint and tests and the package's, through `nix flake check`, then a
# scan for keys. Needs Nix; gitleaks comes from the flake's nixpkgs.
set -euo pipefail
cd "$(dirname "$0")/.."

nix=(nix --extra-experimental-features 'nix-command flakes')
echo "==> nix flake check"
"${nix[@]}" flake check
"${nix[@]}" shell --inputs-from . nixpkgs#gitleaks --command scripts/keyscan.sh
echo "==> ok"
