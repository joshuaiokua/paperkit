#!/usr/bin/env python3
"""Render check for paperkit's pandoc→typst PDFs.

typst never FAILS on a missing font — 0.14 prints a warning but still exits 0
and ships a PDF in its embedded fallback fonts (LibertinusSerif). A wrong-font
PDF is therefore invisible to exit codes; this script is the actual guard:

  1. the PDF exists, is non-empty, and has >= --min-pages pages,
  2. extracted text contains every --sentinel (whitespace-normalized) — pass a
     figure's title/axis text as a sentinel to prove embedded SVGs made it in
     (chart text is real text: the SVGs name fonts rather than outlining them),
  3. the PDF's font programs include every --require-font (repeatable;
     explicit flags REPLACE the default of Geist + Literata — figure-bearing
     docs should pass all three: Geist, Literata, DejaVuSans),
  4. with --min-links N: the PDF carries >= N link annotations (URL autolinks +
     the refs.lua internal citation links) — catches link-pipeline regressions.
  5. the PDF is tagged and any requested metadata, alt text, URI, text-count,
     forbidden-text, and forbidden-font assertions hold.

Dependency: pypdf (`pip install 'pypdf>=5,<7'` or `uv run --with pypdf ...`).

    python3 check_render.py report.pdf --sentinel "Milestone 01" --min-pages 4
"""
import argparse
import re

from pypdf import PdfReader


def norm(t: str) -> str:
    return re.sub(r"\s+", " ", t)


def _resolve(value):
    return value.get_object() if hasattr(value, "get_object") else value


def count_links(reader: PdfReader) -> int:
    n = 0
    for page in reader.pages:
        annots = page.get("/Annots")
        if annots is None:
            continue
        for a in _resolve(annots):
            if _resolve(a).get("/Subtype") == "/Link":
                n += 1
    return n


def link_targets(reader: PdfReader) -> list[str]:
    targets: list[str] = []
    for page in reader.pages:
        annots = page.get("/Annots")
        if annots is None:
            continue
        for ref in _resolve(annots):
            annot = _resolve(ref)
            if annot.get("/Subtype") != "/Link":
                continue
            action = _resolve(annot.get("/A"))
            if action and action.get("/S") == "/URI" and action.get("/URI"):
                targets.append(str(action["/URI"]))
    return targets


def _font_has_program(font: dict) -> bool:
    descriptor = _resolve(font.get("/FontDescriptor"))
    if not descriptor:
        return False
    return any(descriptor.get(key) is not None
               for key in ("/FontFile", "/FontFile2", "/FontFile3"))


def embedded_fonts(reader: PdfReader) -> dict[str, bool]:
    fonts_by_name: dict[str, bool] = {}
    for page in reader.pages:
        res = page.get("/Resources")
        if res is None:
            continue
        fonts = _resolve(res).get("/Font")
        if fonts is None:
            continue
        for ref in _resolve(fonts).values():
            font = _resolve(ref)
            descendants = font.get("/DescendantFonts")
            candidates = (_resolve(descendants) if descendants else [font])
            for candidate_ref in candidates:
                candidate = _resolve(candidate_ref)
                base = candidate.get("/BaseFont") or font.get("/BaseFont")
                if not base:
                    continue
                name = str(base).lstrip("/")
                embedded = _font_has_program(candidate)
                fonts_by_name[name] = fonts_by_name.get(name, True) and embedded
    return fonts_by_name


def unembedded_font_names(fonts: dict[str, bool]) -> list[str]:
    return sorted(name for name, embedded in fonts.items() if not embedded)


def document_metadata(reader: PdfReader) -> dict[str, str]:
    metadata = reader.metadata or {}
    return {
        "title": str(metadata.get("/Title") or ""),
        "author": str(metadata.get("/Author") or ""),
    }


def _document_root(reader: PdfReader) -> dict:
    return _resolve(reader.trailer["/Root"])


def is_tagged_pdf(reader: PdfReader) -> bool:
    root = _document_root(reader)
    mark_info = _resolve(root.get("/MarkInfo")) or {}
    return bool(root.get("/StructTreeRoot") and mark_info.get("/Marked"))


def structure_alt_texts(reader: PdfReader) -> list[str]:
    root = _document_root(reader)
    structure = root.get("/StructTreeRoot")
    if structure is None:
        return []

    alt_texts: list[str] = []
    seen: set[int] = set()

    def visit(value) -> None:
        value = _resolve(value)
        if isinstance(value, list):
            for item in value:
                visit(item)
            return
        if not isinstance(value, dict) or id(value) in seen:
            return
        seen.add(id(value))
        if value.get("/Alt"):
            alt_texts.append(str(value["/Alt"]))
        if value.get("/K") is not None:
            visit(value["/K"])

    visit(structure)
    return alt_texts


def parse_count_requirement(value: str) -> tuple[str, int]:
    try:
        text, count = value.rsplit("=", 1)
        if not text or int(count) < 0:
            raise ValueError
        return text, int(count)
    except ValueError as exc:
        raise ValueError("count requirement must be TEXT=COUNT") from exc


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("pdf")
    ap.add_argument("--sentinel", action="append", default=[],
                    help="string that must appear in the extracted text (repeatable)")
    ap.add_argument("--min-pages", type=int, default=2)
    ap.add_argument("--min-links", type=int, default=0,
                    help="minimum PDF link annotations (0 = don't check)")
    ap.add_argument("--forbid-text", action="append", default=[],
                    help="string that must not appear in extracted text (repeatable)")
    ap.add_argument("--sentinel-count", action="append", default=[], metavar="TEXT=COUNT",
                    help="normalized text that must occur exactly COUNT times (repeatable)")
    ap.add_argument("--require-uri-once", action="append", default=[], metavar="URI",
                    help="external URI that must have exactly one link annotation")
    ap.add_argument("--require-title",
                    help="exact required PDF /Title metadata")
    ap.add_argument("--require-author",
                    help="exact required PDF /Author metadata")
    ap.add_argument("--require-alt", action="append", default=[],
                    help="substring required in tagged structure alt text (repeatable)")
    # default=None, not a list: argparse appends user values TO a list default
    # instead of replacing it — the `or` below gives replace semantics.
    ap.add_argument("--require-font", action="append", default=None,
                    help="substring that must appear among embedded font programs "
                         "(repeatable; explicit flags replace the Geist+Literata default)")
    ap.add_argument("--forbid-font", action="append", default=["Libertinus"],
                    help="substring that must not appear among PDF font names "
                         "(repeatable; default: Libertinus)")
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
    for s in a.forbid_text:
        if norm(s) in text:
            fails.append(f"forbidden text present: {s!r}")
    for requirement in a.sentinel_count:
        try:
            expected_text, expected_count = parse_count_requirement(requirement)
        except ValueError as exc:
            fails.append(str(exc) + f": {requirement!r}")
            continue
        actual_count = text.count(norm(expected_text))
        if actual_count != expected_count:
            fails.append(f"text count for {expected_text!r}: "
                         f"{actual_count} != {expected_count}")

    fonts = embedded_fonts(reader)
    unembedded = unembedded_font_names(fonts)
    if unembedded:
        fails.append("fonts without embedded font programs: " + ", ".join(unembedded))
    for req in (a.require_font or ["Geist", "Literata"]):
        matches = {name: embedded for name, embedded in fonts.items() if req in name}
        if not matches:
            fails.append(f"required font {req!r} not embedded "
                         f"(found: {', '.join(sorted(fonts)) or 'none'}) — "
                         "typst fell back silently; check --font-path")
        elif not all(matches.values()):
            unembedded = ", ".join(sorted(name for name, value in matches.items()
                                           if not value))
            fails.append(f"required font {req!r} has no embedded font program: "
                         f"{unembedded}")
    for forbidden in a.forbid_font:
        matches = sorted(name for name in fonts if forbidden in name)
        if matches:
            fails.append(f"forbidden font {forbidden!r} present: {', '.join(matches)}")

    links = count_links(reader)
    if a.min_links and links < a.min_links:
        fails.append(f"links: {links} < {a.min_links} — autolink/refs.lua regression?")
    uris = link_targets(reader)
    for required_uri in a.require_uri_once:
        actual_count = uris.count(required_uri)
        if actual_count != 1:
            fails.append(f"URI annotations for {required_uri!r}: {actual_count} != 1")

    metadata = document_metadata(reader)
    if a.require_title is not None and metadata["title"] != a.require_title:
        fails.append(f"PDF title: {metadata['title']!r} != {a.require_title!r}")
    if a.require_author is not None and metadata["author"] != a.require_author:
        fails.append(f"PDF author: {metadata['author']!r} != {a.require_author!r}")

    tagged = is_tagged_pdf(reader)
    if not tagged:
        fails.append("PDF is not tagged (/StructTreeRoot and /MarkInfo /Marked required)")
    alt_texts = structure_alt_texts(reader)
    for required_alt in a.require_alt:
        if not any(norm(required_alt) in norm(value) for value in alt_texts):
            fails.append(f"required structure alt text missing: {required_alt!r}")

    print(f"check_render: {a.pdf} · {n} pages · {links} links · "
          f"tagged: {'yes' if tagged else 'no'} · "
          f"fonts: {', '.join(sorted(fonts)) or 'none'}")
    for f in fails:
        print(f" FAIL: {f}")
    print("PASS" if not fails else f"{len(fails)} failure(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
