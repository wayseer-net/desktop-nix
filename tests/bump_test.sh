#!/usr/bin/env bash
# Tests scripts/bump.sh against invented releases, served from a folder instead of wayseer.app.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/bump.sh
. "$here/../scripts/bump.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
served=$work/served
failures=0

# fetch stands in for the network: it copies the named file from $served, within the cap.
fetch() {
	local src=$served/${1#https://wayseer.app/v1/app/}
	[[ -f $src ]] || { echo "fetch: $1 isn't served" >&2; return 1; }
	(($(stat -c %s "$src") <= $3)) || { echo "fetch: $1 is over $3 bytes" >&2; return 1; }
	cp "$src" "$2"
}

# invent_release serves an invented tarball for version $1 and the release file listing it.
# $2 replaces the tarball's listed line, as "key: value", to make a broken release.
invent_release() {
	local v=$1 edit=${2-} file=wayseer-$1-linux-x86_64.tar.gz dir=$served/$1 size sum
	mkdir -p "$dir"
	printf 'an invented tarball of %s\n' "$v" >"$dir/$file"
	size=$(stat -c %s "$dir/$file")
	sum=$(sha256sum "$dir/$file" | cut -d' ' -f1)
	{
		echo 'WAYSEER-REL-1.invented-signature-line'
		printf 'version: "%s"\nbuilt: "2027-03-01"\npackages:\n' "$v"
		printf '  - platform: "linux/amd64"\n    kind: "tarball"\n    file: "%s"\n    size: %s\n    sha256: "%s"\n' \
			"$file" "$size" "$sum"
		printf '  - platform: "linux/amd64"\n    kind: "appimage"\n    file: "wayseer-%s-x86_64.AppImage"\n    size: 9\n    sha256: "%s"\n' \
			"$v" "$(printf '%064d' 1)"
	} >"$dir/wayseer-$v.release"
	if [[ -n $edit ]]; then
		local key=${edit%%:*}
		sed -i "0,/^    $key: .*\$/s||    $edit|" "$dir/wayseer-$v.release"
	fi
}

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1" >&2; failures=$((failures + 1)); }

# expect_refused runs bump for version $2 and passes if it fails, writing nothing.
expect_refused() {
	local name=$1 out=$work/refused.nix
	rm -f "$out"
	if (bump "$2" "$out") 2>"$work/why" || [[ -e $out ]]; then fail "$name"; else pass "$name: $(head -1 "$work/why")"; fi
}

test_writes_the_version_url_and_hash() {
	local out=$work/release.nix sri
	invent_release 1.6.0
	sri=sha256-$(openssl dgst -sha256 -binary "$served/1.6.0/wayseer-1.6.0-linux-x86_64.tar.gz" | base64 -w0)
	bump 1.6.0 "$out" >/dev/null
	local want
	want=$(printf '%s\n' \
		'# Written by scripts/bump.sh from the served release; not edited by hand.' \
		'{' \
		'  version = "1.6.0";' \
		'  url = "https://wayseer.app/v1/app/1.6.0/wayseer-1.6.0-linux-x86_64.tar.gz";' \
		"  hash = \"$sri\";" \
		'}')
	if [[ $(cat "$out") == "$want" ]]; then pass "writes the version, URL and hash"; else
		fail "writes the version, URL and hash: got"$'\n'"$(cat "$out")"
	fi
}

test_replaces_an_older_release_file() {
	local out=$work/over.nix
	echo old >"$out"
	invent_release 1.6.1
	bump 1.6.1 "$out" >/dev/null
	if grep -q 'version = "1.6.1";' "$out"; then pass "replaces the older release.nix"; else fail "replaces the older release.nix"; fi
}

test_refuses_what_it_cannot_trust() {
	expect_refused "refuses a version that isn't x.y.z" 1.6
	expect_refused "refuses a version with a path in it" ../1.6.0
	expect_refused "refuses a release that isn't served" 9.9.9
	invent_release 2.0.0 'sha256: "'"$(printf '%064d' 7)"'"'
	expect_refused "refuses a tarball whose SHA-256 differs from the listed one" 2.0.0
	invent_release 2.0.1 'size: 3'
	expect_refused "refuses a tarball larger than the listed size" 2.0.1
	invent_release 2.0.8 'size: 99999'
	expect_refused "refuses a tarball smaller than the listed size" 2.0.8
	invent_release 2.0.9
	local second
	second=$(tail -n 5 "$served/2.0.9/wayseer-2.0.9.release" | sed 's/"appimage"/"tarball"/')
	printf '%s\n' "$second" >>"$served/2.0.9/wayseer-2.0.9.release"
	sed -i '0,/"appimage"/s//"tarball"/' "$served/2.0.9/wayseer-2.0.9.release"
	expect_refused "refuses a release listing two Linux tarballs" 2.0.9
	invent_release 2.0.2 'sha256: "ABC"'
	expect_refused "refuses a listed hash that isn't 64 lower-case hex digits" 2.0.2
	invent_release 2.0.3 'file: "../wayseer-2.0.3-linux-x86_64.tar.gz"'
	expect_refused "refuses a listed file with a path" 2.0.3
	invent_release 2.0.4 'kind: "zip"'
	expect_refused "refuses a release without a Linux tarball" 2.0.4
	invent_release 2.0.5
	sed -i 's/^version: "2.0.5"/version: "2.0.6"/' "$served/2.0.5/wayseer-2.0.5.release"
	expect_refused "refuses a release that names another version" 2.0.5
	invent_release 2.0.7
	head -c 20000 /dev/zero | tr '\0' '#' >>"$served/2.0.7/wayseer-2.0.7.release"
	expect_refused "refuses a release file larger than 16 KiB" 2.0.7
}

test_writes_the_version_url_and_hash
test_replaces_an_older_release_file
test_refuses_what_it_cannot_trust
if ((failures)); then echo "$failures failed" >&2; exit 1; fi
echo "all passed"
