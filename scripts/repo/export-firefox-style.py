#!/usr/bin/env python3
"""Export the repository's UserCSS as a one-style Stylus JSON import."""

import argparse
import json
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the export is stale")
    args = parser.parse_args()

    config = Path(__file__).resolve().parents[2] / "configs" / "firefox"
    source = (config / "page-styles.user.css").read_text()
    header = re.search(r"/\*\s*==UserStyle==(.*?)==/UserStyle==\s*\*/", source, re.S)
    if header is None:
        raise SystemExit("page-styles.user.css has no UserStyle metadata")
    metadata = dict(re.findall(
        r"^@(name|namespace|version|description)\s+(.+)$", header[1], re.M
    ))
    for key in ("name", "namespace", "version"):
        if key not in metadata:
            raise SystemExit(f"page-styles.user.css is missing @{key}")

    style = {
        "name": metadata["name"],
        "description": metadata.get("description", ""),
        "enabled": True,
        "sourceCode": source,
        "usercssData": metadata,
        # Stylus's own JSON exporter uses a placeholder for UserCSS sections;
        # its importer compiles sourceCode rather than needing a second parser.
        "sections": [{"code": ""}],
    }
    output = config / "page-styles.json"
    content = json.dumps([style], ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not output.exists() or output.read_text() != content:
            raise SystemExit("page-styles.json is stale; run python3 scripts/repo/export-firefox-style.py")
        print("Firefox Stylus export is current.")
    else:
        output.write_text(content)
        print(f"Wrote {output}")


if __name__ == "__main__":
    main()
