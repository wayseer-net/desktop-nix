#!/usr/bin/env bash
# Usage: scripts/bump.sh <version>
# Points release.nix at a served release's Linux tarball: it reads the tarball's name, size and
# SHA-256 from the release file, downloads the tarball and checks it against them. Holds no key.
set -euo pipefail

base=https://wayseer.app/v1/app
max_release=16384           # the app's own cap on a release file
max_tarball=$((512 << 20))

# fetch downloads URL $1 to $2 over HTTPS, without redirects, refusing more than $3 bytes.
fetch() {
	curl --proto '=https' --fail --silent --show-error --max-time 600 --max-filesize "$3" \
		-o "$2" "$1"
}

# tarball_entry prints the linux/amd64 tarball's file, size and SHA-256 from release file $1,
# after checking that its manifest names version $2.
tarball_entry() {
	sed -n 2p "$1" | grep -qxF "version: \"$2\"" || { echo "the release doesn't name $2" >&2; return 1; }
	tail -n +2 "$1" | awk '
		/^  - platform: / { platform = $3; kind = file = size = sum = "" }
		/^    kind: / { kind = $2 }
		/^    file: / { file = $2 }
		/^    size: / { size = $2 }
		/^    sha256: / {
			sum = $2
			if (platform == "\"linux/amd64\"" && kind == "\"tarball\"") { print file, size, sum; n++ }
		}
		END { if (n != 1) exit 1 }' | tr -d '"' ||
		{ echo "the release lists no single Linux tarball" >&2; return 1; }
}

# sri prints the Nix hash of a lower-case hex SHA-256.
sri() { printf 'sha256-%s' "$(printf %s "${1^^}" | basenc --base16 -d | base64 -w0)"; }

# write_release writes release.nix to $1 through a file beside it, so it is whole or untouched.
write_release() {
	local tmp
	tmp=$(mktemp "$1.XXXXXX")
	printf '%s\n' \
		'# Written by scripts/bump.sh from the served release; not edited by hand.' \
		'{' \
		"  version = \"$2\";" \
		"  url = \"$3\";" \
		"  hash = \"$4\";" \
		'}' >"$tmp"
	chmod 644 "$tmp"
	mv "$tmp" "$1"
}

# bump checks release $1's served tarball, then writes its release.nix to $2.
bump() {
	local work status=0
	[[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a release version: $1" >&2; return 2; }
	work=$(mktemp -d) || return 1
	checked_release "$1" "$2" "$work" || status=$?
	rm -rf "$work"
	return "$status"
}

# checked_release downloads release $1 into folder $3 and checks it, then writes release.nix to $2.
checked_release() {
	local v=$1 work=$3 entry file size sum
	fetch "$base/$v/wayseer-$v.release" "$work/release" "$max_release" || return 1
	entry=$(tarball_entry "$work/release" "$v") || return 1
	read -r file size sum <<<"$entry"
	[[ $file == "wayseer-$v-linux-x86_64.tar.gz" ]] || { echo "unexpected tarball name: $file" >&2; return 1; }
	if [[ ! $size =~ ^[1-9][0-9]*$ ]] || ((size > max_tarball)); then echo "unexpected size: $size" >&2; return 1; fi
	[[ $sum =~ ^[0-9a-f]{64}$ ]] || { echo "unexpected SHA-256: $sum" >&2; return 1; }
	fetch "$base/$v/$file" "$work/$file" "$size" || return 1
	[[ $(stat -c %s "$work/$file") == "$size" ]] || { echo "$file isn't $size bytes" >&2; return 1; }
	[[ $(sha256sum "$work/$file" | cut -d' ' -f1) == "$sum" ]] || { echo "$file doesn't match its SHA-256" >&2; return 1; }
	write_release "$2" "$v" "$base/$v/$file" "$(sri "$sum")" || return 1
	echo "release.nix now names Wayseer $v ($file, $size bytes)"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	(($# == 1)) || { echo "usage: $0 <version>" >&2; exit 2; }
	bump "$1" "$(cd "$(dirname "$0")/.." && pwd)/release.nix"
fi
