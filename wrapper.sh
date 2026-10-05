#!@shell@
# shellcheck shell=sh disable=SC2239
# Starts the served app, unpatched, through nixpkgs' glibc loader, with nixpkgs' libraries for
# SDL3 to open and the system's GPU drivers; programs the app starts inherit none of it.
libs=${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}@libs@:/run/opengl-driver/lib:@copy@/lib/wayseer
exec @loader@ --argv0 "$0" --library-path "$libs" @copy@/lib/wayseer/wayseer "$@"
