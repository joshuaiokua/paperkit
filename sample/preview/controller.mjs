import { artifactUrls, validateManifest } from "./state.mjs";

export function createGenerationController({
  fetcher,
  preload,
  commit,
  afterCommit = () => {},
  reportStatus = () => {},
}) {
  let manifest = null;
  let inFlight = null;
  let lastAttemptFailed = false;

  async function performRefresh() {
    if (!manifest && !lastAttemptFailed) reportStatus("refreshing");
    try {
      const response = await fetcher("./manifest.json", { cache: "no-store" });
      if (!response?.ok) {
        throw new Error(`manifest request failed (${response?.status ?? "unknown"})`);
      }
      const nextManifest = validateManifest(await response.json());
      if (!nextManifest) throw new Error("manifest is invalid");
      if (manifest?.pdfSha256 === nextManifest.pdfSha256) {
        if (manifest.pageCount !== nextManifest.pageCount) {
          throw new Error("manifest metadata changed without a new PDF hash");
        }
        if (lastAttemptFailed) reportStatus("ready", manifest);
        lastAttemptFailed = false;
        return false;
      }

      if (manifest && !lastAttemptFailed) reportStatus("refreshing");
      const urls = artifactUrls(nextManifest);
      const pages = await preload(nextManifest, urls);
      const previous = manifest;
      await commit(nextManifest, urls, pages);
      manifest = nextManifest;
      afterCommit(previous, nextManifest);
      lastAttemptFailed = false;
      reportStatus("ready", nextManifest);
      return true;
    } catch (error) {
      if (!lastAttemptFailed) reportStatus("error", error);
      lastAttemptFailed = true;
      return false;
    }
  }

  function refresh() {
    if (inFlight) return inFlight;
    inFlight = performRefresh().finally(() => {
      inFlight = null;
    });
    return inFlight;
  }

  return {
    refresh,
    currentManifest() {
      return manifest;
    },
  };
}
