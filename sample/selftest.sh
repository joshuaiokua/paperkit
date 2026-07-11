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
RICH_TITLE_MD="$VISUAL_DIR/rich-title.md"
cleanup() {
  rm -f "$RESEARCH_TYP"
  rm -rf "$VISUAL_DIR"
}
verify_manifest() {
  local directory="$1"
  local manifest="${2:-MANIFEST.sha256}"
  (cd "$directory" && shasum -a 256 -c "$manifest")
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

verify_manifest "$KIT/fonts"

"$KIT/render.sh" "$KIT/sample/sample.md"

"${PY[@]}" "$KIT/check_render.py" "$KIT/sample/sample.pdf" \
  --min-pages 2 --min-links 6 \
  --sentinel "paperkit sample document" \
  --sentinel-count "paperkit sample document=2" \
  --sentinel "PAPERKIT SAMPLE PIPELINE" \
  --forbid-text "Joshua Iokua" \
  --require-title "paperkit sample document" \
  --require-author "Joshua Iokua" \
  --require-uri-once "https://jiokua.dev" \
  --require-font Geist --require-font Literata --require-font DejaVuSans

printf '%s\n' \
  '# *Linked* [title](https://example.com)' \
  '' \
  'The visible title keeps its authored formatting and link.' \
  '' \
  '```{=typst}' \
  '#pagebreak()' \
  '```' \
  '' \
  'The second-page running title must be plain and unlinked.' \
  > "$RICH_TITLE_MD"

"$KIT/render.sh" "$RICH_TITLE_MD"

"${PY[@]}" "$KIT/check_render.py" "${RICH_TITLE_MD%.md}.pdf" \
  --min-pages 2 --min-links 1 \
  --sentinel-count "Linked title=2" \
  --require-title "Linked title" \
  --require-author "Joshua Iokua" \
  --require-uri-once "https://example.com" \
  --require-font Geist --require-font Literata

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
  --sentinel "research operations" \
  --sentinel "asynchronous review" \
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

verify_manifest "$KIT/sample/goldens"

"$TYPST_BIN" compile "$RESEARCH_TYP" \
  "$VISUAL_DIR/research-paper-{0p}.png" \
  --root=/ \
  --font-path="$KIT/fonts" \
  --ignore-system-fonts \
  --ppi=144

test "$(find "$VISUAL_DIR" -name 'research-paper-*.png' | wc -l | tr -d ' ')" -eq 3
verify_manifest "$VISUAL_DIR" "$KIT/sample/goldens/MANIFEST.sha256"

if PAPERKIT_TYPST_OUT="$VISUAL_DIR/outside.typ" \
  "$KIT/render.sh" "$KIT/sample/research-paper.md" "$VISUAL_DIR/outside.pdf" \
  >"$VISUAL_DIR/outside.log" 2>&1; then
  echo "selftest: PAPERKIT_TYPST_OUT outside the report directory unexpectedly succeeded" >&2
  exit 1
fi
grep -F "PAPERKIT_TYPST_OUT must be in the report directory" "$VISUAL_DIR/outside.log"
