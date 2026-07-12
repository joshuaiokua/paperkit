# Editorial research-note design

## Status

Approved for implementation on 2026-07-11.

## Goal

Make Paperkit's default output read as one coherent, compact editorial
research note: scholarly enough to support citations and evidence, accessible
enough to remain a reliable PDF/UA artifact, and visibly Jiokua without
becoming a corporate report or a submission manuscript.

This is a complete system pass over the opening matter, typography, headings,
tables, figures, captions, notes, links, page furniture, metadata, pagination,
and fixture coverage. It preserves the existing Pandoc -> Lua -> Typst
pipeline and the generated preview companion.

## Non-negotiable constraints

- Preserve the deliberate no-visible-byline rule. `Joshua Iokua` remains PDF
  author metadata only.
- Preserve US Letter, one column, ragged-right prose, the near-white paper,
  Literata/Geist/Geist Mono roles, restrained blue accent, and PDF/UA-1 output.
- Preserve the existing evidence-first figure grammar: text-measure alignment,
  direct labels, sparse guides, one semantic accent, grayscale legibility, and
  layered captions.
- Keep ordinary Markdown as the authoring surface. Any new metadata or display
  syntax must be optional and must not break legacy reports.
- Do not add a package manager, Typst package, JavaScript dependency, bundler,
  or production service.

## Editorial register

The target is a polished research note, not a double-spaced manuscript and not
an institutional report. Hierarchy comes from alignment, type role, and
whitespace. Decorative frames, large rules, all caps, color-only meaning, and
dashboard-like panels are excluded.

The current 24pt two-line title remains. The primary body remains Geist at a
compact print size, but primary supporting material must not drop to 9pt. Main
sections remain sentence-case Literata semibold with their two-digit number
hanging in the left margin.

## Page geometry and typography

- Keep 1.25in side margins and the existing top/bottom page geometry.
- Raise body text from 10.5pt to 10.75pt. Preserve ragged-right composition and
  the existing 0.64em leading and 0.88em paragraph separation.
- Set level-two section titles to 12.5pt. Keep the 7.5pt blue hanging number,
  make the heading sticky, and retain substantially more space above than
  below.
- Set level-three headings to 11pt and sticky. Define a restrained explicit
  level-four treatment so deeper content cannot fall back to an unrelated
  Typst default.
- Style the document title through its own labeled heading rule. Define body H1
  separately at 16pt so authored H1 content cannot become a second title.
- Use these supporting sizes: abstract and table 9.75pt, captions 9pt, display
  notes and keywords 8.75pt, footnotes 8.5pt, and bibliography 9.75pt.

## Opening matter

Page one uses a reserved masthead row instead of a free-floating identity
element. An optional document type appears at the left and the linked
`jiokua.dev` identity appears at the right. Both use the mono metadata role.

The opening stack is:

1. masthead row;
2. title;
3. subtitle;
4. date;
5. abstract or summary;
6. keywords;
7. document body.

Add optional `document-type` metadata and use `Research note` in the fixture.
`abstract-title` retains its literal meaning and becomes `Abstract` in the
fixture. Missing `document-type` produces no empty visual space.

The abstract loses its four-sided enclosure. It becomes an open summary area
aligned with the text measure, separated by a neutral top rule and whitespace.
Its label is a blue mono accent; its prose uses readable 9.75pt Geist.

The raw ISO source date remains valid metadata. The visible fixture date is
formatted as `10 July 2026`, avoiding a machine-log appearance while keeping
the source contract simple.

## Metadata transport

Transport `document-type`, keywords, abstract/description, and the authored
date through the existing invisible labeled-metadata mechanism in `refs.lua`.
Populate Typst 0.14.2's supported `document` fields explicitly: `title`, fixed
`author`, `description`, `keywords`, and a parsed `datetime` for `date`. Keep
the existing reproducible export timestamp behavior and PDF/UA output.

Metadata transport must remain optional and safe for reports that provide none
of the new fields. Existing title promotion, running-title fallback, citation,
and sibling-link behavior must remain unchanged.

## Tables

- Keep table captions above and notes/sources below.
- Undo Pandoc's intrinsic centered-table appearance inside table figures so
  tables deliberately align to the left text edge. Do not stretch a small
  table so widely that comparison becomes harder.
- Use 9.75pt table text, left-aligned descriptive cells, right-aligned numeric
  cells, and the existing monospaced numeric role.
- Retain a real header row, remove the header wash, use no vertical grid, and
  rely on the writer's header rule plus neutral hairlines for separation.
- Stop interpreting every Markdown `strong` value as the semantic focal result.
  Use `[value]{.focal-value}` as the explicit optional focal-value hook and keep
  ordinary bold semantically ordinary.
- Use a fenced `table-note` Div immediately after a table for compact note and
  source material. It is left aligned to the table measure and styled below
  the primary table content.

## Figures and captions

- Keep figures at the surrounding text width and make each image plus caption
  an unbreakable pagination unit.
- Use the image attribute `fig-alt="..."` as an optional explicit alt channel so
  the accessible text alternative can differ from the visible figure caption.
  Legacy images without the attribute continue to use Pandoc's behavior.
- Use optional `fig-note="..."` and `fig-source="..."` attributes for the
  quieter caption layers. The visible Markdown caption contains the concise
  lead and explanation.
- Render captions as an editorial hierarchy: blue mono figure label, concise
  lead in ink, explanatory text in muted ink, then quieter `Note.` and
  `Source.` material when present.
- Keep chart title, source, note, and caption as document text rather than
  rasterized image text.
- Preserve the existing SVG, direct-label, uncertainty, invalid-state, and
  grayscale rules in `FIGURE_STYLE.md`.

## Lists, code, footnotes, links, and references

- Define compact list and enumeration indentation/spacing that belongs to the
  body rhythm and remains legible when nested.
- Keep code in Geist Mono, but use a neutral hairline or quiet surface and keep
  code blocks with enough surrounding context at page breaks.
- Define a neutral footnote separator and readable footnote typography. Notes
  must remain supplementary; essential interpretation stays in the body.
- Give external prose links a non-color cue. Internal citation/navigation links
  remain quiet. Long DOI links must wrap without dominating the bibliography.
- Raise bibliography text to 9.75pt, retain hanging indents and APA ordering,
  and keep stable DOI links.
- References remain a numbered top-level section because Paperkit's section
  numbers are navigational and the current paper treats references as part of
  the full reading sequence.

## Running furniture and pagination

- Page one has no running header and keeps its centered page number.
- Later pages retain the short running title at left and muted `jiokua.dev` at
  right, plus the centered page number.
- Require the explicit short `running-title` in the canonical fixture and
  constrain fallback behavior so a long document title cannot collide with
  page content.
- Prevent bare headings and single orphan lines by retaining Typst's default
  widow/orphan control and making every heading sticky.
- Keep image/caption units together; allow long tables to break under a
  separate table-specific rule rather than making all figures breakable.

## Fixture and tests

Extend the canonical research fixture without redesigning its argument. It
must exercise:

- document type and abstract as separate concepts;
- level-three and level-four headings;
- unordered, ordered, and nested lists;
- a block quote;
- a multi-line footnote;
- an external prose link;
- compact table notes and source;
- separate visible figure caption and alt text;
- the existing table, SVG figure, citations, code block, and bibliography.

Add focused tests for every new metadata and styling contract before changing
implementation. Continue to run the preview-script Python tests, browser
companion Node tests, render validation, PDF metadata/accessibility checks,
page-by-page PNG inspection, and the full self-test. Update visual goldens only
after the final render has been inspected and accepted as the intended new
baseline.

## Failure behavior and compatibility

- Missing optional metadata produces no visible placeholder or empty spacing.
- Malformed optional rich display metadata falls back to the ordinary Pandoc
  representation instead of dropping content.
- Old Markdown without new attributes renders successfully and retains its
  previous semantic content.
- Rendering, validation, or rasterization failure leaves the last-good preview
  generation available.
- No change is allowed to weaken PDF/UA tagging, title/author metadata, alt-text
  validation, link validation, embedded-font checks, or release isolation.

## Out of scope

- A visible author block, affiliation, correspondence line, or institutional
  masthead.
- A cover page, contents page, executive-summary dashboard, or key-findings
  cards.
- A serif body conversion, two-column journal layout, or submission-manuscript
  formatting.
- New chart generation inside Paperkit.
- PDF.js, PDF editing, annotations, or changes to the preview companion beyond
  what is needed to display the refreshed fixture.
