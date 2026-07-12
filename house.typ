// house.typ — paperkit's branded research-paper template.
//
// Pandoc's default Typst template stays in charge and imports `conf` from this
// file through `-V template=`. The `(doc, ..args)` signature deliberately
// absorbs future Pandoc variables while this file owns the visible register.
//
// v0.3.0 register — AMS-informed foundations. The visible brand is unchanged
// (brand.typ tokens, Geist/Literata/Geist Mono roles, jiokua blue); only the
// foundational proportions and rhythm are rebuilt on a more dependable
// typographic baseline: a ~71-character measure, regularized heading rhythm, an
// every-page running frame (running title + blue folio over a hairline;
// jiokua.dev at the foot), hanging marginal section numbers, a bracketed abstract
// band, and booktabs tables. Break quality uses Typst's text.costs (runt) and
// optimized ragged-right line breaking.

#import "brand.typ": *

#let accent-label(body, size: 7.5pt) = text(
  font: font-mono,
  size: size,
  weight: 600,
  fill: accent,
  body,
)

// First value of an injected <paperkit-*> metadata label, or `default` if absent.
// Call inside a `context` (query is contextual).
#let first-meta(label, default: none) = {
  let matches = query(label)
  if matches.len() > 0 { matches.first().value } else { default }
}

// The brand's structural rules. The light hairline is shared by the
// running-header rule, the abstract band, the front-matter divider, the
// code/footnote separators, and the booktabs under-header rule; the heavier
// booktabs frame rule brackets every table top and bottom.
#let hairline-stroke = 0.5pt + rule-light
#let booktabs-stroke = 0.9pt + rule-strong

#let conf(doc, ..args) = {
  let a = args.named()
  let title = a.at("title", default: none)
  let subtitle = a.at("subtitle", default: none)
  let date = a.at("date", default: none)
  let abstract-title = a.at("abstract-title", default: none)
  let abstract = a.at("abstract", default: none)
  let lang = a.at("lang", default: "en")
  let region = a.at("region", default: "US")
  let cols = a.at("cols", default: 1)
  let section-counter = counter("paperkit-section")

  // Author identity and editorial fields are document metadata, never visible
  // paper furniture.
  context {
    set document(
      title: title,
      author: "Joshua Iokua",
      description: first-meta(<paperkit-description>),
      keywords: first-meta(<paperkit-keywords>, default: ()),
      date: first-meta(<paperkit-authored-date>, default: none),
    )
  }

  // Running frame — header (running title | blue folio, over a hairline) and
  // footer (jiokua.dev flush right) on EVERY page. The measure is ~71 characters;
  // the top/bottom margin gives the frame room to breathe.
  set page(
    paper: "us-letter",
    margin: (x: 1.80in, top: 1.0in, bottom: 1.0in),
    numbering: none,
    fill: surface,
    header-ascent: 40%,
    header: context {
      let running-title = first-meta(<paperkit-running-title>, default: "Research paper")
      grid(
        columns: (1fr, auto),
        column-gutter: 12pt,
        text(font: font-mono, size: 7.25pt, weight: 600, fill: muted, running-title),
        text(font: font-mono, size: 7.25pt, weight: 600, fill: accent, counter(page).display("1")),
      )
      v(3pt, weak: true)
      pdf.artifact(line(length: 100%, stroke: hairline-stroke))
    },
    footer: context {
      // jiokua.dev is non-clickable here by necessity: PDF/UA-1 forbids links
      // inside artifacts (headers/footers), and typst enforces it at compile.
      align(right)[
        #text(font: font-mono, size: 7.5pt, weight: 600, fill: accent)[#brand-site-label]
      ]
    },
  )

  // Body — Geist at a book measure. text.costs prevents orphans/widows (on by
  // default at 100%) and discourages single-word last lines (runt); optimized
  // line breaking smooths the ragged-right edge.
  set text(
    font: font-body,
    size: 10.75pt,
    lang: lang,
    region: region,
    fill: ink,
    costs: (orphan: 200%, widow: 200%, runt: 130%, hyphenation: 100%),
  )
  set par(justify: false, leading: 0.64em, spacing: 0.88em, linebreaks: "optimized")

  set heading(numbering: none)
  show heading: set text(font: font-heading, weight: weight-heading)
  show heading.where(level: 1, outlined: true): it => block(above: 1.5em, below: 0.5em, sticky: true)[
    #text(size: 16pt)[#it.body]
  ]
  // Level-two sections carry a hanging marginal index: the accent section number
  // hangs ~28pt out in the left margin, baseline-aligned with the Literata heading.
  // A zero-width right-aligned box between -/+ kerning keeps the heading text at
  // the normal left edge while the number sits outside the content block.
  show heading.where(level: 2): it => {
    section-counter.step()
    block(above: 1.25em, below: 0.5em, sticky: true, {
      h(-28pt)
      box(width: 0pt, align(right, accent-label(size: 7.5pt)[#context section-counter.display("01")]))
      h(28pt)
      text(font: font-heading, size: 12.5pt, weight: weight-heading, it.body)
    })
  }
  show heading.where(level: 3): it => block(above: 1.0em, below: 0.5em, sticky: true)[
    #text(size: 11pt)[#it.body]
  ]
  show heading.where(level: 4): it => block(above: 0.75em, below: 0.5em, sticky: true)[
    #text(font: font-body, size: 10.75pt, weight: 600)[#it.body]
  ]
  show heading.where(level: 1, outlined: false): it => block(above: 0.5em, below: 0.75em)[
    #text(font: font-heading, size: 24pt, weight: weight-heading)[#it.body]
  ]

  set list(indent: 0.25em, body-indent: 0.55em, spacing: 0.35em)
  set enum(indent: 0.25em, body-indent: 0.65em, spacing: 0.35em)

  show quote: it => block(
    inset: (left: 12pt),
    stroke: (left: 1pt + rule-strong),
    above: 0.75em,
    below: 0.75em,
  )[
    #set text(size: 10pt, fill: muted)
    #it
  ]

  // Links: string-destination links (external URLs) get the accent underline;
  // internal cross-reference links pass through unstyled. Re-emitting `it`
  // preserves the clickable annotation for PDF/UA. (The footer jiokua.dev is
  // plain text, not a link — PDF/UA-1 forbids links inside footer artifacts.)
  show link: it => {
    if type(it.dest) == str {
      set text(fill: accent)
      underline(stroke: 0.35pt + accent, offset: 2pt, it)
    } else {
      it
    }
  }
  show raw: set text(font: font-mono)
  show raw.where(block: true): it => block(
    width: 100%,
    fill: surface-quiet,
    stroke: hairline-stroke,
    inset: (x: 9pt, y: 7pt),
    above: 0.5em,
    below: 0.75em,
    it,
  )

  set footnote.entry(
    separator: line(length: 30%, stroke: hairline-stroke),
    clearance: 0.75em,
    gap: 0.4em,
    indent: 1em,
  )
  show footnote.entry: set text(size: 8.5pt, fill: muted)

  // Booktabs tables: top + under-header rules via the stroke closure (pandoc's
  // table.header() makes y==0 the header), bottom rule via the block wrap. No
  // vertical rules; quiet brand-hairline tones.
  set table(
    inset: (x: 7pt, y: 5pt),
    stroke: (_, y) => (
      top: if y == 0 { booktabs-stroke },
      bottom: if y == 0 { hairline-stroke },
    ),
  )
  show table.cell.where(y: 0): set text(weight: 600, fill: ink)
  show table: it => {
    set text(size: 9.75pt)
    show regex("[0-9]+[.][0-9]+|[0-9]+"): set text(font: font-mono)
    show strong: set text(fill: ink)
    block(stroke: (bottom: booktabs-stroke), it)
  }
  show <paperkit-focal-value>: set text(font: font-mono, weight: 600, fill: accent)
  show <paperkit-table-note>: it => block(above: 0.45em, below: 0.9em)[
    #set text(size: 8.75pt, fill: muted)
    #set par(leading: 0.55em, spacing: 0.35em)
    #it
  ]

  show image: set image(width: 100%)
  show figure: set block(above: 1em, below: 1em)
  show figure.where(kind: image): set figure(numbering: "1", gap: 0.5em)
  show figure.where(kind: image): set figure.caption(position: bottom)
  show figure.where(kind: image): set block(breakable: false)
  show figure.where(kind: table): set block(breakable: false)
  show figure.where(kind: table): it => {
    show align.where(alignment: center): aligned => align(left, aligned.body)
    set figure.caption(position: top)
    it
  }
  show figure.caption: it => align(left, block(width: 100%, above: 0.5em)[
    #set text(size: 9pt, fill: muted)
    #show strong: set text(fill: ink, weight: 600)
    #accent-label[#it.supplement #context it.counter.display(it.numbering)]
    #h(0.45em)
    #it.body
  ])

  set bibliography(title: [References])
  show bibliography: set heading(offset: 1)
  show bibliography: set text(size: 9.75pt)

  // Page one identity — the document-type badge. The site link now lives in the
  // running footer (present on every page).
  context {
    let document-type = first-meta(<paperkit-document-type>)
    if document-type != none {
      accent-label(size: 7.75pt)[#document-type]
    }
  }

  if title != none {
    [#heading(level: 1, outlined: false, title) <paperkit-title>]
  }
  if subtitle != none {
    block(above: 0em, below: 0.75em)[
      #text(size: 11.5pt, fill: muted)[#subtitle]
    ]
  }
  let visible-date = context {
    let authored-date = first-meta(<paperkit-authored-date>)
    if authored-date != none {
      authored-date.display("[day padding:none] [month repr:long] [year]")
    } else {
      date
    }
  }
  if date != none {
    block(below: 1.25em)[
      #text(font: font-mono, size: 8pt, fill: muted)[#visible-date]
    ]
  }

  // Abstract + keywords sit in a band bracketed by matching hairlines — a top
  // rule opening the abstract and a bottom divider after the keywords.
  if abstract != none {
    block(
      width: 100%,
      breakable: true,
      stroke: (top: hairline-stroke),
      inset: (top: 9pt),
      above: 0.5em,
      below: 0.75em,
    )[
      #accent-label(size: 7.75pt)[
        #if abstract-title != none { abstract-title } else { [Abstract] }
      ]
      #v(0.5em, weak: true)
      #set text(size: 9.75pt, fill: ink)
      #set par(leading: 0.6em, spacing: 0.7em)
      #abstract
    ]
  }

  context {
    let matches = query(<paperkit-keywords>)
    if matches.len() > 0 {
      let values = matches.first().value
      block(above: 0.5em, below: 0.6em)[
        #accent-label[Keywords]
        #h(0.65em)
        #(
          values
            .map(keyword => text(size: 8.75pt, fill: muted, keyword))
            .join([ · ])
        )
      ]
    }
  }

  block(above: 0.5em, below: 0.9em)[
    #pdf.artifact(line(length: 100%, stroke: hairline-stroke))
  ]

  if cols == 1 { doc } else { columns(cols, doc) }
}
