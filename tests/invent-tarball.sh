#!/usr/bin/env bash
# Usage: invent-tarball.sh <program> <out> [--old]
# Writes an invented release tarball shaped like the served one, with <program> standing in for
# the app, so the package can be built and run without the network. --old shapes it as 0.27.1's,
# with the app in bin/ and no launcher.
set -euo pipefail
program=$1 out=$2 old=${3-}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
top=$work/wayseer-1.0.0-linux-x86_64

mkdir -p "$top/bin" "$top/lib/wayseer" "$top/share/applications" \
	"$top/share/icons/hicolor/scalable/apps" "$top/share/licenses/wayseer"
printf 'an invented launcher\n' >"$top/bin/wayseer"
install -m 755 "$program" "$top/lib/wayseer/wayseer"
printf 'an invented SDL3\n' >"$top/lib/wayseer/libSDL3.so.0"
printf '[Desktop Entry]\nType=Application\nName=Wayseer\nExec=wayseer\nIcon=wayseer\n' \
	>"$top/share/applications/wayseer.desktop"
printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' >"$top/share/icons/hicolor/scalable/apps/wayseer.svg"
printf 'invented terms\n' >"$top/share/licenses/wayseer/LICENSE"
chmod 755 "$top/bin/wayseer"
if [[ $old == --old ]]; then mv "$top/lib/wayseer/wayseer" "$top/bin/wayseer"; fi
tar --owner=0 --group=0 --numeric-owner --sort=name --mtime=@0 -C "$work" -czf "$out" "${top##*/}"
