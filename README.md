# paperkit

Markdown in, personally branded research paper out. Paperkit is a pinned
Pandoc + Typst pipeline for producing accessible, journal-like PDFs with a
quiet Jiokua visual register.

- **Markdown is content; Typst is presentation.** Papers remain readable in
  source control and reproducible in CI.
- **Accessible by construction.** Every PDF is exported as PDF/UA-1, and the
  self-test verifies tagging, figure alt text, metadata, links, and real font
  programs.
- **Branded without a visible byline.** The first page carries a single
  clickable `jiokua.dev` identity line. Later pages use an unlinked running
  title and site label. `Joshua Iokua` remains in PDF author metadata only.
- **Figures stay evidence-owned.** Producer repositories generate
  presentation-ready SVGs from their own data and lockfiles. Paperkit places,
  numbers, captions, and validates them; it does not reproduce analyses.
- **Everything is pinned.** Typst, Pandoc in CI, fonts, workflow assets, and
  consumer releases are exact-version or checksum pinned.

## The paper register

The default output is US Letter, one column, near-white paper, and about 1.25in
side margins. Body copy is ragged-right 10.5pt Geist; titles and headings use
Literata; metadata, measures, section labels, and page furniture use Geist Mono.

The visible hierarchy is intentionally restrained:

- no author, affiliation, correspondence, or report-style ruled chrome;
- blue two-digit labels on top-level sections, with lower headings unnumbered;
- transparent, square-cornered research-note/abstract block with a neutral
  hairline;
- inline keywords;
- readable tables with captions above, no vertical rules, tabular mono values,
  and an accent-mist header row;
- full-measure figures with left-aligned captions below;
- page-number-only footer.

See [FIGURE_STYLE.md](FIGURE_STYLE.md) for the graph grammar and producer
handoff contract.

## What's in the box

| file | role |
|---|---|
| `house.typ` | page, title, section, table, figure, bibliography, and running-furniture layout |
| `brand.typ` | colors, type families, weights, and fixed brand identity |
| `refs.lua` | title promotion, running-title/keyword transport, manual `[N]` compatibility, sibling-Markdown unlinking |
| `render.sh <md> [out.pdf]` | Pandoc 3.10 -> Typst 0.14.2 -> PDF/UA-1 |
| `check_render.py <pdf>` | structural guard for pages, text, metadata, links, tags, alt text, and embedded fonts |
| `FIGURE_STYLE.md` | producer-side chart and figure specification |
| `sample/research-paper.md` | multi-page research-paper stress specimen using native citations |
| `sample/goldens/` | committed 144-PPI visual baselines and SHA-256 manifest |
| `sample/selftest.sh` | the single integration contract used locally, in CI, and before release |
| `bootstrap.sh` | checksum-pinned Typst installer and local toolchain check |
| `fonts/` | vendored typefaces and licenses |
| `templates/` | consumer render and release workflows |

`vendor/` retains the previously vendored Typst package snapshot, but the v0.2
house template has no external package dependency.

## Write a paper

Use ordinary Pandoc Markdown with research metadata:

```yaml
---
title: Intermittent Evaluation Preserves Calibration
subtitle: A field note on evidence quality and review cadence
running-title: Retention under intermittent constraint
document-type: Research note
date: 2026-07-10
abstract-title: Abstract
abstract: |
  A concise statement of the question, method, result, and boundary.
keywords:
  - research operations
  - calibration
bibliography: references.bib
csl: apa
---
```

Use native citation keys in prose:

```markdown
Pre-registration separates planned analysis from outcome-contingent choices
[@nosek2018].
```

Pandoc leaves the citation native in Typst and Typst formats the bibliography
using the requested built-in style or CSL file. Do not add a Markdown
`## References` heading for a native bibliography; Typst emits the branded
`References` section. Legacy `[N]` markers and bullet-list references remain
supported for existing documents, but they are compatibility behavior, not the
new-paper default.

Use explicit editorial attributes when a table or figure needs richer semantics:

- `[value]{.focal-value}` marks one analytically focal table value.
- `::: {.table-note}` groups a table's Note and Source paragraphs.
- `fig-alt`, `fig-note`, and `fig-source` separate accessible image text from
  the visible caption layers.

Render and validate:

```sh
./bootstrap.sh
./render.sh path/to/paper.md
python3 check_render.py path/to/paper.pdf \
  --require-title "Paper title" \
  --require-author "Joshua Iokua" \
  --require-uri-once "https://jiokua.dev" \
  --require-font Geist \
  --require-font Literata
```

`check_render.py` needs `pypdf>=5,<7`. Explicit `--require-font` values replace
the default Geist + Literata requirement. Every encountered font must contain a
real embedded font program, and Libertinus is forbidden by default to catch
silent Typst fallback.

For debugging or visual-regression work, keep the normal PDF output and request
the exact standalone Typst source at the same time:

```sh
PAPERKIT_TYPST_OUT=path/to/paper.typ ./render.sh path/to/paper.md
```

Keep the `.typ` artifact beside its source Markdown. Pandoc preserves relative
image, bibliography, and CSL paths in Typst output, so `render.sh` rejects a
`PAPERKIT_TYPST_OUT` destination outside the report directory instead of
producing a misleading artifact with broken resources.

## Verify the kit

Run the same end-to-end contract as CI:

```sh
./sample/selftest.sh
```

It verifies vendored font checksums, renders the legacy compatibility sample,
renders the research specimen, inspects PDF metadata and structure, asserts the
running-header/link contract, compiles the standalone Typst source to three PNG
pages at 144 PPI, and compares them against `sample/goldens/MANIFEST.sha256`.
Visual changes therefore require an intentional render, page-by-page review,
and golden update.

## Consumer install

Copy `templates/render.yml` and `templates/release.yml` into the consumer
repository. Keep the current release pin and digest together:

```yaml
env:
  PAPERKIT_REF: v0.1.1
  PAPERKIT_SHA256: "57a84b4c09edb3ec4e402c4afca0952096619cf6b79b7f118619e00948093e4a"
```

Do not point consumers at the feature branch. After the immutable v0.2.0 release
is published, replace both values with the released tag and asset digest in one
reviewed change.

## Versioning and release

Tags and release assets are immutable. Fixes ship as a new tag; consumers move
only by updating their exact tag and SHA-256 pin. The release workflow re-runs
the complete self-test before packaging the repository and prints GitHub's asset
digest for consumers.

This branch prepares the v0.2.0 research-paper default. It does not publish the
tag or update consumer pins.

## Pinned toolchain

| thing | pin |
|---|---|
| Typst | **0.14.2 exact** |
| Pandoc | **3.10 exact** in CI; `>=3.9` floor locally |
| fonts | Geist 1.7.2; Literata 3.103; DejaVu 2.37 |
| pypdf | `>=5,<7` |

Pandoc's default Typst template remains in charge. `-V template=house.typ`
imports only Paperkit's `conf`, so upstream template improvements are not forked.
The Lua filter transports metadata that Pandoc's fixed argument list cannot
forward safely by inserting invisible labeled Typst metadata in document
content.
