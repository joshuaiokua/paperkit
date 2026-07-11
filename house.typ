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

  // Author identity is document metadata, never visible paper furniture.
  set document(title: title, author: "Joshua Iokua")

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
    size: 10.5pt,
    lang: lang,
    region: region,
    fill: ink,
  )
  set par(justify: false, leading: 0.64em, spacing: 0.88em)

  set heading(numbering: none)
  show heading: set text(font: font-heading, weight: weight-heading)
  show heading.where(level: 1): it => block(above: 0.5em, below: 0.85em)[
    #text(size: 24pt)[#it.body]
  ]
  show heading.where(level: 2): it => block(above: 1.7em, below: 0.72em)[
    #section-counter.step()
    #grid(
      columns: (28pt, 1fr),
      column-gutter: 8pt,
      [#accent-label(size: 8pt)[#context section-counter.display("01")]],
      [#text(font: font-heading, size: 13pt, weight: weight-heading)[#it.body]],
    )
  ]
  show heading.where(level: 3): it => block(above: 1.35em, below: 0.52em)[
    #text(size: 10.75pt)[#it.body]
  ]

  show link: set text(fill: accent)
  show raw: set text(font: font-mono)
  show raw.where(block: true): it => block(
    width: 100%,
    fill: surface-quiet,
    inset: (x: 9pt, y: 7pt),
    it,
  )

  set table(
    inset: (x: 7pt, y: 5pt),
    stroke: none,
    fill: (_, y) => if y == 0 { accent-mist },
  )
  show table.cell.where(y: 0): it => {
    set text(weight: 600, fill: ink)
    it
  }
  show table: it => {
    set text(size: 9pt)
    show regex("[0-9]+[.][0-9]+|[0-9]+"): set text(font: font-mono)
    show strong: set text(font: font-mono, weight: 600, fill: accent)
    it
  }

  show image: set image(width: 100%)
  show figure: set block(breakable: true)
  show figure.where(kind: image): set figure(numbering: "1", gap: 0.55em)
  show figure.where(kind: table): set figure.caption(position: top)
  show figure.where(kind: image): set figure.caption(position: bottom)
  show figure.caption: it => align(left, block(width: 100%, above: 0.35em)[
      #accent-label[#it.supplement #context it.counter.display(it.numbering)]
      #h(0.45em)
      #text(size: 8.5pt, fill: muted)[#it.body]
    ])

  set bibliography(title: [References])
  show bibliography: set heading(offset: 1)
  show bibliography: set text(size: 9.25pt)

  // Page one identity is real document content so the site remains clickable.
  align(right)[
    #link(brand-site-url)[
      #text(font: font-mono, size: 8pt, weight: 600)[#brand-site-label]
    ]
  ]

  if title != none {
    heading(level: 1, title)
  }
  if subtitle != none {
    block(above: -0.2em, below: 0.7em)[
      #text(size: 11.5pt, fill: muted)[#subtitle]
    ]
  }
  if date != none {
    block(below: 1.2em)[
      #text(font: font-mono, size: 8pt, fill: muted)[#date]
    ]
  }

  if abstract != none {
    block(
      width: 100%,
      breakable: true,
      stroke: 0.5pt + rule-light,
      inset: (x: 11pt, y: 10pt),
      above: 0.3em,
      below: 0.65em,
    )[
      #accent-label(size: 7.75pt)[
        #if abstract-title != none { abstract-title } else { [Abstract] }
      ]
      #v(0.45em)
      #set text(size: 9.25pt, fill: ink)
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
            .map(keyword => text(size: 8.25pt, fill: muted, keyword))
            .join([ · ])
        )
      ]
    }
  }

  if cols == 1 { doc } else { columns(cols, doc) }
}
