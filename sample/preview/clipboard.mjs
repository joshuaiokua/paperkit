export async function writeTextToClipboard(
  text,
  {
    clipboard = globalThis.navigator?.clipboard,
    documentRef = globalThis.document,
  } = {},
) {
  if (typeof clipboard?.writeText === "function") {
    try {
      await clipboard.writeText(text);
      return "modern";
    } catch {
      // Local preview shells may deny the async API; use a selected textarea below.
    }
  }

  if (
    !documentRef?.body ||
    typeof documentRef.createElement !== "function" ||
    typeof documentRef.execCommand !== "function"
  ) {
    throw new Error("Clipboard writing is unavailable");
  }

  const textarea = documentRef.createElement("textarea");
  const previouslyFocused = documentRef.activeElement;
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  Object.assign(textarea.style, {
    position: "fixed",
    inset: "0 auto auto -9999px",
    opacity: "0",
  });
  documentRef.body.append(textarea);
  let copied = false;
  try {
    textarea.focus();
    textarea.select();
    textarea.setSelectionRange(0, text.length);
    copied = documentRef.execCommand("copy");
  } finally {
    textarea.remove();
    if (
      previouslyFocused !== textarea &&
      previouslyFocused?.isConnected !== false &&
      typeof previouslyFocused?.focus === "function"
    ) {
      previouslyFocused.focus();
    }
  }
  if (!copied) throw new Error("Clipboard writing failed");
  return "fallback";
}

export function selectTextForManualCopy(readout, expectedText = readout.value) {
  if (readout.value !== expectedText) return false;
  readout.focus();
  readout.select();
  readout.setSelectionRange(0, readout.value.length);
  return true;
}
