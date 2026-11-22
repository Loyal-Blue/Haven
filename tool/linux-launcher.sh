#!/bin/sh
set -eu
bundle=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
IFS= read -r build < "$bundle/current"
case "$build" in
    ''|*[!0-9]*) printf '%s\n' 'Invalid Haven build number.' >&2; exit 1 ;;
esac
exec "$bundle/versions/$build/haven" "$@"
