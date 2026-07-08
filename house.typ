// house.typ — the paperkit house template, consumed via pandoc's
// `-V template=` import mechanism: pandoc's DEFAULT typst template stays in
// charge (it survives pandoc upgrades) and imports `conf` from this file.
//
// The signature is deliberately `(doc, ..args)`: pandoc's default template
// calls `conf(<many named variables>, doc)`, and new named variables added by
// future pandoc versions land in the sink instead of erroring.
//
// Register: professional report, not academic apparatus — bare page numbers,
// ruled section headings, restrained color. Every brand value lives in
// brand.typ (the single re-skin point); this file owns layout only.

#import "brand.typ": *
#import "@preview/hydra:0.6.3": hydra

#let conf(doc, ..args) = {
  let a = args.named()
  let title = a.at("title", default: none)
  let subtitle = a.at("subtitle", default: none)
  let date = a.at("date", default: none)
  let lang = a.at("lang", default: "en")
  let region = a.at("region", default: "US")
  let cols = a.at("cols", default: 1)

  // PDF document metadata (/Title). Pandoc's DEFAULT conf does this — replacing
  // it via -V template= makes it OUR job, or the metadata silently vanishes.
  set document(title: title)

  set page(
    paper: "us-letter",
    margin: (x: 1in, y: 1in),
    numbering: "1",                  // bare page number, no "of N" fraction
    fill: surface,
    // Running section header (pages 2+): the current level-2 section — level 2
    // because refs.lua promotes the report's H1 to the title, so `##` sections
    // are the document's structure — in muted mono caps over a hairline.
    // Headers are tagged-PDF artifacts: no links in here (PDF/UA-1 forbids
    // links inside artifacts).
    header: context {
      if here().page() > 1 {
        let sect = hydra(2)
        if sect != none {
          set text(font: font-mono, size: 7pt, weight: 600, fill: muted)
          upper(sect)
          v(-0.45em)
          line(length: 100%, stroke: 0.4pt + rule-light)
        }
      }
    },
  )
  // Geist body; the figure SVGs name DejaVu Sans (matplotlib's bundled default),
  // which stays vendored beside it — typst never FAILS on a missing font, so
  // check_render.py asserts both families ended up embedded.
  set text(font: font-body, size: 9.5pt, lang: lang, region: region, fill: ink)
  set par(justify: false, leading: 0.65em, spacing: 0.95em)

  set heading(numbering: none)
  show heading: set text(font: font-heading, weight: weight-heading)
  // Level 1 — the document title heading: large, with a strong rule beneath.
  show heading.where(level: 1): it => block(above: 0.4em, below: 1.1em)[
    #text(size: 16pt)[#it.body]
    #v(0.4em)
    #line(length: 100%, stroke: 0.7pt + rule-strong)
  ]
  // Level 2 — sections: ruled hairline gives the report its visible structure.
  show heading.where(level: 2): it => block(above: 1.8em, below: 0.8em)[
    #text(size: 12.5pt)[#it.body]
    #v(0.3em)
    #line(length: 100%, stroke: 0.4pt + rule-light)
  ]
  show heading.where(level: 3): set text(size: 10.5pt)
  show heading.where(level: 3): set block(above: 1.5em, below: 0.6em)

  show link: set text(fill: accent)
  show raw: set text(font: font-mono)
  // Block code on the quiet surface — square corners, no border (retro-restrained).
  show raw.where(block: true): it => block(
    width: 100%,
    fill: surface-quiet,
    inset: 8pt,
    it,
  )
  // Milestone tables are wide (program map, economics) — shrink to fit.
  show table: set text(size: 8pt)
  show figure: set block(breakable: true)
  show figure.caption: set text(size: 8.5pt, fill: muted)
  // Numbered figures ("Figure 1: …") — images only; caption-less tables stay clean.
  show figure.where(kind: image): set figure(numbering: "1")

  // The title renders as a REAL level-1 heading (styled by the rule above), so
  // the PDF outline and heading hierarchy include it — refs.lua promotes a
  // report's leading H1 into this path when no front-matter title exists.
  if title != none {
    heading(level: 1, title)
    if subtitle != none or date != none {
      block(above: 0.6em, below: 1.2em)[
        #if subtitle != none [ #text(size: 11.5pt, fill: muted)[#subtitle] ]
        #if subtitle != none and date != none [ #text(fill: muted)[ · ] ]
        #if date != none [ #text(size: 9.5pt, fill: muted)[#date] ]
      ]
    }
  }

  if cols == 1 { doc } else { columns(cols, doc) }
}
