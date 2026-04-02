#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <zig-version>" >&2
  exit 1
fi

version="$1"

python_bin="${PYTHON:-python3}"
if ! command -v "$python_bin" >/dev/null 2>&1; then
  python_bin="python"
fi

runner_os="${RUNNER_OS:-$(uname -s)}"
runner_arch="${RUNNER_ARCH:-$(uname -m)}"

case "$runner_os" in
  Linux | linux)   zig_os="linux" ;;
  Darwin | macOS)  zig_os="macos" ;;
  Windows | MINGW* | MSYS* | CYGWIN*) zig_os="windows" ;;
  *) echo "unsupported OS: $runner_os" >&2; exit 1 ;;
esac

case "$runner_arch" in
  X64 | x86_64 | amd64)    zig_arch="x86_64" ;;
  ARM64 | arm64 | aarch64)  zig_arch="aarch64" ;;
  *) echo "unsupported arch: $runner_arch" >&2; exit 1 ;;
esac

host_key="${zig_arch}-${zig_os}"
tool_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hermes-zig"
install_dir="${tool_root}/${version}/${host_key}"
zig_bin="zig"
[ "$zig_os" = "windows" ] && zig_bin="zig.exe"

if [ ! -x "${install_dir}/${zig_bin}" ]; then
  mkdir -p "$(dirname "$install_dir")"

  zig_metadata="$(
    "$python_bin" - "$version" "$host_key" <<'PY'
import json, sys, urllib.request
version, host_key = sys.argv[1], sys.argv[2]
with urllib.request.urlopen("https://ziglang.org/download/index.json") as r:
    data = json.load(r)
host = data.get(version, {}).get(host_key)
if not host:
    raise SystemExit(f"missing Zig metadata for {version!r} {host_key!r}")
url = host.get("tarball") or host.get("zip")
sha = host.get("shasum") or ""
if not url:
    raise SystemExit(f"missing archive URL for {version!r} {host_key!r}")
print(url)
print(sha)
PY
  )"

  archive_url="$(printf '%s\n' "$zig_metadata" | sed -n '1p')"
  expected_sha="$(printf '%s\n' "$zig_metadata" | sed -n '2p')"

  archive_dir="$(mktemp -d)"
  archive_path="${archive_dir}/${archive_url##*/}"
  extract_dir="$(mktemp -d)"
  trap 'rm -rf "$archive_dir" "$extract_dir"' EXIT

  curl -fsSL --retry 3 "$archive_url" -o "$archive_path"

  "$python_bin" - "$archive_path" "$expected_sha" <<'PY'
import hashlib, sys
path, expected = sys.argv[1], sys.argv[2].strip().lower()
if not expected: sys.exit(0)
d = hashlib.sha256()
with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(1048576), b""): d.update(chunk)
if d.hexdigest().lower() != expected:
    raise SystemExit(f"checksum mismatch: expected {expected}, got {d.hexdigest()}")
PY

  "$python_bin" - "$archive_path" "$extract_dir" <<'PY'
import pathlib, sys, tarfile, zipfile
archive, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
dest.mkdir(parents=True, exist_ok=True)
if archive.suffix == ".zip":
    with zipfile.ZipFile(archive) as z: z.extractall(dest)
else:
    with tarfile.open(archive, "r:*") as t: t.extractall(dest)
PY

  extracted_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  rm -rf "$install_dir"
  mv "$extracted_dir" "$install_dir"
fi

if [ -n "${GITHUB_PATH:-}" ]; then
  printf '%s\n' "$install_dir" >> "$GITHUB_PATH"
fi

"${install_dir}/${zig_bin}" version
