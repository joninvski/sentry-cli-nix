#!/usr/bin/env bash
set -euo pipefail

# Requires Nix and Python 3; run from any directory.
ROOT="$(dirname "$(realpath "$0")")"
export PACKAGE_FILE="$ROOT/package.nix"
python3 - <<'PY'
import json
import os
import re
import subprocess
import urllib.request
from pathlib import Path

package = Path(os.environ["PACKAGE_FILE"])
text = package.read_text()
with urllib.request.urlopen("https://registry.npmjs.org/sentry/latest", timeout=60) as response:
    metadata = json.load(response)
version = metadata["version"]
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit(f"Unexpected stable version: {version!r}")
if metadata.get("dependencies") or metadata.get("optionalDependencies") or metadata.get("peerDependencies"):
    raise SystemExit("Upstream added runtime dependencies; review the packaging before updating")
if metadata.get("license") != "FSL-1.1-Apache-2.0":
    raise SystemExit("Upstream changed its license; review meta.license before updating")
if metadata.get("bin", {}).get("sentry", "").removeprefix("./") != "dist/bin.cjs":
    raise SystemExit("Upstream changed its entry point; review the wrapper before updating")
current = re.search(r'^  version = "([^"]+)";', text, re.MULTILINE)
if not current:
    raise SystemExit("Could not find package version")
if current[1] == version:
    print(f"sentry is already at {version}")
    raise SystemExit(0)
url = f"https://registry.npmjs.org/sentry/-/sentry-{version}.tgz"
result = subprocess.run(
    ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
    check=True, capture_output=True, text=True,
)
hash_value = json.loads(result.stdout)["hash"]
text, versions = re.subn(r'^  version = "[^"]+";', f'  version = "{version}";', text, count=1, flags=re.MULTILINE)
text, hashes = re.subn(r'^    hash = "[^"]+";', f'    hash = "{hash_value}";', text, count=1, flags=re.MULTILINE)
if versions != 1 or hashes != 1:
    raise SystemExit("Could not uniquely replace version and hash")
package.write_text(text)
print(f"Update sentry from {current[1]} to {version}")
PY
