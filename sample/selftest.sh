#!/usr/bin/env bash
# Kit self-test — the single source of truth for the sample's render contract.
# Verifies the vendored fonts are intact, renders sample/sample.md, and asserts
# every mechanism the kit promises: title promotion, [N] citation links, figure
# SVG text, font embedding, and the branded research-paper fixture. ci.yml and
# release.yml both call this, so the sentinel and font lists cannot drift.
#
# Run it locally to reproduce exactly what CI asserts:  ./sample/selftest.sh
# Honors $TYPST (CI sets it to the setup-typst binary; else render.sh's pin).
# Needs pypdf importable — uses the ambient python3 if it already has it, else
# falls back to `uv run --with pypdf`.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESEARCH_TYP="$KIT/sample/.research-paper.generated.typ"
TYPST_BIN="${TYPST:-$KIT/bin/typst}"
VISUAL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/paperkit-visual.XXXXXX")"
cleanup() {
  rm -f "$RESEARCH_TYP"
  rm -rf "$VISUAL_DIR"
}
trap cleanup EXIT

if python3 -c 'import pypdf' 2>/dev/null; then
  PY=(python3)
elif command -v uv >/dev/null 2>&1; then
  PY=(uv run --quiet --with 'pypdf>=5,<7' python3)
else
  echo "selftest: need pypdf — 'pip install pypdf>=5,<7' or install uv" >&2
  exit 2
fi

( cd "$KIT/fonts" && shasum -a 256 -c MANIFEST.sha256 )

"$KIT/render.sh" "$KIT/sample/sample.md"

"${PY[@]}" "$KIT/check_render.py" "$KIT/sample/sample.pdf" \
  --min-pages 2 --min-links 6 \
  --sentinel "paperkit sample document" \
  --sentinel "PAPERKIT SAMPLE PIPELINE" \
  --require-font Geist --require-font Literata --require-font DejaVuSans

PAPERKIT_TYPST_OUT="$RESEARCH_TYP" \
  "$KIT/render.sh" "$KIT/sample/research-paper.md"

test -s "$RESEARCH_TYP"
grep -F '#metadata("Retention under intermittent constraint") <paperkit-running-title>' \
  "$RESEARCH_TYP"
grep -F '#metadata(("research operations", "evidence quality", "calibration", "asynchronous review")) <paperkit-keywords>' \
  "$RESEARCH_TYP"
grep -F '@gelman2014' "$RESEARCH_TYP"
grep -F '#bibliography(' "$RESEARCH_TYP"

"${PY[@]}" "$KIT/check_render.py" "$KIT/sample/research-paper.pdf" \
  --min-pages 3 --min-links 2 \
  --sentinel "Intermittent evaluation preserves calibration" \
  --sentinel "No estimate" \
  --sentinel "Research note" \
  --sentinel "Keywords" \
  --sentinel "01 Introduction" \
  --sentinel "Retention under intermittent constraint" \
  --sentinel "References" \
  --sentinel-count "Retention under intermittent constraint=2" \
  --sentinel-count "jiokua.dev=3" \
  --forbid-text "Joshua Iokua" \
  --forbid-text "Bibliography" \
  --require-title "Intermittent Evaluation Preserves Calibration Under Sparse Feedback" \
  --require-author "Joshua Iokua" \
  --require-uri-once "https://jiokua.dev" \
  --require-alt "Calibration error relative to the continuous-monitoring condition" \
  --require-font Geist --require-font Literata

"$TYPST_BIN" compile "$RESEARCH_TYP" \
  "$VISUAL_DIR/research-paper-{0p}.png" \
  --root=/ \
  --font-path="$KIT/fonts" \
  --ignore-system-fonts \
  --ppi=144

test "$(find "$VISUAL_DIR" -name 'research-paper-*.png' | wc -l | tr -d ' ')" -eq 3
(cd "$VISUAL_DIR" && shasum -a 256 -c "$KIT/sample/goldens/MANIFEST.sha256")
