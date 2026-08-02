# /// script
# requires-python = ">=3.13"
# dependencies = ["ocx-mirror-sdk"]
#
# [tool.uv.sources]
# ocx-mirror-sdk = { url = "https://github.com/ocx-sh/ocx-mirror-sdk/releases/download/v0.5.2/ocx_mirror_sdk-0.5.2-py3-none-any.whl" }
# ///
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The OCX Authors

"""Generate url_index JSON for JFrog CLI releases.

JFrog does not publish release assets on GitHub. The raw binaries (not
archives) live under a directory index on releases.jfrog.io, one folder per
version, one folder per platform, each holding a single `jf` / `jf.exe`
binary. Version discovery scrapes the HTML directory index.
"""

import re

from ocx_mirror_sdk import IndexBuilder
from ocx_mirror_sdk.http import fetch_text

BASE_URL = "https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf"

# JFrog platform directory name -> binary filename inside that directory.
# We mirror the `jf` binary (the current CLI name, not the legacy `jfrog`).
# macOS `mac-386` is JFrog's Intel (amd64) build, not a 32-bit build — its
# naming is a historical quirk, mapped to darwin/amd64 in mirror.yml.
PLATFORMS = {
    "jfrog-cli-linux-amd64": "jf",
    "jfrog-cli-linux-arm64": "jf",
    "jfrog-cli-mac-386": "jf",
    "jfrog-cli-mac-arm64": "jf",
    "jfrog-cli-windows-amd64": "jf.exe",
}

VERSION_RE = re.compile(r'href="(\d+\.\d+\.\d+)/"')


def main() -> None:
    html = fetch_text(BASE_URL + "/")
    versions = VERSION_RE.findall(html)

    index = IndexBuilder()

    for version in versions:
        assets: dict[str, str] = {}
        for platform_dir, binary_name in PLATFORMS.items():
            # Use a flat filename (no path separator) — the pipeline treats the
            # asset name as a filename in its work directory. Keeping the `.exe`
            # suffix on Windows lets `asset_type.name: jf` land it as `jf.exe`.
            filename = f"{platform_dir}-{binary_name}"
            url = f"{BASE_URL}/{version}/{platform_dir}/{binary_name}"
            assets[filename] = url

        index.add_version(version, assets=assets, prerelease=False)

    index.emit()


if __name__ == "__main__":
    main()
