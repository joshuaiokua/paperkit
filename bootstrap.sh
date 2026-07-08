#!/usr/bin/env bash
# Bootstrap paperkit's pinned render toolchain.
#
#   typst  0.14.2  EXACT pin, installed into <this dir>/bin/ from the GitHub release.
#                  brew can't pin, and typst 0.x releases break templates — 0.15.0
#                  (2026-06-15) postdates pandoc 3.10 and is deliberately NOT used;
#                  bump only when a pandoc release states typst-0.15 compatibility.
#   pandoc >= 3.9  floor, via brew locally (the CI workflows pin 3.10 exactly).
#
# sha256 pins recorded 2026-07-07 from the upstream release assets (upstream
# publishes no checksum files). Bumping the typst version = new asset + new sha
# here AND in render.yml/release.yml, then re-render everything deliberately.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TYPST_VERSION="0.14.2"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    ASSET="typst-aarch64-apple-darwin.tar.xz"
    SHA256="470aa49a2298d20b65c119a10e4ff8808550453e0cb4d85625b89caf0cedf048" ;;
  Linux-x86_64)
    ASSET="typst-x86_64-unknown-linux-musl.tar.xz"
    SHA256="a6044cbad2a954deb921167e257e120ac0a16b20339ec01121194ff9d394996d" ;;
  *) echo "bootstrap: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 2 ;;
esac

if [ -x "$KIT/bin/typst" ] && "$KIT/bin/typst" --version | grep -qF "typst $TYPST_VERSION"; then
  echo "typst $TYPST_VERSION already installed at $KIT/bin/typst"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fsSL -o "$TMP/$ASSET" \
    "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/${ASSET}"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "$SHA256  $TMP/$ASSET" | sha256sum -c -
  else
    echo "$SHA256  $TMP/$ASSET" | shasum -a 256 -c -
  fi
  tar -xJf "$TMP/$ASSET" -C "$TMP"
  mkdir -p "$KIT/bin"
  mv "$TMP/${ASSET%.tar.xz}/typst" "$KIT/bin/typst"
  chmod +x "$KIT/bin/typst"
  echo "installed $("$KIT/bin/typst" --version) -> $KIT/bin/typst"
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "bootstrap: pandoc not found — installing via brew"
  brew install pandoc
fi
PV="$(pandoc --version | head -n1 | awk '{print $2}')"
LOW="$(printf '%s\n3.9\n' "$PV" | sort -V | head -n1)"
if [ "$LOW" != "3.9" ]; then
  echo "bootstrap: pandoc >= 3.9 required for the typst engine (found $PV)" >&2
  exit 2
fi
echo "toolchain ready: typst $TYPST_VERSION · pandoc $PV"
