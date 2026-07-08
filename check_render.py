#!/usr/bin/env python3
"""Render check for paperkit's pandoc→typst PDFs.

typst never FAILS on a missing font — 0.14 prints a warning but still exits 0
and ships a PDF in its embedded fallback fonts (LibertinusSerif). A wrong-font
PDF is therefore invisible to exit codes; this script is the actual guard:

  1. the PDF exists, is non-empty, and has >= --min-pages pages,
  2. extracted text contains every --sentinel (whitespace-normalized) — pass a
     figure's title/axis text as a sentinel to prove embedded SVGs made it in
     (chart text is real text: the SVGs name fonts rather than outlining them),
  3. the PDF's embedded fonts include every --require-font (repeatable;
     explicit flags REPLACE the default of Geist + Literata — figure-bearing
     docs should pass all three: Geist, Literata, DejaVuSans),
  4. with --min-links N: the PDF carries >= N link annotations (URL autolinks +
     the refs.lua internal citation links) — catches link-pipeline regressions.

Dependency: pypdf (`pip install 'pypdf>=5,<7'` or `uv run --with pypdf ...`).

    python3 check_render.py report.pdf --sentinel "Milestone 01" --min-pages 4
"""
import argparse
import re

from pypdf import PdfReader


def norm(t: str) -> str:
    return re.sub(r"\s+", " ", t)


def count_links(reader: PdfReader) -> int:
    n = 0
    for page in reader.pages:
        annots = page.get("/Annots")
        if annots is None:
            continue
        for a in annots.get_object():
            if a.get_object().get("/Subtype") == "/Link":
                n += 1
    return n


def embedded_fonts(reader: PdfReader) -> set[str]:
    names: set[str] = set()
    for page in reader.pages:
        res = page.get("/Resources")
        if res is None:
            continue
        fonts = res.get_object().get("/Font")
        if fonts is None:
            continue
        for f in fonts.get_object().values():
            base = f.get_object().get("/BaseFont")
            if base:
                names.add(str(base).lstrip("/"))
    return names


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("pdf")
    ap.add_argument("--sentinel", action="append", default=[],
                    help="string that must appear in the extracted text (repeatable)")
    ap.add_argument("--min-pages", type=int, default=2)
    ap.add_argument("--min-links", type=int, default=0,
                    help="minimum PDF link annotations (0 = don't check)")
    # default=None, not a list: argparse appends user values TO a list default
    # instead of replacing it — the `or` below gives replace semantics.
    ap.add_argument("--require-font", action="append", default=None,
                    help="substring that must appear among embedded BaseFont names "
                         "(repeatable; explicit flags replace the Geist+Literata default)")
    a = ap.parse_args()

    fails: list[str] = []
    reader = PdfReader(a.pdf)

    n = len(reader.pages)
    if n < a.min_pages:
        fails.append(f"pages: {n} < {a.min_pages}")

    text = norm(" ".join((p.extract_text() or "") for p in reader.pages))
    for s in a.sentinel:
        if norm(s) not in text:
            fails.append(f"sentinel missing from text: {s!r}")

    fonts = embedded_fonts(reader)
    for req in (a.require_font or ["Geist", "Literata"]):
        if not any(req in f for f in fonts):
            fails.append(f"required font {req!r} not embedded "
                         f"(found: {', '.join(sorted(fonts)) or 'none'}) — "
                         "typst fell back silently; check --font-path")

    links = count_links(reader)
    if a.min_links and links < a.min_links:
        fails.append(f"links: {links} < {a.min_links} — autolink/refs.lua regression?")

    print(f"check_render: {a.pdf} · {n} pages · {links} links · "
          f"fonts: {', '.join(sorted(fonts)) or 'none'}")
    for f in fails:
        print(f" FAIL: {f}")
    print("PASS" if not fails else f"{len(fails)} failure(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
