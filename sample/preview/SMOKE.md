# Preview companion browser smoke check

Run `./sample/preview-research-paper.sh`, open the printed loopback URL, and
complete this short matrix before handing off preview UI changes:

1. Confirm all pages appear together, the short PDF hash and page count
   match `manifest.json`, the exact-PDF link opens, and the console is clean.
2. Drag forward, backward, and beyond a page edge with a mouse or pen. Confirm
   the visible box, URL fragment, JSON readout, and `#preview` dataset describe
   the same clamped, normalized rectangle.
3. Confirm a drag smaller than four CSS pixels, `pointercancel`, and lost pointer
   capture restore the prior selection. Confirm touch still scrolls and zooms.
4. Confirm Copy Region, its manual-copy fallback, Clear, Escape, reload
   restoration, malformed fragments, and stale-PDF fragments behave as stated.
5. Resize to a narrow viewport and back. Confirm there is no horizontal
   overflow and the percentage-based rectangle stays aligned with the page.
6. Publish a temporary, genuinely different PDF generation while the server
   remains running. This keeps the canonical artifact intact, appends a benign
   PDF comment to change the bytes, hashes those bytes, and rasterizes them with
   the same Poppler command as the preview script:

   ```sh
   python3 - tmp/research-paper-preview <<'PY'
   import hashlib
   import json
   import os
   from pathlib import Path
   import shutil
   import subprocess
   import sys
   import tempfile

   root = Path(sys.argv[1]).resolve()
   manifest = json.loads((root / "manifest.json").read_text())
   current = root / "artifacts" / manifest["pdfSha256"]
   pdf = (current / "research-paper.pdf").read_bytes() + b"\n% paperkit preview smoke\n"
   pdf_hash = hashlib.sha256(pdf).hexdigest()
   published = root / "artifacts" / pdf_hash
   stage = Path(tempfile.mkdtemp(prefix=".smoke.", dir=root))
   try:
       (stage / "research-paper.pdf").write_bytes(pdf)
       subprocess.run(
           [
               "pdftoppm", "-png", "-r", "144", "-cropbox",
               str(stage / "research-paper.pdf"), str(stage / "page"),
           ],
           check=True,
       )
       if published.exists():
           shutil.rmtree(stage)
       else:
           stage.replace(published)
       temporary = root / ".manifest.smoke.tmp"
       temporary.write_text(json.dumps({
           "schemaVersion": 1,
           "pdfSha256": pdf_hash,
           "pageCount": manifest["pageCount"],
       }) + "\n")
       os.replace(temporary, root / "manifest.json")
       print(f"published smoke generation {pdf_hash}")
   finally:
       shutil.rmtree(stage, ignore_errors=True)
   PY
   ```

   Confirm all decoded pages swap together and a selection from the canonical
   generation clears only after the temporary generation is visible.
7. Make a selection on the temporary generation, then publish a valid manifest
   whose immutable artifact does not exist:

   ```sh
   python3 - tmp/research-paper-preview <<'PY'
   import json
   import os
   from pathlib import Path
   import sys

   root = Path(sys.argv[1]).resolve()
   manifest = json.loads((root / "manifest.json").read_text())
   missing_hash = "f" * 64 if manifest["pdfSha256"] != "f" * 64 else "e" * 64
   temporary = root / ".manifest.smoke.tmp"
   temporary.write_text(json.dumps({
       "schemaVersion": 1,
       "pdfSha256": missing_hash,
       "pageCount": manifest["pageCount"],
   }) + "\n")
   os.replace(temporary, root / "manifest.json")
   print(f"published missing generation {missing_hash}")
   PY
   ```

   Confirm the temporary last-good generation and its selection remain visible
   while the status reports a retry. Restore the canonical generation with
   `./sample/preview-research-paper.sh render`; confirm recovery occurs without
   a page reload and the temporary artifact is removed.
