#!/usr/bin/env bash
# Render a markdown report to PDF: pandoc → typst (pinned), house template, vendored fonts.
#
#   ~/dev/paperkit/render.sh <report.md> [out.pdf]
#
# The PDF is never committed (consumers gitignore reports/*.pdf). After rendering, run
# check_render.py — typst never FAILS on a missing font (0.14 warns but exits 0
# and falls back to its embedded LibertinusSerif), so the guard is the check
# script's embedded-font assertion, not typst's exit code.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="${1:?usage: render.sh <report.md> [out.pdf]}"
OUT="${2:-${REPORT%.md}.pdf}"
# CI sets TYPST to the setup-typst binary on PATH; local default is the bootstrap pin.
TYPST="${TYPST:-$KIT/bin/typst}"
if ! command -v "$TYPST" >/dev/null 2>&1 && [ ! -x "$TYPST" ]; then
  echo "render: no pinned typst — run $KIT/bootstrap.sh first (or set TYPST)" >&2
  exit 2
fi

REPORT_DIR="$(cd "$(dirname "$REPORT")" && pwd)"
REPO_ROOT="$(git -C "$REPORT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$REPORT_DIR")"

TEMPLATE="$KIT/house.typ"
FILTER="$KIT/refs.lua"

# Hermetic typst packages (hydra): vendored under vendor/, resolved before the
# package cache and before any network download.
export TYPST_PACKAGE_PATH="$KIT/vendor"

# Reproducible PDF timestamps: the report's last-commit time (0 for uncommitted drafts).
TS="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$REPORT" 2>/dev/null || true)"
export SOURCE_DATE_EPOCH="${TS:-0}"

# --root=/ + an absolute template path: pandoc's default typst template interpolates the
# `template` variable into `#import "...": conf`, and typst resolves absolute import paths
# against --root (house.typ's own `#import "brand.typ"` resolves relative to house.typ).
# Images: pandoc fetches and copies them beside its temp .typ itself, but it resolves
# relative paths against the CWD — --resource-path points it at the report's dir (a
# missing image is only a pandoc WARNING; check_render.py's per-figure sentinels are the
# real guard). --citeproc is inert until a report carries citeproc metadata.
# +autolink_bare_uris: bibliography URLs are written bare and must be clickable.
# refs.lua: [N] markers -> internal links to bibliography anchors; sibling .md
# report links unlink (a PDF can't resolve them).
pandoc "$REPORT" -o "$OUT" \
  -f markdown+autolink_bare_uris \
  --syntax-highlighting=none \
  --lua-filter="$FILTER" \
  --pdf-engine="$TYPST" \
  -V template="$TEMPLATE" \
  --resource-path="$REPORT_DIR" \
  --citeproc \
  --pdf-engine-opt=--root=/ \
  --pdf-engine-opt=--font-path="$KIT/fonts" \
  --pdf-engine-opt=--ignore-system-fonts \
  --pdf-engine-opt=--pdf-standard=ua-1
echo "rendered $OUT"
