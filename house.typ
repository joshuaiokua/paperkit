// house.typ — paperkit's branded research-paper template.
//
// Pandoc's default Typst template stays in charge and imports `conf` from this
// file through `-V template=`. The `(doc, ..args)` signature deliberately
// absorbs future Pandoc variables while this file owns the visible register.

#import "brand.typ": *

#let accent-label(body, size: 7.5pt) = text(
  font: font-mono,
  size: size,
  weight: 600,
  fill: accent,
  body,
)

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
    let value = (label, default: none) => {
      let matches = query(label)
      if matches.len() > 0 { matches.first().value } else { default }
    }
    set document(
      title: title,
      author: "Joshua Iokua",
      description: value(<paperkit-description>),
      keywords: value(<paperkit-keywords>, default: ()),
      date: value(<paperkit-authored-date>, default: none),
    )
  }

  set page(
    paper: "us-letter",
    margin: (x: 1.25in, top: 0.82in, bottom: 0.82in),
    numbering: none,
    fill: surface,
    header-ascent: 52%,
    header: context {
      if counter(page).get().first() > 1 {
        let matches = query(<paperkit-running-title>)
        let running-title = if matches.len() > 0 {
          matches.first().value
        } else if title != none {
          title
        } else {
          "Research paper"
        }
        grid(
          columns: (1fr, auto),
          column-gutter: 12pt,
          text(
            font: font-mono,
            size: 7.25pt,
            weight: 600,
            fill: muted,
            running-title,
          ),
          text(
            font: font-mono,
            size: 7.25pt,
            weight: 600,
            fill: muted,
            brand-site-label,
          ),
        )
      }
    },
    footer: context {
      align(center)[
        #text(font: font-mono, size: 7.5pt, fill: muted)[
          #counter(page).display("1")
        ]
      ]
    },
  )

  set text(
    font: font-body,
    size: 10.75pt,
    lang: lang,
    region: region,
    fill: ink,
  )
  set par(justify: false, leading: 0.64em, spacing: 0.88em)

  set heading(numbering: none)
  show heading: set text(font: font-heading, weight: weight-heading)
  show heading.where(level: 1, outlined: true): it => block(above: 1.7em, below: 0.6em, sticky: true)[
    #text(size: 16pt)[#it.body]
  ]
  show heading.where(level: 2): it => block(above: 1.5em, below: 0.45em, sticky: true)[
    #section-counter.step()
    #grid(
      columns: (0pt, 1fr),
      column-gutter: 0pt,
      align: (right + horizon, left + horizon),
      [#move(dx: -7pt)[
        #accent-label(size: 7.5pt)[#context section-counter.display("01")]
      ]],
      [#text(font: font-heading, size: 12.5pt, weight: weight-heading)[#it.body]],
    )
  ]
  show heading.where(level: 3): it => block(above: 1.3em, below: 0.45em, sticky: true)[
    #text(size: 11pt)[#it.body]
  ]
  show heading.where(level: 4): it => block(above: 1.1em, below: 0.4em, sticky: true)[
    #text(font: font-body, size: 10.75pt, weight: 600)[#it.body]
  ]
  show heading.where(level: 1, outlined: false): it => block(above: 0.5em, below: 0.85em)[
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

  show link: it => {
    set text(fill: accent)
    if type(it.dest) == str {
      underline(stroke: 0.35pt + accent, offset: 2pt, it)
    } else {
      it
    }
  }
  show raw: set text(font: font-mono)
  show raw.where(block: true): it => block(
    width: 100%,
    fill: surface-quiet,
    stroke: 0.5pt + rule-light,
    inset: (x: 9pt, y: 7pt),
    above: 0.6em,
    below: 0.8em,
    it,
  )

  set footnote.entry(
    separator: line(length: 30%, stroke: 0.5pt + rule-light),
    clearance: 0.8em,
    gap: 0.4em,
    indent: 1em,
  )
  show footnote.entry: set text(size: 8.5pt, fill: muted)

  set table(inset: (x: 7pt, y: 5pt), stroke: none)
  show table.cell.where(y: 0): set text(weight: 600, fill: ink)
  show table: it => {
    set text(size: 9.75pt)
    show regex("[0-9]+[.][0-9]+|[0-9]+"): set text(font: font-mono)
    show strong: set text(fill: ink)
    it
  }
  show <paperkit-focal-value>: set text(font: font-mono, weight: 600, fill: accent)
  show <paperkit-table-note>: it => block(above: 0.45em, below: 0.9em)[
    #set text(size: 8.75pt, fill: muted)
    #set par(leading: 0.55em, spacing: 0.35em)
    #it
  ]

  show image: set image(width: 100%)
  show figure.where(kind: image): set figure(numbering: "1", gap: 0.55em)
  show figure.where(kind: image): set figure.caption(position: bottom)
  show figure.where(kind: image): set block(breakable: false)
  show figure.where(kind: table): set block(breakable: true)
  show figure.where(kind: table): it => {
    show align.where(alignment: center): aligned => align(left, aligned.body)
    set figure.caption(position: top)
    it
  }
  show figure.caption: it => align(left, block(width: 100%, above: 0.35em)[
    #set text(size: 9pt, fill: muted)
    #show strong: set text(fill: ink, weight: 600)
    #accent-label[#it.supplement #context it.counter.display(it.numbering)]
    #h(0.45em)
    #it.body
  ])

  set bibliography(title: [References])
  show bibliography: set heading(offset: 1)
  show bibliography: set text(size: 9.75pt)

  // Page one identity is real document content so the site remains clickable.
  context {
    let matches = query(<paperkit-document-type>)
    let document-type = if matches.len() > 0 { matches.first().value } else { none }
    grid(
      columns: (1fr, auto),
      column-gutter: 12pt,
      if document-type != none {
        accent-label(size: 7.75pt)[#document-type]
      },
      link(brand-site-url)[
        #text(font: font-mono, size: 8pt, weight: 600)[#brand-site-label]
      ],
    )
  }

  if title != none {
    [#heading(level: 1, outlined: false, title) <paperkit-title>]
  }
  if subtitle != none {
    block(above: -0.2em, below: 0.7em)[
      #text(size: 11.5pt, fill: muted)[#subtitle]
    ]
  }
  let visible-date = context {
    let matches = query(<paperkit-authored-date>)
    let authored-date = if matches.len() > 0 { matches.first().value } else { none }
    if authored-date != none {
      authored-date.display("[day padding:none] [month repr:long] [year]")
    } else {
      date
    }
  }
  if date != none {
    block(below: 1.2em)[
      #text(font: font-mono, size: 8pt, fill: muted)[#visible-date]
    ]
  }

  if abstract != none {
    block(
      width: 100%,
      breakable: true,
      stroke: (top: 0.5pt + rule-light),
      inset: (top: 9pt),
      above: 0.35em,
      below: 0.7em,
    )[
      #accent-label(size: 7.75pt)[
        #if abstract-title != none { abstract-title } else { [Abstract] }
      ]
      #v(0.45em)
      #set text(size: 9.75pt, fill: ink)
      #set par(leading: 0.6em, spacing: 0.7em)
      #abstract
    ]
  }

  context {
    let matches = query(<paperkit-keywords>)
    if matches.len() > 0 {
      let values = matches.first().value
      block(above: 0.55em, below: 1.35em)[
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

  if cols == 1 { doc } else { columns(cols, doc) }
}
