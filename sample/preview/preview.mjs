import { createGenerationController } from "./controller.mjs";
import { selectTextForManualCopy, writeTextToClipboard } from "./clipboard.mjs";
import {
  parseSelectionHash,
  selectionDataset,
  selectionFromDrag,
  serializeSelection,
} from "./state.mjs";

const POLL_INTERVAL_MS = 1000;
const DATASET_KEYS = ["v", "pdf", "page", "x", "y", "width", "height"];

const elements = {
  preview: document.querySelector("#preview"),
  pages: document.querySelector("#pages"),
  documentStatus: document.querySelector("#document-status"),
  refreshStatus: document.querySelector("#refresh-status"),
  pdfLink: document.querySelector("#pdf-link"),
  pdfHash: document.querySelector("#pdf-hash"),
  pageCount: document.querySelector("#page-count"),
  regionSummary: document.querySelector("#region-summary"),
  selectionJson: document.querySelector("#selection-json"),
  copySelection: document.querySelector("#copy-selection"),
  clearSelection: document.querySelector("#clear-selection"),
  copyStatus: document.querySelector("#copy-status"),
};

let currentManifest = null;
let selection = null;
let draftSelection = null;
let activeDrag = null;
let pollTimer = null;
let pollSequence = 0;
let copyResetTimer = null;

function replaceLocationHash(hash) {
  const url = `${window.location.pathname}${window.location.search}${hash}`;
  window.history.replaceState(null, "", url);
}

function renderSelectionOverlay() {
  for (const box of elements.pages.querySelectorAll(".selection-box")) {
    box.hidden = true;
  }
  const visible = draftSelection ?? selection;
  if (!visible) return;
  const surface = elements.pages.querySelector(`.page-surface[data-page="${visible.page}"]`);
  const box = surface?.querySelector(".selection-box");
  if (!box) return;
  box.style.left = `${visible.x * 100}%`;
  box.style.top = `${visible.y * 100}%`;
  box.style.width = `${visible.width * 100}%`;
  box.style.height = `${visible.height * 100}%`;
  box.hidden = false;
}

function clearCopyFeedback() {
  window.clearTimeout(copyResetTimer);
  copyResetTimer = null;
  elements.copySelection.textContent = "Copy Region";
  elements.copyStatus.textContent = "";
}

function showCopyFeedback(buttonText, message, duration) {
  clearCopyFeedback();
  elements.copySelection.textContent = buttonText;
  elements.copyStatus.textContent = message;
  copyResetTimer = window.setTimeout(clearCopyFeedback, duration);
}

function renderSelectionState() {
  clearCopyFeedback();
  for (const key of DATASET_KEYS) delete elements.preview.dataset[key];
  if (selection) {
    Object.assign(elements.preview.dataset, selectionDataset(selection));
    elements.regionSummary.textContent = `Page ${selection.page} · ${selection.x.toFixed(6)}, ${selection.y.toFixed(6)} · ${selection.width.toFixed(6)} × ${selection.height.toFixed(6)}`;
    elements.selectionJson.value = JSON.stringify(selection, null, 2);
    elements.copySelection.disabled = false;
    elements.clearSelection.disabled = false;
  } else {
    elements.regionSummary.textContent = "No region selected";
    elements.selectionJson.value = "No region selected.";
    elements.copySelection.disabled = true;
    elements.clearSelection.disabled = true;
  }
  renderSelectionOverlay();
}

function commitSelection(nextSelection) {
  selection = nextSelection;
  draftSelection = null;
  replaceLocationHash(serializeSelection(nextSelection));
  renderSelectionState();
}

function releaseActivePointer() {
  if (!activeDrag) return;
  const { input, pointerId } = activeDrag;
  activeDrag = null;
  if (input.hasPointerCapture(pointerId)) input.releasePointerCapture(pointerId);
}

function clearSelection({ updateUrl = true } = {}) {
  releaseActivePointer();
  selection = null;
  draftSelection = null;
  if (updateUrl) replaceLocationHash("");
  renderSelectionState();
}

function selectionForPointer(event) {
  if (!activeDrag || !currentManifest || event.pointerId !== activeDrag.pointerId) return null;
  const bounds = activeDrag.surface.getBoundingClientRect();
  return selectionFromDrag({
    manifest: currentManifest,
    page: activeDrag.page,
    startX: activeDrag.startClientX - bounds.left,
    startY: activeDrag.startClientY - bounds.top,
    endX: event.clientX - bounds.left,
    endY: event.clientY - bounds.top,
    surfaceWidth: bounds.width,
    surfaceHeight: bounds.height,
  });
}

function beginDrag(event, page, surface, input) {
  if (
    !currentManifest ||
    !event.isPrimary ||
    event.button !== 0 ||
    !["mouse", "pen"].includes(event.pointerType) ||
    activeDrag
  ) {
    return;
  }
  activeDrag = {
    pointerId: event.pointerId,
    page,
    surface,
    input,
    startClientX: event.clientX,
    startClientY: event.clientY,
  };
  draftSelection = null;
  input.setPointerCapture(event.pointerId);
  event.preventDefault();
}

function moveDrag(event) {
  if (!activeDrag || event.pointerId !== activeDrag.pointerId) return;
  draftSelection = selectionForPointer(event);
  renderSelectionOverlay();
}

function finishDrag(event) {
  if (!activeDrag || event.pointerId !== activeDrag.pointerId) return;
  const completed = selectionForPointer(event);
  releaseActivePointer();
  draftSelection = null;
  if (completed) commitSelection(completed);
  else renderSelectionState();
}

function cancelDrag(event) {
  if (!activeDrag || event.pointerId !== activeDrag.pointerId) return;
  activeDrag = null;
  draftSelection = null;
  renderSelectionState();
}

function wireSelectionInput(input, surface, page) {
  input.addEventListener("pointerdown", (event) => beginDrag(event, page, surface, input));
  input.addEventListener("pointermove", moveDrag);
  input.addEventListener("pointerup", finishDrag);
  input.addEventListener("pointercancel", cancelDrag);
  input.addEventListener("lostpointercapture", cancelDrag);
}

async function preloadGeneration(manifest, urls) {
  return Promise.all(
    urls.pages.map(async (url, index) => {
      const image = new Image();
      image.className = "page-image";
      image.alt = `Rendered preview of PDF page ${index + 1}`;
      image.decoding = "async";
      image.draggable = false;
      image.src = url;
      await image.decode();
      return image;
    }),
  );
}

function commitGeneration(manifest, urls, images) {
  releaseActivePointer();
  draftSelection = null;
  const fragment = document.createDocumentFragment();
  images.forEach((image, index) => {
    const page = index + 1;
    const figure = document.createElement("figure");
    figure.className = "page";
    const surface = document.createElement("div");
    surface.className = "page-surface";
    surface.dataset.page = String(page);
    const box = document.createElement("div");
    box.className = "selection-box";
    box.hidden = true;
    const input = document.createElement("div");
    input.className = "selection-input";
    input.setAttribute("aria-label", `Select a region on page ${page} with a mouse or pen`);
    wireSelectionInput(input, surface, page);
    const caption = document.createElement("figcaption");
    caption.textContent = `Page ${page}`;
    surface.append(image, box, input);
    figure.append(surface, caption);
    fragment.append(figure);
  });

  elements.pages.replaceChildren(fragment);
  elements.pdfLink.href = urls.pdf;
  elements.pdfLink.setAttribute("aria-disabled", "false");
  elements.pdfHash.textContent = manifest.pdfSha256.slice(0, 12);
  elements.pdfHash.title = manifest.pdfSha256;
  elements.pageCount.textContent = String(manifest.pageCount);
}

function afterGenerationCommit(previous, next) {
  draftSelection = null;
  currentManifest = next;
  const restored = parseSelectionHash(window.location.hash, next);
  selection = restored;
  if (restored) {
    const canonicalHash = serializeSelection(restored);
    if (window.location.hash !== canonicalHash) replaceLocationHash(canonicalHash);
  } else if (window.location.hash) {
    replaceLocationHash("");
  }
  renderSelectionState();
  if (previous && previous.pdfSha256 !== next.pdfSha256) {
    elements.regionSummary.textContent = "No region selected · PDF changed";
  }
}

function reportStatus(kind, detail) {
  elements.refreshStatus.dataset.state = kind;
  if (kind === "refreshing") {
    elements.refreshStatus.textContent = "Refreshing";
    elements.documentStatus.textContent = currentManifest
      ? "Checking for an updated PDF…"
      : "Loading the generated PDF…";
    return;
  }
  if (kind === "ready") {
    elements.refreshStatus.textContent = "Ready";
    elements.documentStatus.textContent = `PDF ${detail.pdfSha256.slice(0, 12)} · ${detail.pageCount} pages`;
    return;
  }
  elements.refreshStatus.textContent = "Retrying";
  elements.documentStatus.textContent = currentManifest
    ? "Refresh failed; showing the last good PDF and retrying."
    : "Preview unavailable; retrying.";
}

const generation = createGenerationController({
  fetcher: window.fetch.bind(window),
  preload: preloadGeneration,
  commit: commitGeneration,
  afterCommit: afterGenerationCommit,
  reportStatus,
});

async function poll(sequence) {
  await generation.refresh();
  if (sequence !== pollSequence || document.hidden) return;
  pollTimer = window.setTimeout(() => poll(sequence), POLL_INTERVAL_MS);
}

function stopPolling() {
  pollSequence += 1;
  if (pollTimer !== null) window.clearTimeout(pollTimer);
  pollTimer = null;
}

function startPolling() {
  stopPolling();
  if (document.hidden) return;
  const sequence = pollSequence;
  void poll(sequence);
}

elements.clearSelection.addEventListener("click", () => clearSelection());
elements.copySelection.addEventListener("click", async () => {
  if (!selection) return;
  const text = JSON.stringify(selection, null, 2);
  try {
    await writeTextToClipboard(text);
    if (elements.selectionJson.value !== text) return;
    showCopyFeedback("Copied", "Region copied", 1200);
  } catch {
    if (!selectTextForManualCopy(elements.selectionJson, text)) {
      showCopyFeedback("Copy Region", "Selection changed · copy again", 1600);
      return;
    }
    showCopyFeedback("Selected", "Clipboard blocked · press your copy shortcut", 1600);
  }
});

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") clearSelection();
});
window.addEventListener("hashchange", () => {
  if (!currentManifest) return;
  const restored = parseSelectionHash(window.location.hash, currentManifest);
  selection = restored;
  draftSelection = null;
  if (restored) {
    const canonicalHash = serializeSelection(restored);
    if (window.location.hash !== canonicalHash) replaceLocationHash(canonicalHash);
  } else if (window.location.hash) {
    replaceLocationHash("");
  }
  renderSelectionState();
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) stopPolling();
  else startPolling();
});
window.addEventListener("beforeunload", stopPolling);

renderSelectionState();
startPolling();
