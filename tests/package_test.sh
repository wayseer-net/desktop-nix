#!/usr/bin/env bash
# Usage: package_test.sh <package> <tarball>
# Checks a package built from an invented tarball whose app is fake-app.c: the tarball is
# kept byte for byte, Nix is named as the installer, and the wrapper runs the app as it should.
set -euo pipefail
pkg=$1 tarball=$2
copy=$pkg/libexec/wayseer
failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1" >&2; failures=$((failures + 1)); }
check() { if "$2"; then pass "$1"; else fail "$1"; fi; }

# The wrapper, run without an inherited library path.
run() { env -u LD_LIBRARY_PATH "$pkg/bin/wayseer" "$@"; }

# Lists every file under $1 but installed-by, with its hash.
hashes() { (cd "$1" && find . -type f ! -path ./share/wayseer/installed-by -exec sha256sum {} + | sort -k2); }

keeps_the_tarball() {
	tar -xzf "$tarball" -C "$work"
	cmp -s <(hashes "$work"/wayseer-*/) <(hashes "$copy")
}
names_nix() { [[ $(cat "$copy/share/wayseer/installed-by") == Nix ]]; }
keeps_the_app_executable() { [[ -x $copy/lib/wayseer/wayseer ]]; }
shares_the_desktop_file() {
	[[ -f $pkg/share/applications/wayseer.desktop && -f $pkg/share/icons/hicolor/scalable/apps/wayseer.svg ]]
}
# line prints line $1 of what the fake app printed when the wrapper ran it with the rest.
line() { local n=$1; shift; run "$@" | sed -n "${n}p"; }
names_the_wrapper_as_argv0() { [[ $(line 1) == "$pkg/bin/wayseer" ]]; }
passes_arguments() { [[ $(line 2 one 'two three') == "one|two three|" ]]; }
keeps_the_library_path_to_itself() { [[ $(line 3) == "(unset)" ]]; }
leaves_an_inherited_path() { [[ $(LD_LIBRARY_PATH=/invented "$pkg/bin/wayseer" | sed -n 3p) == /invented ]]; }
orders_the_library_path() {
	grep -qF "libs=\${LD_LIBRARY_PATH:+\$LD_LIBRARY_PATH:}/nix/store/" "$pkg/bin/wayseer" &&
		grep -qE ":/run/opengl-driver/lib:$copy/lib/wayseer\$" "$pkg/bin/wayseer"
}
uses_the_nixpkgs_loader() { grep -qE '^exec /nix/store/[^ ]*-glibc-[^ ]*/lib/ld-linux-x86-64\.so\.2 ' "$pkg/bin/wayseer"; }
fills_every_placeholder() { ! grep -qE '@[a-z]+@' "$pkg/bin/wayseer"; }

check "keeps every file of the tarball unchanged" keeps_the_tarball
check "names Nix as the installer" names_nix
check "keeps the app executable" keeps_the_app_executable
check "puts the desktop file and icon in share" shares_the_desktop_file
check "names the wrapper as the app's argv[0]" names_the_wrapper_as_argv0
check "passes the arguments to the app" passes_arguments
check "keeps the library path out of the environment the app passes on" keeps_the_library_path_to_itself
check "leaves an inherited LD_LIBRARY_PATH in that environment as it was" leaves_an_inherited_path
check "puts the inherited path first, then nixpkgs', the drivers and the copy" orders_the_library_path
check "runs the app through nixpkgs' loader" uses_the_nixpkgs_loader
check "leaves no placeholder in the wrapper" fills_every_placeholder

if ((failures)); then echo "$failures failed" >&2; exit 1; fi
echo "all passed"
