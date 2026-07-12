const MANIFEST_KEYS = ["pageCount", "pdfSha256", "schemaVersion"];
const SELECTION_KEYS = ["height", "page", "pdf", "v", "width", "x", "y"];
const HASH_KEYS = ["v", "pdf", "page", "x", "y", "width", "height"];
const NUMERIC_HASH_KEYS = ["v", "page", "x", "y", "width", "height"];
const SHA256 = /^[0-9a-f]{64}$/;
const MIN_DRAG_PIXELS = 4;

function hasExactKeys(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const keys = Object.keys(value).sort();
  return keys.length === expected.length && keys.every((key, index) => key === expected[index]);
}

function roundCoordinate(value) {
  return Number(value.toFixed(6));
}

function clamp(value, minimum, maximum) {
  return Math.min(Math.max(value, minimum), maximum);
}

export function validateManifest(value) {
  if (!hasExactKeys(value, MANIFEST_KEYS)) return null;
  if (value.schemaVersion !== 1) return null;
  if (typeof value.pdfSha256 !== "string" || !SHA256.test(value.pdfSha256)) return null;
  if (!Number.isInteger(value.pageCount) || value.pageCount < 1) return null;
  return {
    schemaVersion: 1,
    pdfSha256: value.pdfSha256,
    pageCount: value.pageCount,
  };
}

export function artifactUrls(value) {
  const manifest = validateManifest(value);
  if (!manifest) throw new TypeError("Invalid preview manifest");
  const root = `./artifacts/${manifest.pdfSha256}`;
  return {
    pdf: `${root}/research-paper.pdf`,
    pages: Array.from(
      { length: manifest.pageCount },
      (_, index) => `${root}/page-${index + 1}.png`,
    ),
  };
}

export function normalizeSelection(value, manifest) {
  const validManifest = validateManifest(manifest);
  if (!validManifest || !hasExactKeys(value, SELECTION_KEYS)) return null;
  if (value.v !== 1 || value.pdf !== validManifest.pdfSha256) return null;
  if (!Number.isInteger(value.page) || value.page < 1 || value.page > validManifest.pageCount) {
    return null;
  }

  const coordinates = [value.x, value.y, value.width, value.height];
  if (!coordinates.every((coordinate) => Number.isFinite(coordinate))) return null;
  if (value.x < 0 || value.y < 0 || value.width <= 0 || value.height <= 0) return null;
  if (value.x + value.width > 1 || value.y + value.height > 1) return null;

  const x = roundCoordinate(value.x);
  const y = roundCoordinate(value.y);
  const normalized = {
    v: 1,
    pdf: validManifest.pdfSha256,
    page: value.page,
    x,
    y,
    width: roundCoordinate(Math.min(value.width, 1 - x)),
    height: roundCoordinate(Math.min(value.height, 1 - y)),
  };
  if (
    normalized.width <= 0 ||
    normalized.height <= 0 ||
    normalized.x + normalized.width > 1 ||
    normalized.y + normalized.height > 1
  ) {
    return null;
  }
  return normalized;
}

export function parseSelectionHash(hash, manifest) {
  if (typeof hash !== "string" || hash === "" || hash === "#") return null;
  const params = new URLSearchParams(hash.startsWith("#") ? hash.slice(1) : hash);
  const keys = [...params.keys()];
  if (
    keys.length !== HASH_KEYS.length ||
    !HASH_KEYS.every((key) => params.getAll(key).length === 1) ||
    !keys.every((key) => HASH_KEYS.includes(key))
  ) {
    return null;
  }
  for (const key of NUMERIC_HASH_KEYS) {
    const value = params.get(key);
    if (value.trim() === "" || !Number.isFinite(Number(value))) return null;
  }

  return normalizeSelection(
    {
      v: Number(params.get("v")),
      pdf: params.get("pdf"),
      page: Number(params.get("page")),
      x: Number(params.get("x")),
      y: Number(params.get("y")),
      width: Number(params.get("width")),
      height: Number(params.get("height")),
    },
    manifest,
  );
}

export function serializeSelection(value) {
  const manifest = {
    schemaVersion: 1,
    pdfSha256: value?.pdf,
    pageCount: value?.page,
  };
  const selection = normalizeSelection(value, manifest);
  if (!selection) throw new TypeError("Invalid preview selection");
  const params = new URLSearchParams();
  params.set("v", "1");
  params.set("pdf", selection.pdf);
  params.set("page", String(selection.page));
  params.set("x", selection.x.toFixed(6));
  params.set("y", selection.y.toFixed(6));
  params.set("width", selection.width.toFixed(6));
  params.set("height", selection.height.toFixed(6));
  return `#${params.toString()}`;
}

export function selectionFromDrag({
  manifest,
  page,
  startX,
  startY,
  endX,
  endY,
  surfaceWidth,
  surfaceHeight,
}) {
  const validManifest = validateManifest(manifest);
  const values = [startX, startY, endX, endY, surfaceWidth, surfaceHeight];
  if (
    !validManifest ||
    !Number.isInteger(page) ||
    page < 1 ||
    page > validManifest.pageCount ||
    !values.every((value) => Number.isFinite(value)) ||
    surfaceWidth <= 0 ||
    surfaceHeight <= 0
  ) {
    return null;
  }

  const left = Math.min(clamp(startX, 0, surfaceWidth), clamp(endX, 0, surfaceWidth));
  const right = Math.max(clamp(startX, 0, surfaceWidth), clamp(endX, 0, surfaceWidth));
  const top = Math.min(clamp(startY, 0, surfaceHeight), clamp(endY, 0, surfaceHeight));
  const bottom = Math.max(clamp(startY, 0, surfaceHeight), clamp(endY, 0, surfaceHeight));
  if (right - left < MIN_DRAG_PIXELS || bottom - top < MIN_DRAG_PIXELS) return null;

  return normalizeSelection(
    {
      v: 1,
      pdf: validManifest.pdfSha256,
      page,
      x: left / surfaceWidth,
      y: top / surfaceHeight,
      width: (right - left) / surfaceWidth,
      height: (bottom - top) / surfaceHeight,
    },
    validManifest,
  );
}

export function selectionDataset(value) {
  const manifest = {
    schemaVersion: 1,
    pdfSha256: value?.pdf,
    pageCount: value?.page,
  };
  const selection = normalizeSelection(value, manifest);
  if (!selection) throw new TypeError("Invalid preview selection");
  return {
    v: String(selection.v),
    pdf: selection.pdf,
    page: String(selection.page),
    x: selection.x.toFixed(6),
    y: selection.y.toFixed(6),
    width: selection.width.toFixed(6),
    height: selection.height.toFixed(6),
  };
}
