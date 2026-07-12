#!/usr/bin/env bash
# Render and inspect the canonical research-paper fixture in a local browser.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: preview-research-paper.sh [render]

With no command, render the fixture and serve its preview on 127.0.0.1.
Use `render` to refresh artifacts without starting another server.

Environment:
  PAPERKIT_PREVIEW_PORT  Local server port (default: 8765)

Dependencies:
  Paperkit's normal Typst/Pandoc toolchain, Python with pypdf (or uv),
  and Poppler's pdftoppm command.

Browser checks:
  See sample/preview/SMOKE.md for the manual interaction matrix.
EOF
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  ""|render)
    MODE="${1:-serve}"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

PORT_INPUT="${PAPERKIT_PREVIEW_PORT:-8765}"
if ! [[ "$PORT_INPUT" =~ ^0*([0-9]{1,5})$ ]]; then
  echo "preview: PAPERKIT_PREVIEW_PORT must be an integer from 1 to 65535" >&2
  exit 2
fi
PORT_NUMBER="${BASH_REMATCH[1]}"
if ((10#$PORT_NUMBER < 1 || 10#$PORT_NUMBER > 65535)); then
  echo "preview: PAPERKIT_PREVIEW_PORT must be an integer from 1 to 65535" >&2
  exit 2
fi
PORT="$((10#$PORT_NUMBER))"

if ! command -v pdftoppm >/dev/null 2>&1; then
  echo "preview: pdftoppm is required (install Poppler)" >&2
  exit 2
fi

if command -v python3 >/dev/null 2>&1 && python3 -c 'import pypdf' 2>/dev/null; then
  PY=(python3)
elif command -v uv >/dev/null 2>&1; then
  PY=(uv run --quiet --with 'pypdf>=5,<7' python3)
else
  echo "preview: python3 with pypdf, or uv, is required" >&2
  exit 2
fi

if [ "$MODE" = "serve" ] && ! "${PY[@]}" -c \
  'import socket, sys; sock = socket.socket(); sock.bind(("127.0.0.1", int(sys.argv[1]))); sock.close()' \
  "$PORT" 2>/dev/null; then
  echo "preview: port $PORT is already in use; set PAPERKIT_PREVIEW_PORT to another port" >&2
  exit 2
fi

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="$KIT/tmp/research-paper-preview"
ARTIFACTS_ROOT="$OUTPUT_ROOT/artifacts"
LOCK_DIR="$OUTPUT_ROOT/.render.lock"
STATIC_ROOT="$KIT/sample/preview"
STATIC_FILES=(index.html preview.css preview.mjs state.mjs controller.mjs clipboard.mjs)
STAGE=""
MANIFEST_TMP=""
STATIC_TMP=""
LOCK_HELD=0

release_render_lock() {
  local owner=""
  if [ "$LOCK_HELD" -ne 1 ]; then
    return
  fi
  if [ -f "$LOCK_DIR/pid" ]; then
    IFS= read -r owner < "$LOCK_DIR/pid" || true
  fi
  if [ "$owner" = "$$" ]; then
    rm -f -- "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
  LOCK_HELD=0
}

acquire_render_lock() {
  local stale_pid=""
  local stale_stage
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if [ -f "$LOCK_DIR/pid" ]; then
      IFS= read -r stale_pid < "$LOCK_DIR/pid" || true
    fi
    if [[ "$stale_pid" =~ ^[1-9][0-9]*$ ]] && ! kill -0 "$stale_pid" 2>/dev/null; then
      rm -f -- "$LOCK_DIR/pid"
      if rmdir "$LOCK_DIR" 2>/dev/null; then
        shopt -s nullglob
        for stale_stage in "$OUTPUT_ROOT"/.stage."$stale_pid".*; do
          rm -rf -- "$stale_stage"
        done
        shopt -u nullglob
      fi
    fi
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      echo "preview: another preview render is already running; if no render is active, remove $LOCK_DIR" >&2
      exit 2
    fi
  fi
  if ! printf '%s\n' "$$" > "$LOCK_DIR/pid"; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    echo "preview: could not record render lock ownership" >&2
    exit 1
  fi
  LOCK_HELD=1
}

cleanup() {
  local status=$?
  if [ -n "$MANIFEST_TMP" ]; then
    rm -f -- "$MANIFEST_TMP"
  fi
  if [ -n "$STATIC_TMP" ]; then
    rm -f -- "$STATIC_TMP"
  fi
  if [ -n "$STAGE" ] && [[ "$STAGE" == "$OUTPUT_ROOT"/.stage.* ]]; then
    rm -rf -- "$STAGE"
  fi
  release_render_lock
  return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

render_preview() {
  mkdir -p "$ARTIFACTS_ROOT"
  acquire_render_lock

  STAGE="$(mktemp -d "$OUTPUT_ROOT/.stage.$$.XXXXXX")"
  local pdf="$STAGE/research-paper.pdf"
  "$KIT/render.sh" "$KIT/sample/research-paper.md" "$pdf"
  "${PY[@]}" "$KIT/check_render.py" "$pdf" --min-pages 3
  pdftoppm -png -r 144 -cropbox "$pdf" "$STAGE/page"

  local pages
  local page_count
  local page_number
  shopt -s nullglob
  pages=("$STAGE"/page-*.png)
  shopt -u nullglob
  page_count="${#pages[@]}"
  if [ "$page_count" -lt 1 ]; then
    echo "preview: pdftoppm produced no page images" >&2
    exit 1
  fi

  local normalized_pages="$STAGE/.normalized-pages"
  local page_path
  local page_suffix
  local normalized_path
  mkdir "$normalized_pages"
  for page_path in "${pages[@]}"; do
    page_suffix="${page_path##*/page-}"
    page_suffix="${page_suffix%.png}"
    if ! [[ "$page_suffix" =~ ^[0-9]{1,9}$ ]]; then
      echo "preview: pdftoppm produced an invalid page filename" >&2
      exit 1
    fi
    page_number=$((10#$page_suffix))
    normalized_path="$normalized_pages/page-$page_number.png"
    if [ "$page_number" -lt 1 ] || [ "$page_number" -gt "$page_count" ] || [ -e "$normalized_path" ]; then
      echo "preview: pdftoppm produced a non-contiguous page set" >&2
      exit 1
    fi
    mv "$page_path" "$normalized_path"
  done
  for ((page_number = 1; page_number <= page_count; page_number++)); do
    if [ ! -s "$normalized_pages/page-$page_number.png" ]; then
      echo "preview: pdftoppm produced a non-contiguous page set" >&2
      exit 1
    fi
  done
  pages=("$normalized_pages"/page-*.png)
  mv "${pages[@]}" "$STAGE/"
  rmdir "$normalized_pages"

  local pdf_hash
  local published
  pdf_hash="$("${PY[@]}" -c \
    'import hashlib, pathlib, sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' \
    "$pdf")"
  published="$ARTIFACTS_ROOT/$pdf_hash"
  if [ -d "$published" ]; then
    rm -rf -- "$STAGE"
  else
    mv "$STAGE" "$published"
  fi
  STAGE=""

  local filename
  local static_tmp
  for filename in "${STATIC_FILES[@]}"; do
    if [ ! -f "$STATIC_ROOT/$filename" ]; then
      echo "preview: missing static companion file $STATIC_ROOT/$filename" >&2
      exit 1
    fi
    static_tmp="$OUTPUT_ROOT/.$filename.$$.tmp"
    STATIC_TMP="$static_tmp"
    cp "$STATIC_ROOT/$filename" "$static_tmp"
    mv "$static_tmp" "$OUTPUT_ROOT/$filename"
    STATIC_TMP=""
  done

  MANIFEST_TMP="$OUTPUT_ROOT/.manifest.$$.tmp"
  printf '{\n  "schemaVersion": 1,\n  "pdfSha256": "%s",\n  "pageCount": %s\n}\n' \
    "$pdf_hash" "$page_count" > "$MANIFEST_TMP"
  mv "$MANIFEST_TMP" "$OUTPUT_ROOT/manifest.json"
  MANIFEST_TMP=""

  local directory
  local name
  for directory in "$ARTIFACTS_ROOT"/*; do
    [ -d "$directory" ] || continue
    name="${directory##*/}"
    if [[ "$name" =~ ^[0-9a-f]{64}$ ]] && [ "$name" != "$pdf_hash" ]; then
      rm -rf -- "$directory"
    fi
  done

  echo "preview: rendered $page_count pages from $published/research-paper.pdf"
  release_render_lock
}

render_preview

if [ "$MODE" = "render" ]; then
  exit 0
fi

echo "preview: serving http://127.0.0.1:$PORT/"
echo "preview: refresh from another terminal with ./sample/preview-research-paper.sh render"
exec "${PY[@]}" -m http.server \
  --bind 127.0.0.1 \
  --directory "$OUTPUT_ROOT" \
  "$PORT"
