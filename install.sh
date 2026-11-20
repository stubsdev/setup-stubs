#!/usr/bin/env bash
# The action's step (action.yml): installs stubs $VERSION ("latest" or X.Y.Z) for the runner's OS and CPU from
# stubsdev/cli-releases, checks it against the release's SHA256SUMS, and puts it on the PATH.
set -euo pipefail

releases="https://github.com/stubsdev/cli-releases/releases"
version="${VERSION#v}"

if [[ "$version" == latest ]]; then
  auth=()
  [[ -n "${GH_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GH_TOKEN")
  tag=$(curl -fsSL --retry 3 "${auth[@]}" https://api.github.com/repos/stubsdev/cli-releases/releases/latest \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')
  [[ -n "$tag" ]] || { echo "::error::couldn't find the latest stubs release"; exit 1; }
  version="${tag#v}"
fi

case "$RUNNER_OS" in
  Linux) os=linux ext=tar.gz binary=stubs ;;
  macOS) os=darwin ext=tar.gz binary=stubs ;;
  Windows) os=windows ext=zip binary=stubs.exe ;;
  *) echo "::error::no stubs release for $RUNNER_OS"; exit 1 ;;
esac
case "$RUNNER_ARCH" in
  X64) arch=amd64 ;;
  ARM64) arch=arm64 ;;
  *) echo "::error::no stubs release for $RUNNER_ARCH"; exit 1 ;;
esac

archive="stubs_${version}_${os}_${arch}.$ext"
dir="$RUNNER_TOOL_CACHE/stubs/$version/$arch"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 3 -o "$tmp/$archive" "$releases/download/v$version/$archive"
curl -fsSL --retry 3 -o "$tmp/SHA256SUMS" "$releases/download/v$version/SHA256SUMS"
expected=$(awk -v name="$archive" '$2 == name { print $1 }' "$tmp/SHA256SUMS")
[[ -n "$expected" ]] || { echo "::error::SHA256SUMS has no checksum for $archive"; exit 1; }
if command -v sha256sum > /dev/null; then
  actual=$(sha256sum "$tmp/$archive" | cut -d ' ' -f 1)
else
  actual=$(shasum -a 256 "$tmp/$archive" | cut -d ' ' -f 1)
fi
[[ "$actual" == "$expected" ]] || { echo "::error::checksum mismatch for $archive: expected $expected, got $actual"; exit 1; }

mkdir -p "$dir"
if [[ "$ext" == zip ]]; then
  # PowerShell, which every Windows runner has, rather than unzip, which Git Bash may not.
  pwsh -NoProfile -Command "Expand-Archive -Force -Path '$(cygpath -w "$tmp/$archive")' -DestinationPath '$(cygpath -w "$tmp/unzipped")'"
  mv "$tmp/unzipped/$binary" "$dir/$binary"
else
  tar -xzf "$tmp/$archive" -C "$dir" "$binary"
fi
echo "$dir" >> "$GITHUB_PATH"
echo "version=$version" >> "$GITHUB_OUTPUT"
echo "Installed stubs $version to $dir"
