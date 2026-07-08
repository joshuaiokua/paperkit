# paperkit

Markdown in, branded accessible PDF out. paperkit is a personal report/paper
rendering toolkit: a typst house template + brand tokens, a pandoc Lua filter for
document shape, vendored fonts, render/check scripts, and installable CI workflows —
**everything pinned by exact version and checksum**, including the kit itself when
consumed from another repository.

- **Markdown is content, typst is styling.** Reports stay readable on GitHub; the
  PDF is generated, never committed.
- **Accessible by construction.** Every render is exported as PDF/UA-1; typst
  enforces the standard's machine-checkable rules at compile time, so an
  accessibility violation is a build failure.
- **Loud failure over silent fallback.** typst exits 0 on a missing font;
  `check_render.py` is the actual guard — embedded-font assertions, per-figure
  text sentinels, link counts, page counts.
- **Boundary rule: paperkit may *style* figures; it is never required to
  *reproduce* them.** Data figures are generated in the repos that own the data
  (science stack: matplotlib/seaborn, regenerated from each repo's own lockfile);
  paperkit consumes them as committed SVGs.

## What's in the box

| file | role |
|---|---|
| `house.typ` | layout: page furniture, running section header, ruled headings, figures |
| `brand.typ` | every brand value — colors, faces, weights; the single re-skin point |
| `refs.lua` | pandoc AST work: H1→title promotion, `[N]`→anchor links (dangling ref = loud failure), sibling-`.md` unlink |
| `render.sh <md> [out.pdf]` | the whole render: pandoc → typst, UA-1, vendored fonts |
| `check_render.py <pdf>` | the guard: pages, sentinels, embedded fonts, link count |
| `bootstrap.sh` | one-time local install of the pinned typst (sha-verified) |
| `fonts/` | vendored faces + per-family licenses ([provenance](fonts/README.md)) |
| `vendor/` | vendored typst packages (hydra + its dependency) — compiles offline |
| `templates/` | the two workflow files consumers install |
| `sample/` | the self-test document CI renders on every push |

## Local use

```sh
./bootstrap.sh                    # installs typst 0.14.2 into bin/ (sha-pinned)
./render.sh path/to/report.md    # -> path/to/report.pdf (PDF/UA-1)
python3 check_render.py path/to/report.pdf \
  --min-pages 2 --min-links 20 \
  --sentinel "Figure 1 title text" \
  --require-font Geist --require-font Literata --require-font DejaVuSans
```

`check_render.py` needs `pypdf>=5,<7`. Defaults assert Geist + Literata embedded;
pass all three `--require-font`s for figure-bearing documents (figure SVGs name
DejaVu Sans). A `[N]` citation with no matching References entry fails the render
itself — that's deliberate.

Report conventions the pipeline assumes: one leading `# H1` (becomes the PDF
title), `##` sections, and a `## References` section whose entries are list items
beginning with `[N]` (those become the link anchors).

## Consumer install (CI)

Copy the two files from `templates/` into your repo's `.github/workflows/`, then
set the pin at the top of each:

```yaml
env:
  PAPERKIT_REF: v0.1.0
  PAPERKIT_SHA256: "<asset digest — printed by paperkit's release workflow>"
```

That's the entire installation. The workflows fetch
`releases/download/<ref>/paperkit-<ref>.tar.gz` (public repo — no token), verify
the sha256, and use the extracted kit. Upgrading = bumping the two env lines,
reviewed like any dependency.

## Versioning

Tags are immutable — this repo has GitHub release immutability enabled, so
published releases and their assets are platform-locked and tag names are never
reusable. Fixes ship as a new tag; consumers move by choice. The release workflow
prints each asset's sha256 digest (GitHub computes it at upload) for pinning.

## Pinned toolchain (recorded 2026-07-07)

| thing | pin |
|---|---|
| typst | **0.14.2 exact** (0.15 is breaking and postdates pandoc 3.10) |
| pandoc | **3.10 exact** in CI (sha-verified deb) · `>= 3.9` floor locally |
| hydra (running headers) | **0.6.3**, vendored in `vendor/` with its dependency (oxifmt 1.0.0) |
| fonts | Geist v1.7.2 · Literata 3.103 @ frozen repo · DejaVu 2.37 — [all pins](fonts/README.md) |
| pypdf | `>= 5, < 7` |

## Mechanism notes

- **`-V template=`, not `--template`**: pandoc's default typst template stays in
  charge (it survives pandoc upgrades) and imports `conf` from `house.typ`;
  `--root=/` lets typst resolve the absolute template path, and `brand.typ`
  resolves relative to `house.typ`.
- **Metadata is our job**: replacing `conf` means `set document(title:)` must
  happen in `house.typ`, or the PDF `/Title` silently vanishes (`refs.lua`
  promotes the leading H1 when no front-matter title exists).
- **Reproducible stamps**: `render.sh` sets `SOURCE_DATE_EPOCH` from the report's
  last commit time (0 for uncommitted drafts).
- **Running header**: the current `##` section on pages 2+, muted mono caps —
  a tagged-PDF artifact, so it may never contain links (PDF/UA-1).
- **Brand**: all values live in `brand.typ`, translated from the portfolio's
  design tokens; two deliberate print-specific deviations are documented inline
  there. v0.1.0 spends exactly one accent: link blue.
