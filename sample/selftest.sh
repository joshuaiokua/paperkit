#!/usr/bin/env bash
# Kit self-test — the single source of truth for the sample's render contract.
# Verifies the vendored fonts are intact, renders sample/sample.md, and asserts
# every mechanism the kit promises: title promotion, [N] citation links, figure
# SVG text, font embedding, and the running section header (the uppercase
# sentinel only appears once hydra renders it on page 2). ci.yml and release.yml
# both call this, so the sentinel and font lists can never drift between them.
#
# Run it locally to reproduce exactly what CI asserts:  ./sample/selftest.sh
# Honors $TYPST (CI sets it to the setup-typst binary; else render.sh's pin).
# Needs pypdf importable — uses the ambient python3 if it already has it, else
# falls back to `uv run --with pypdf`.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESEARCH_TYP="$KIT/sample/.research-paper.generated.typ"
trap 'rm -f "$RESEARCH_TYP"' EXIT

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
  --sentinel "THE PIPELINE UNDER TEST" \
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
  --sentinel "References" \
  --require-font Geist --require-font Literata
