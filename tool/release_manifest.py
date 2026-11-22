"""Generate the update manifest for a versioned release."""

import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import quote, urlparse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--android", type=Path, required=True)
    parser.add_argument("--linux", type=Path, required=True)
    parser.add_argument("--tag")
    parser.add_argument("--output", type=Path, default=Path("haven-updates.json"))
    args = parser.parse_args()

    base = urlparse(args.base_url)
    if base.scheme != "https" or not base.hostname or base.username or base.query or base.fragment:
        parser.error("--base-url must be an HTTPS directory URL")
    root = Path(__file__).resolve().parents[1]
    match = re.search(r"^version:\s+(\d+\.\d+\.\d+)\+([1-9][0-9]*)$", (root / "pubspec.yaml").read_text(), re.M)
    if match is None:
        parser.error("pubspec.yaml must include a version and monotonic build number")
    version, build = match.groups()
    if args.tag and args.tag != f"v{version}":
        parser.error(f"The release tag must be v{version}")

    artifacts = {}
    for platform, path in [("android", args.android), ("linux-x64", args.linux)]:
        length = path.stat().st_size
        if not 0 < length <= 160 * 1024 * 1024:
            parser.error(f"{path.name} is outside the supported update size")
        with path.open("rb") as file:
            digest = hashlib.file_digest(file, "sha256").hexdigest()
        artifacts[platform] = {
            "url": f"{args.base_url.rstrip('/')}/{quote(path.name, safe='')}",
            "sha256": digest,
            "bytes": length,
        }
    args.output.write_text(json.dumps({
        "schema": 1, "version": version, "build": int(build), "artifacts": artifacts,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
