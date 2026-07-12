import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

let state;
let controllerModule;
let clipboardModule;
try {
  state = await import("../sample/preview/state.mjs");
} catch {
  state = null;
}
try {
  controllerModule = await import("../sample/preview/controller.mjs");
} catch {
  controllerModule = null;
}
try {
  clipboardModule = await import("../sample/preview/clipboard.mjs");
} catch {
  clipboardModule = null;
}

const HASH = "0123456789abcdef".repeat(4);
const OTHER_HASH = "fedcba9876543210".repeat(4);
const MANIFEST = {
  schemaVersion: 1,
  pdfSha256: HASH,
  pageCount: 3,
};
const PREVIEW_SOURCE = await readFile(
  new URL("../sample/preview/preview.mjs", import.meta.url),
  "utf8",
);

function response(value, { ok = true, status = 200 } = {}) {
  return {
    ok,
    status,
    async json() {
      return value;
    },
  };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

test("the companion state module is available", () => {
  assert.ok(state, "sample/preview/state.mjs is not implemented");
});

test("manifest validation accepts only the versioned exact contract", () => {
  assert.ok(state);
  assert.deepEqual(state.validateManifest(MANIFEST), MANIFEST);

  const invalid = [
    null,
    {},
    { ...MANIFEST, schemaVersion: 2 },
    { ...MANIFEST, pdfSha256: HASH.toUpperCase() },
    { ...MANIFEST, pdfSha256: "short" },
    { ...MANIFEST, pageCount: 0 },
    { ...MANIFEST, pageCount: 1.5 },
    { ...MANIFEST, extra: true },
  ];
  for (const value of invalid) {
    assert.equal(state.validateManifest(value), null);
  }
});

test("artifact URLs are immutable and derived from the PDF hash", () => {
  assert.ok(state);
  assert.deepEqual(state.artifactUrls(MANIFEST), {
    pdf: `./artifacts/${HASH}/research-paper.pdf`,
    pages: [
      `./artifacts/${HASH}/page-1.png`,
      `./artifacts/${HASH}/page-2.png`,
      `./artifacts/${HASH}/page-3.png`,
    ],
  });
});

test("selection hashes round-trip with six-decimal normalized coordinates", () => {
  assert.ok(state);
  const selection = {
    v: 1,
    pdf: HASH,
    page: 2,
    x: 0.1,
    y: 0.2345674,
    width: 0.3,
    height: 0.4567894,
  };
  const hash = state.serializeSelection(selection);

  assert.equal(
    hash,
    `#v=1&pdf=${HASH}&page=2&x=0.100000&y=0.234567&width=0.300000&height=0.456789`,
  );
  assert.deepEqual(state.parseSelectionHash(hash, MANIFEST), {
    v: 1,
    pdf: HASH,
    page: 2,
    x: 0.1,
    y: 0.234567,
    width: 0.3,
    height: 0.456789,
  });
});

test("selection parsing rejects stale, malformed, and out-of-page state", () => {
  assert.ok(state);
  const valid = `#v=1&pdf=${HASH}&page=1&x=0.1&y=0.2&width=0.3&height=0.4`;
  const invalid = [
    "",
    valid.replace("v=1", "v=2"),
    valid.replace(HASH, OTHER_HASH),
    valid.replace("page=1", "page=4"),
    valid.replace("x=0.1", "x=NaN"),
    valid.replace("x=0.1", "x=-0.1"),
    valid.replace("width=0.3", "width=0"),
    valid.replace("x=0.1", "x=0.8"),
    valid.replace("x=0.1", "x=0.9999996").replace("width=0.3", "width=0.0000004"),
    `${valid}&extra=true`,
  ];

  for (const hash of invalid) {
    assert.equal(state.parseSelectionHash(hash, MANIFEST), null, hash);
  }
});

test("selection parsing rejects invalid raw numeric fields", () => {
  assert.ok(state);
  const numericFields = ["v", "page", "x", "y", "width", "height"];
  const base = new URLSearchParams({
    v: "1",
    pdf: HASH,
    page: "1",
    x: "0.1",
    y: "0.2",
    width: "0.3",
    height: "0.4",
  });

  for (const field of numericFields) {
    for (const value of ["", "   ", "not-a-number"]) {
      const params = new URLSearchParams(base);
      params.set(field, value);
      assert.equal(
        state.parseSelectionHash(`#${params}`, MANIFEST),
        null,
        `${field}=${JSON.stringify(value)}`,
      );
    }
  }
});

test("drag normalization clamps, reverses, and rejects tiny rectangles", () => {
  assert.ok(state);
  assert.deepEqual(
    state.selectionFromDrag({
      manifest: MANIFEST,
      page: 3,
      startX: 900,
      startY: 1800,
      endX: -100,
      endY: 100,
      surfaceWidth: 1000,
      surfaceHeight: 2000,
    }),
    {
      v: 1,
      pdf: HASH,
      page: 3,
      x: 0,
      y: 0.05,
      width: 0.9,
      height: 0.85,
    },
  );
  assert.equal(
    state.selectionFromDrag({
      manifest: MANIFEST,
      page: 1,
      startX: 10,
      startY: 10,
      endX: 13,
      endY: 30,
      surfaceWidth: 1000,
      surfaceHeight: 1000,
    }),
    null,
  );
});

test("edge-clamped drags survive six-decimal normalization", () => {
  assert.ok(state);
  assert.deepEqual(
    state.selectionFromDrag({
      manifest: MANIFEST,
      page: 1,
      startX: 3,
      startY: 24,
      endX: 384,
      endY: 120,
      surfaceWidth: 384,
      surfaceHeight: 384,
    }),
    {
      v: 1,
      pdf: HASH,
      page: 1,
      x: 0.007813,
      y: 0.0625,
      width: 0.992187,
      height: 0.25,
    },
  );
});

test("pointerdown positively allows only primary mouse or pen input", () => {
  assert.match(PREVIEW_SOURCE, /!event\.isPrimary/);
  assert.match(PREVIEW_SOURCE, /!\["mouse", "pen"\]\.includes\(event\.pointerType\)/);
  assert.match(PREVIEW_SOURCE, /event\.button !== 0/);
  assert.doesNotMatch(PREVIEW_SOURCE, /event\.pointerType === "touch"/);
});

test("dataset projection is a string-only view of canonical state", () => {
  assert.ok(state);
  assert.deepEqual(
    state.selectionDataset({
      v: 1,
      pdf: HASH,
      page: 2,
      x: 0.1,
      y: 0.2,
      width: 0.3,
      height: 0.4,
    }),
    {
      v: "1",
      pdf: HASH,
      page: "2",
      x: "0.100000",
      y: "0.200000",
      width: "0.300000",
      height: "0.400000",
    },
  );
});

test("selection rendering clears every projected dataset field", () => {
  assert.match(
    PREVIEW_SOURCE,
    /const DATASET_KEYS = \["v", "pdf", "page", "x", "y", "width", "height"\]/,
  );
  assert.match(
    PREVIEW_SOURCE,
    /for \(const key of DATASET_KEYS\) delete elements\.preview\.dataset\[key\]/,
  );
});

test("refreshes are serialized and fetch the manifest without cache", async () => {
  assert.ok(controllerModule, "sample/preview/controller.mjs is not implemented");
  const pending = deferred();
  const requests = [];
  const preview = controllerModule.createGenerationController({
    fetcher(url, options) {
      requests.push({ url, options });
      return pending.promise;
    },
    preload: async () => [],
    commit: () => {},
    reportStatus: () => {},
  });

  const first = preview.refresh();
  const second = preview.refresh();

  assert.equal(first, second);
  assert.deepEqual(requests, [
    { url: "./manifest.json", options: { cache: "no-store" } },
  ]);
  pending.resolve(response(MANIFEST));
  await first;
});

test("a generation commits only after every page has preloaded", async () => {
  assert.ok(controllerModule);
  const loaded = deferred();
  const events = [];
  const preview = controllerModule.createGenerationController({
    fetcher: async () => response(MANIFEST),
    preload(manifest, urls) {
      events.push({ type: "preload", manifest, urls });
      return loaded.promise;
    },
    commit(manifest, urls, pages) {
      events.push({ type: "commit", manifest, urls, pages });
    },
    afterCommit(previous, current) {
      events.push({ type: "afterCommit", previous, current });
    },
    reportStatus: () => {},
  });

  const refresh = preview.refresh();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(events.length, 1);
  loaded.resolve(["decoded-1", "decoded-2", "decoded-3"]);
  assert.equal(await refresh, true);
  assert.deepEqual(events.map((event) => event.type), [
    "preload",
    "commit",
    "afterCommit",
  ]);
  assert.equal(events[1].pages.length, 3);
  assert.equal(events[2].previous, null);
  assert.deepEqual(events[2].current, MANIFEST);
});

test("steady-state polls do not churn visible refresh status", async () => {
  assert.ok(controllerModule);
  const statuses = [];
  const preview = controllerModule.createGenerationController({
    fetcher: async () => response(MANIFEST),
    preload: async () => ["decoded"],
    commit: () => {},
    reportStatus(kind) {
      statuses.push(kind);
    },
  });

  assert.equal(await preview.refresh(), true);
  const initialStatuses = [...statuses];
  assert.equal(await preview.refresh(), false);
  assert.equal(await preview.refresh(), false);

  assert.deepEqual(statuses, initialStatuses);
});

test("unchanged and failed refreshes retain the last-good generation", async () => {
  assert.ok(controllerModule);
  const nextManifest = { ...MANIFEST, pdfSha256: OTHER_HASH };
  const responses = [
    response(MANIFEST),
    response(MANIFEST),
    response(nextManifest),
    response({ broken: true }),
    response({}, { ok: false, status: 503 }),
  ];
  const commits = [];
  const statuses = [];
  let failPreload = false;
  const preview = controllerModule.createGenerationController({
    fetcher: async () => responses.shift(),
    async preload() {
      if (failPreload) throw new Error("decode failed");
      return ["decoded"];
    },
    commit(manifest) {
      commits.push(manifest.pdfSha256);
    },
    reportStatus(kind) {
      statuses.push(kind);
    },
  });

  assert.equal(await preview.refresh(), true);
  assert.equal(await preview.refresh(), false);
  failPreload = true;
  assert.equal(await preview.refresh(), false);
  failPreload = false;
  assert.equal(await preview.refresh(), false);
  assert.equal(await preview.refresh(), false);

  assert.deepEqual(commits, [HASH]);
  assert.deepEqual(preview.currentManifest(), MANIFEST);
  assert.equal(statuses.at(-1), "error");
});

test("same-hash manifest metadata drift is rejected", async () => {
  assert.ok(controllerModule);
  const responses = [response(MANIFEST), response({ ...MANIFEST, pageCount: 4 })];
  const commits = [];
  const statuses = [];
  const preview = controllerModule.createGenerationController({
    fetcher: async () => responses.shift(),
    preload: async () => ["decoded"],
    commit(manifest) {
      commits.push(manifest);
    },
    reportStatus(kind) {
      statuses.push(kind);
    },
  });

  assert.equal(await preview.refresh(), true);
  assert.equal(await preview.refresh(), false);
  assert.deepEqual(commits, [MANIFEST]);
  assert.deepEqual(preview.currentManifest(), MANIFEST);
  assert.equal(statuses.at(-1), "error");
});

test("clipboard writing falls back when the modern API is denied", async () => {
  assert.ok(clipboardModule, "sample/preview/clipboard.mjs is not implemented");
  const events = [];
  const textarea = {
    style: {},
    setAttribute(name, value) {
      events.push(["attribute", name, value]);
    },
    select() {
      events.push(["select"]);
    },
    focus() {
      events.push(["focus"]);
    },
    setSelectionRange(start, end) {
      events.push(["range", start, end]);
    },
    remove() {
      events.push(["remove"]);
    },
  };
  const documentRef = {
    activeElement: {
      focus() {
        events.push(["restore-focus"]);
      },
    },
    body: {
      append(element) {
        events.push(["append", element.value]);
      },
    },
    createElement(name) {
      events.push(["create", name]);
      return textarea;
    },
    execCommand(command) {
      events.push(["command", command]);
      return true;
    },
  };

  const method = await clipboardModule.writeTextToClipboard("region-json", {
    clipboard: {
      async writeText() {
        events.push(["modern"]);
        throw new Error("permission denied");
      },
    },
    documentRef,
  });

  assert.equal(method, "fallback");
  assert.deepEqual(events, [
    ["modern"],
    ["create", "textarea"],
    ["attribute", "readonly", ""],
    ["append", "region-json"],
    ["focus"],
    ["select"],
    ["range", 0, 11],
    ["command", "copy"],
    ["remove"],
    ["restore-focus"],
  ]);
});

test("manual clipboard fallback selects the complete canonical readout", () => {
  assert.ok(clipboardModule);
  assert.equal(typeof clipboardModule.selectTextForManualCopy, "function");
  const events = [];
  const readout = {
    value: "canonical-json",
    focus() {
      events.push(["focus"]);
    },
    select() {
      events.push(["select"]);
    },
    setSelectionRange(start, end) {
      events.push(["range", start, end]);
    },
  };

  assert.equal(clipboardModule.selectTextForManualCopy(readout, "canonical-json"), true);

  assert.deepEqual(events, [
    ["focus"],
    ["select"],
    ["range", 0, 14],
  ]);
  assert.equal(clipboardModule.selectTextForManualCopy(readout, "stale-json"), false);
});
