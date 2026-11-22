#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf '%s\n' 'Usage: package_linux.sh FLUTTER_BUNDLE ARCHIVE' >&2
    exit 2
fi

bundle=$1
archive=$2
build=$(python3 - "$bundle" <<'PY'
import json
import re
import sys
from pathlib import Path

info = json.loads((Path(sys.argv[1]) / "data/flutter_assets/version.json").read_text())
build = info.get("build_number", "")
if info.get("app_name") != "haven" or not re.fullmatch("[1-9][0-9]*", build):
    raise SystemExit("Invalid Haven bundle metadata")
print(build)
PY
)
if [[ ! -x "$bundle/haven" ]]; then
    printf '%s\n' 'Flutter bundle is missing the Haven executable.' >&2
    exit 1
fi
launcher_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
staging=$(mktemp -d)
trap 'rm -rf -- "$staging"' EXIT
package="$staging/Haven-Linux"
mkdir -p "$package/versions"
install -m 755 "$launcher_dir/linux-launcher.sh" "$package/haven"
printf '%s\n' "$build" > "$package/current"
cp -a -- "$bundle" "$package/versions/$build"
tar -czf "$archive" -C "$staging" Haven-Linux
