# Editorial Research Note Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Paperkit's default PDF into the approved coherent, accessible, branded editorial research note and refresh its canonical visual fixture.

**Architecture:** Keep the current Pandoc -> `refs.lua` -> `house.typ` -> Typst 0.14.2 pipeline. Extend the Lua filter only for metadata and explicit Markdown semantics that Pandoc's stock Typst writer cannot carry, keep all presentation in `house.typ`, extend `check_render.py` for metadata assertions, then exercise the complete surface through the canonical Markdown fixture and its PDF/PNG goldens.

**Tech Stack:** Pandoc 3.10 Lua filters, Typst 0.14.2, Python 3 `unittest`, `pypdf>=5,<7`, Poppler, shell, static HTML/CSS/ES modules for the already-built preview companion.

## Global Constraints

- Preserve the deliberate no-visible-byline rule; `Joshua Iokua` remains PDF author metadata only.
- Preserve US Letter, one column, ragged-right prose, near-white paper, Literata/Geist/Geist Mono roles, restrained blue, and PDF/UA-1.
- Keep ordinary Markdown as the authoring surface; every new metadata field and attribute is optional and legacy-safe.
- Keep figures evidence-owned and text-measure aligned; do not add chart generation to Paperkit.
- Add no package manager, Typst package, JavaScript dependency, bundler, watcher, or production service.
- Keep `render.sh`, the default Pandoc Typst template, pinned tools, and release isolation intact.
- Do not stage or overwrite the existing preview-tool changes except when running their tests.

## File Map

- `refs.lua`: normalize optional metadata and translate explicit Paperkit Markdown attributes into Typst labels/caption layers.
- `house.typ`: own all visible page, type, masthead, heading, table, figure, note, list, link, footnote, and bibliography presentation.
- `check_render.py`: expose and validate PDF subject and keyword metadata in addition to title/author.
- `tests/test_refs_filter.py`: black-box Pandoc/Lua filter tests against generated Typst.
- `tests/test_house_style.py`: focused source-contract tests for the Typst house rules.
- `tests/test_check_render.py`: unit tests for expanded metadata extraction and requirements.
- `sample/research-paper.md`: canonical full-surface research-note fixture.
- `sample/selftest.sh`: end-to-end source, PDF/UA, metadata, alt-text, font, link, page, and visual assertions.
- `README.md`: authoring contract for the new metadata and explicit display semantics.
- `FIGURE_STYLE.md`: caption/alt/note/source authoring contract.
- `sample/goldens/research-paper-*.png` and `sample/goldens/MANIFEST.sha256`: approved 144-PPI visual baseline.

---

### Task 1: Metadata and Explicit Markdown Semantics

**Files:**
- Create: `tests/test_refs_filter.py`
- Modify: `refs.lua`

**Interfaces:**
- Consumes: Pandoc metadata keys `document-type`, `date`, `abstract`, `keywords`; image attributes `fig-alt`, `fig-note`, `fig-source`; classes `focal-value`, `table-note`.
- Produces: Typst labels `<paperkit-document-type>`, `<paperkit-authored-date>`, `<paperkit-description>`, `<paperkit-keywords>`, `<paperkit-focal-value>`, `<paperkit-table-note>` plus rich Figure captions and distinct image alt text.

- [ ] **Step 1: Add a black-box filter test harness and failing contracts**

```python
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]


def render_typst(markdown: str) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "fixture.md"
        source.write_text(textwrap.dedent(markdown))
        result = subprocess.run(
            [
                "pandoc",
                str(source),
                "-f",
                "markdown+autolink_bare_uris",
                "--lua-filter",
                str(ROOT / "refs.lua"),
                "-t",
                "typst",
                "--standalone",
                "-V",
                f"template={ROOT / 'house.typ'}",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout


class RefsFilterTests(unittest.TestCase):
    def test_transports_editorial_metadata(self):
        typst = render_typst("""
            ---
            title: Metadata fixture
            document-type: Research note
            date: 2026-07-10
            abstract: A concise description.
            keywords: [research operations, calibration]
            ---

            ## Body
        """)
        self.assertIn('#metadata("Research note") <paperkit-document-type>', typst)
        self.assertIn(
            '#metadata(datetime(year: 2026, month: 7, day: 10)) <paperkit-authored-date>',
            typst,
        )
        self.assertIn('#metadata("A concise description.") <paperkit-description>', typst)
        self.assertIn(
            '#metadata(("research operations", "calibration")) <paperkit-keywords>',
            typst,
        )

    def test_preserves_caption_but_overrides_image_alt_and_adds_layers(self):
        typst = render_typst("""
            ![**Finding.** Explanation.](plot.svg){fig-alt="Bar chart showing the finding" fig-note="Intervals are 95%." fig-source="Simulation."}
        """)
        self.assertIn('alt: "Bar chart showing the finding"', typst)
        self.assertIn('#strong[Finding.] Explanation.', typst)
        self.assertIn('#strong[Note.] Intervals are 95%.', typst)
        self.assertIn('#strong[Source.] Simulation.', typst)

    def test_maps_explicit_focal_value_and_table_note_classes(self):
        typst = render_typst("""
            | Condition | Value |
            |:--|--:|
            | Milestone | [0.084]{.focal-value} |

            ::: {.table-note}
            **Note.** Lower is better.
            :::
        """)
        self.assertIn('0.084<paperkit-focal-value>', typst)
        self.assertIn('<paperkit-table-note>', typst)
```

- [ ] **Step 2: Run the filter tests and confirm the new contracts fail**

Run: `python3 -m unittest tests.test_refs_filter -v`

Expected: three failures because `document-type`, authored date, description, figure attributes, and semantic class labels are not yet transported.

- [ ] **Step 3: Implement metadata helpers and semantic transforms in `refs.lua`**

Add helpers with these exact contracts:

```lua
local function insert_typst_metadata(doc, expression, label)
  table.insert(doc.blocks, 1, pandoc.RawBlock(
    "typst",
    "#metadata(" .. expression .. ") <" .. label .. ">"
  ))
end

local function meta_text(meta)
  if meta == nil then return nil end
  local value = pandoc.utils.stringify(meta)
  if value == "" then return nil end
  return value
end

local function iso_date_expression(meta)
  local value = meta_text(meta)
  if value == nil then return nil end
  local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if year == nil then return nil end
  return string.format(
    "datetime(year: %d, month: %d, day: %d)",
    tonumber(year), tonumber(month), tonumber(day)
  )
end
```

Within `Pandoc(doc)`, retain title promotion/running-title behavior and add:

```lua
local document_type = meta_text(doc.meta["document-type"])
if document_type ~= nil then
  insert_typst_metadata(doc, typst_string(document_type), "paperkit-document-type")
end

local authored_date = iso_date_expression(doc.meta.date)
if authored_date ~= nil then
  insert_typst_metadata(doc, authored_date, "paperkit-authored-date")
end

local description = meta_text(doc.meta.abstract)
if description ~= nil then
  insert_typst_metadata(doc, typst_string(description), "paperkit-description")
end
```

Keep the existing explicit keyword tuple, but route it through `insert_typst_metadata`. Add these element filters:

```lua
function Span(el)
  if el.classes:includes("focal-value") then
    el.identifier = "paperkit-focal-value"
    el.classes = el.classes:filter(function(class)
      return class ~= "focal-value"
    end)
  end
  return el
end

function Div(el)
  if el.classes:includes("table-note") then
    el.identifier = "paperkit-table-note"
    el.classes = el.classes:filter(function(class)
      return class ~= "table-note"
    end)
  end
  return el
end

function Figure(el)
  local block = el.content[1]
  local image = block and block.content and block.content[1]
  if image == nil or image.t ~= "Image" then return nil end

  local explicit_alt = image.attributes["fig-alt"]
  if explicit_alt ~= nil and explicit_alt ~= "" then
    image.caption = pandoc.Inlines({pandoc.Str(explicit_alt)})
  end

  local caption = el.caption.long[1]
  for _, layer in ipairs({
    {label = "Note.", value = image.attributes["fig-note"]},
    {label = "Source.", value = image.attributes["fig-source"]},
  }) do
    if layer.value ~= nil and layer.value ~= "" and caption ~= nil then
      caption.content:insert(pandoc.LineBreak())
      caption.content:insert(pandoc.Strong({pandoc.Str(layer.label)}))
      caption.content:insert(pandoc.Space())
      caption.content:insert(pandoc.Str(layer.value))
    end
  end

  image.attributes["fig-alt"] = nil
  image.attributes["fig-note"] = nil
  image.attributes["fig-source"] = nil
  return el
end
```

If Pandoc's Lua list type does not provide `filter`, replace only the two class-filter expressions with indexed reconstruction; do not change the public Markdown syntax.

- [ ] **Step 4: Run focused and legacy filter checks**

Run:

```bash
python3 -m unittest tests.test_refs_filter -v
pandoc sample/sample.md -f markdown+autolink_bare_uris --lua-filter=refs.lua -t typst --standalone -V template=house.typ >/dev/null
```

Expected: all filter tests pass and the legacy sample converts without warnings or errors.

- [ ] **Step 5: Commit the metadata/semantics slice**

```bash
git add refs.lua tests/test_refs_filter.py
git commit -m "feat: transport editorial report semantics"
```

---

### Task 2: PDF Metadata Validation

**Files:**
- Modify: `check_render.py`
- Modify: `tests/test_check_render.py`

**Interfaces:**
- Consumes: pypdf metadata keys `/Title`, `/Author`, `/Subject`, `/Keywords`.
- Produces: normalized metadata fields `title`, `author`, `subject`, `keywords`; CLI options `--require-subject`, repeatable `--require-keyword`.

- [ ] **Step 1: Extend the unit tests with subject and keyword requirements**

Change the metadata test to:

```python
def test_document_metadata_normalizes_editorial_fields(self):
    reader = SimpleNamespace(metadata={
        "/Title": "Intermittent Evaluation",
        "/Author": "Joshua Iokua",
        "/Subject": "A concise description.",
        "/Keywords": "research operations, calibration",
    })

    self.assertEqual(check_render.document_metadata(reader), {
        "title": "Intermittent Evaluation",
        "author": "Joshua Iokua",
        "subject": "A concise description.",
        "keywords": ["research operations", "calibration"],
    })
```

Add `require_subject=None` and `require_keyword=[]` to the local requirements factory and add two negative cases:

```python
(
    "wrong subject",
    requirements(require_subject="Expected description"),
    {},
    "PDF subject",
),
(
    "missing keyword",
    requirements(require_keyword=["missing keyword"]),
    {},
    "PDF keyword",
),
```

- [ ] **Step 2: Run the metadata tests and confirm failure**

Run: `python3 -m unittest tests.test_check_render.CheckRenderTests.test_document_metadata_normalizes_editorial_fields tests.test_check_render.CheckRenderTests.test_validation_failures_cover_new_negative_contracts -v`

Expected: failure because subject/keywords and requirement attributes are not implemented.

- [ ] **Step 3: Implement extraction, CLI flags, and validation**

Use this normalization in `document_metadata`:

```python
def document_metadata(reader):
    metadata = reader.metadata or {}
    keywords = [
        value.strip()
        for value in str(metadata.get("/Keywords", "")).split(",")
        if value.strip()
    ]
    return {
        "title": str(metadata.get("/Title", "")),
        "author": str(metadata.get("/Author", "")),
        "subject": str(metadata.get("/Subject", "")),
        "keywords": keywords,
    }
```

Add argparse fields:

```python
parser.add_argument("--require-subject")
parser.add_argument("--require-keyword", action="append", default=[])
```

Add validation alongside title/author checks:

```python
if requirements.require_subject is not None and metadata["subject"] != requirements.require_subject:
    failures.append(
        f"PDF subject {metadata['subject']!r} != {requirements.require_subject!r}"
    )
for keyword in requirements.require_keyword:
    if keyword not in metadata["keywords"]:
        failures.append(f"required PDF keyword missing: {keyword!r}")
```

- [ ] **Step 4: Run the complete validator unit suite**

Run: `python3 -m unittest tests.test_check_render -v`

Expected: all validator tests pass.

- [ ] **Step 5: Commit the validation slice**

```bash
git add check_render.py tests/test_check_render.py
git commit -m "feat: validate editorial PDF metadata"
```

---

### Task 3: Editorial Page System and Opening Matter

**Files:**
- Modify: `house.typ`
- Modify: `tests/test_house_style.py`

**Interfaces:**
- Consumes: the existing conf arguments plus queried metadata labels from Task 1.
- Produces: real PDF document metadata, 10.75pt body, labeled title rule, complete H1-H4 hierarchy, reserved masthead, open abstract, human-formatted authored date.

- [ ] **Step 1: Replace the single heading test with focused failing contracts**

Keep the existing regex helper pattern and add assertions for these exact source contracts:

```python
def test_body_and_heading_scale_is_explicit(self):
    source = HOUSE.read_text()
    for contract in (
        "size: 10.75pt",
        "size: 12.5pt",
        "size: 11pt",
        "show heading.where(level: 4)",
        "heading.where(level: 1, outlined: false)",
        "sticky: true",
    ):
        self.assertIn(contract, source)

def test_opening_matter_has_reserved_masthead_and_open_abstract(self):
    source = HOUSE.read_text()
    self.assertIn("columns: (1fr, auto)", source)
    self.assertIn("paperkit-document-type", source)
    self.assertIn("paperkit-authored-date", source)
    self.assertIn("paperkit-description", source)
    abstract = re.search(
        r"if abstract != none \{(?P<rule>.*?)\n  \}\n\n  context \{",
        source,
        re.DOTALL,
    ).group("rule")
    self.assertIn("stroke: (top: 0.5pt + rule-light)", abstract)
    self.assertNotIn("stroke: 0.5pt + rule-light,", abstract)

def test_document_metadata_uses_all_editorial_fields(self):
    source = HOUSE.read_text()
    for contract in ("description:", "keywords:", "date:"):
        self.assertIn(contract, source)
```

Update the existing H2 contract from `size: 11.5pt` to `size: 12.5pt`.

- [ ] **Step 2: Run the house-style tests and confirm failure**

Run: `python3 -m unittest tests.test_house_style -v`

Expected: failures for body scale, H2-H4, labeled title, masthead metadata, and abstract rule.

- [ ] **Step 3: Implement queried metadata and PDF document fields**

At the start of `conf`, retain existing arguments and set document metadata in
one contextual block:

```typst
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
```

- [ ] **Step 4: Implement the approved type scale and heading hierarchy**

Use these values:

```typst
set text(font: font-body, size: 10.75pt, lang: lang, region: region, fill: ink)
set par(justify: false, leading: 0.64em, spacing: 0.88em)

show heading.where(level: 1, outlined: true): it => block(above: 1.7em, below: 0.6em, sticky: true)[
  #text(size: 16pt)[#it.body]
]
show heading.where(level: 2): it => block(above: 1.5em, below: 0.45em, sticky: true)[
  // Preserve the approved hanging-number grid; set the title to 12.5pt.
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
```

Render the page title as
`heading(level: 1, outlined: false, title) <paperkit-title>` so it stays a real
semantic heading while body H1 uses the 16pt `outlined: true` rule.

- [ ] **Step 5: Implement masthead, date formatting, abstract, and keywords**

Build the masthead as an explicit grid:

```typst
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
```

Format parsed dates with Typst's built-in English long-month formatter while
falling back to the original visible `date` content:

```typst
let visible-date = context {
  let matches = query(<paperkit-authored-date>)
  let authored-date = if matches.len() > 0 { matches.first().value } else { none }
  if authored-date != none {
    authored-date.display("[day padding:none] [month repr:long] [year]")
  } else {
    date
  }
}
```

Replace the abstract enclosure with:

```typst
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
```

Set keyword values to 8.75pt and keep the existing inline label/spacing model.

- [ ] **Step 6: Run source tests and compile both fixtures**

Run:

```bash
python3 -m unittest tests.test_house_style -v
./render.sh sample/sample.md /tmp/paperkit-legacy.pdf
./render.sh sample/research-paper.md /tmp/paperkit-research.pdf
```

Expected: house-style tests pass and both PDFs compile as PDF/UA-1 with no Typst errors.

- [ ] **Step 7: Commit the page-system slice**

```bash
git add house.typ tests/test_house_style.py
git commit -m "feat: unify editorial paper hierarchy"
```

---

### Task 4: Tables, Figures, Notes, and Secondary Content

**Files:**
- Modify: `house.typ`
- Modify: `tests/test_house_style.py`

**Interfaces:**
- Consumes: labels `<paperkit-focal-value>`, `<paperkit-table-note>` and rich caption content from Task 1.
- Produces: left-aligned tables, explicit focal values, layered captions, atomic image figures, styled notes/lists/quotes/code/footnotes, external-link underlines, 9.75pt bibliography.

- [ ] **Step 1: Add failing house contracts for display and secondary elements**

```python
def test_tables_and_figures_use_editorial_semantics(self):
    source = HOUSE.read_text()
    for contract in (
        "show <paperkit-focal-value>",
        "show <paperkit-table-note>",
        "show align.where(alignment: center)",
        "size: 9.75pt",
        "breakable: false",
        "show strong: set text(fill: ink)",
    ):
        self.assertIn(contract, source)
    self.assertNotIn("fill: (_, y) => if y == 0 { accent-mist }", source)

def test_secondary_content_has_house_rules(self):
    source = HOUSE.read_text()
    for contract in (
        "set list(",
        "set enum(",
        "show quote:",
        "set footnote.entry(",
        "show link: it =>",
        "show bibliography: set text(size: 9.75pt)",
    ):
        self.assertIn(contract, source)
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `python3 -m unittest tests.test_house_style -v`

Expected: new display-system and secondary-content tests fail.

- [ ] **Step 3: Implement table alignment, table notes, and focal values**

Use no header wash and retain Pandoc's semantic header rule:

```typst
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
```

Within the table-figure show rule, scope this rewrite to undo only Pandoc's generated `align(center)` wrapper:

```typst
show figure.where(kind: table): it => {
  show align.where(alignment: center): aligned => align(left, aligned.body)
  set figure.caption(position: top)
  it
}
```

- [ ] **Step 4: Implement atomic image figures and layered captions**

```typst
show figure.where(kind: image): set figure(numbering: "1", gap: 0.55em)
show figure.where(kind: image): set figure.caption(position: bottom)
show figure.where(kind: image): set block(breakable: false)
show figure.where(kind: table): set block(breakable: true)
show figure.caption: it => align(left, block(width: 100%, above: 0.35em)[
  #set text(size: 9pt, fill: muted)
  #show strong: set text(fill: ink, weight: 600)
  #accent-label[#it.supplement #context it.counter.display(it.numbering)]
  #h(0.45em)
  #it.body
])
```

Do not retain the current global `show figure: set block(breakable: true)` rule.

- [ ] **Step 5: Implement lists, quote, code, footnotes, links, and bibliography**

```typst
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

show link: it => {
  if type(it.dest) == str {
    underline(stroke: 0.35pt + accent, offset: 2pt)[
      #text(fill: accent)[#it.body]
    ]
  } else {
    text(fill: accent, it.body)
  }
}

show bibliography: set text(size: 9.75pt)
```

- [ ] **Step 6: Run style tests and compile a semantics probe**

Run:

```bash
python3 -m unittest tests.test_house_style -v
python3 -m unittest tests.test_refs_filter -v
./render.sh sample/research-paper.md /tmp/paperkit-display-system.pdf
python3 check_render.py /tmp/paperkit-display-system.pdf --min-pages 3 --require-font Geist --require-font Literata
```

Expected: all focused tests pass and the current research fixture remains structurally valid.

- [ ] **Step 7: Commit the display-system slice**

```bash
git add house.typ tests/test_house_style.py
git commit -m "feat: style editorial evidence elements"
```

---

### Task 5: Canonical Fixture and Authoring Documentation

**Files:**
- Modify: `sample/research-paper.md`
- Modify: `sample/selftest.sh`
- Modify: `README.md`
- Modify: `FIGURE_STYLE.md`

**Interfaces:**
- Consumes: metadata/attribute syntax and house rules from Tasks 1-4.
- Produces: one canonical report that exercises the full supported surface and documented consumer syntax.

- [ ] **Step 1: Update opening metadata and display semantics in the fixture**

Change the YAML fields to:

```yaml
document-type: Research note
abstract-title: Abstract
date: 2026-07-10
```

Change the focal table cell to:

```markdown
| Milestone      | [0.084]{.focal-value} | 2.6       | 12.2           |
```

Wrap table material as:

```markdown
::: {.table-note}
**Note.** Lower calibration error and fewer reversals are better. Hours include
interpretive review but exclude automated collection.

**Source.** Paperkit research-operations simulation, 240 programs.
:::
```

Change the figure to the explicit contract:

```markdown
![**Calibration error by review cadence.** Weekly and milestone review are
directly labeled; the underpowered subgroup remains visible as a hatched state.](figs/calibration.svg){fig-alt="Horizontal bar chart showing lower calibration error for weekly and milestone review than continuous monitoring, with an underpowered subgroup labeled No estimate." fig-note="Error bars show 95% confidence intervals." fig-source="Paperkit research-operations simulation."}
```

- [ ] **Step 2: Extend the fixture without changing its argument**

Add the following compact mechanisms where they support the existing prose:

```markdown
### Registered decision rule

The review protocol fixed three operational constraints:

1. collect observations continuously;
2. interpret them only at declared checkpoints;
3. revise conclusions against the registered rule.

- Invalid programs remain visible.
  - Underpowered subgroups receive an explicit `No estimate` state.
- Uncertainty remains attached to every estimated comparison.

#### Interpretation boundary

> A cadence is useful only when it matches the risk and reversibility of the
> decision it governs.
```

Expand the existing footnote to two sentences and add one descriptive external prose link to `https://www.cos.io/initiatives/prereg` with link text `Center for Open Science preregistration guidance`.

- [ ] **Step 3: Update end-to-end source and PDF assertions**

Add generated-Typst greps for document type, authored date, description, focal value, table note, and explicit alt. Update `check_render.py` invocation with:

```bash
--sentinel "Abstract" \
--sentinel "Registered decision rule" \
--sentinel "Interpretation boundary" \
--forbid-text "Joshua Iokua" \
--require-subject "Teams often increase review frequency when evidence is scarce, assuming that more checkpoints necessarily improve judgment. This paper tests the opposite proposition: a deliberately intermittent review cadence can preserve calibration while reducing coordination cost. Across three simulated research conditions, scheduled evidence reviews retained decision quality and produced fewer reversals than continuous monitoring. The result is not a general case against observation; it is evidence for protecting the moment when observation becomes interpretation." \
--require-keyword "research operations" \
--require-keyword "calibration" \
--require-alt "Horizontal bar chart showing lower calibration error for weekly and milestone review than continuous monitoring" \
```

Keep `--min-pages 3` rather than asserting an exact page count in structural validation. Update the PNG-count assertion only after the final layout count is known in Task 6.

- [ ] **Step 4: Document the authoring contract**

In `README.md`, add `document-type` to the YAML example and document:

```markdown
- `[value]{.focal-value}` marks one analytically focal table value.
- `::: {.table-note}` groups a table's Note and Source paragraphs.
- `fig-alt`, `fig-note`, and `fig-source` separate accessible image text from
  the visible caption layers.
```

In `FIGURE_STYLE.md`, replace the single caption sentence contract with the exact rich-caption example from Step 1 and state that legacy images without attributes remain supported.

- [ ] **Step 5: Run all non-visual tests and render validation**

Run:

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/test_preview_companion.mjs
PAPERKIT_TYPST_OUT=sample/.research-paper.generated.typ ./render.sh sample/research-paper.md /tmp/paperkit-editorial-fixture.pdf
python3 check_render.py /tmp/paperkit-editorial-fixture.pdf --min-pages 3 --require-title "Intermittent Evaluation Preserves Calibration Under Sparse Feedback" --require-author "Joshua Iokua" --require-keyword "research operations" --require-alt "Horizontal bar chart showing lower calibration error for weekly and milestone review than continuous monitoring" --require-font Geist --require-font Literata
```

Expected: all unit/browser tests pass and the fixture PDF passes structural, metadata, alt-text, and font validation.

- [ ] **Step 6: Commit fixture and documentation**

```bash
git add sample/research-paper.md sample/selftest.sh README.md FIGURE_STYLE.md
git commit -m "test: expand editorial research fixture"
```

---

### Task 6: Visual Baseline, Preview Refresh, and Release Verification

**Files:**
- Modify: `sample/goldens/research-paper-*.png`
- Modify: `sample/goldens/MANIFEST.sha256`
- Generated/ignored: `tmp/research-paper-preview/**`

**Interfaces:**
- Consumes: the final source, renderer, fixture, and tests from Tasks 1-5.
- Produces: reviewed 144-PPI PNG goldens, a fully passing self-test, and a live companion showing the same validated PDF bytes.

- [ ] **Step 1: Run the pre-golden verification suite**

Run:

```bash
bash -n sample/preview-research-paper.sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/test_preview_companion.mjs
git diff --check
```

Expected: all source/unit/browser tests pass and the diff has no whitespace errors.

- [ ] **Step 2: Render exact golden candidates at 144 PPI**

Run:

```bash
PAPERKIT_TYPST_OUT=sample/.research-paper.generated.typ ./render.sh sample/research-paper.md /tmp/paperkit-editorial-final.pdf
bin/typst compile sample/.research-paper.generated.typ /tmp/research-paper-{0p}.png --root=/ --font-path=fonts --ignore-system-fonts --ppi=144
pdfinfo /tmp/paperkit-editorial-final.pdf
```

Expected: a tagged US Letter PDF with title, author, subject, keywords, the authored date, and at least three pages; one contiguous PNG per page.

- [ ] **Step 3: Inspect every candidate PNG at original resolution**

Inspect every `/tmp/research-paper-N.png` and reject the generation if any page has clipped text, excessive line length, orphaned headings, detached notes, table/caption misalignment, unreadable chart labels, collisions, broken glyphs, or inconsistent furniture.

Expected visual result:

- page-one masthead, title, date, open abstract, keywords, and first section share one alignment system;
- H2 numbers hang in the margin while 12.5pt titles align with prose;
- tables align left with captions and compact notes;
- figures and layered captions remain text-measure aligned and intact;
- lists, quote, code, footnotes, links, and references share the same hierarchy;
- later-page running furniture remains quiet and collision-free.

- [ ] **Step 4: Publish the reviewed PNGs as goldens and update the manifest**

Copy the contiguous candidate pages into `sample/goldens/`, remove only obsolete `research-paper-N.png` files if the final page count decreased, and regenerate the manifest from inside the golden directory:

```bash
shasum -a 256 research-paper-*.png > MANIFEST.sha256
```

Update `sample/selftest.sh`'s exact PNG-count assertion to the reviewed final page count.

- [ ] **Step 5: Run the complete integration and release-isolation checks**

Run:

```bash
./sample/selftest.sh
./sample/preview-research-paper.sh render
git check-attr export-ignore -- sample/preview-research-paper.sh sample/preview/index.html
git archive --format=tar HEAD | tar -tf - | rg '^sample/(preview-research-paper\.sh|preview/)' && exit 1 || true
```

Expected: self-test passes including visual hashes; preview render publishes a valid manifest; both preview paths report `export-ignore: set`; the archive contains no preview tooling.

- [ ] **Step 6: Verify the live browser companion**

Open or reuse `http://127.0.0.1:8765/`, wait for status `Ready`, and assert:

- displayed short hash equals the new manifest hash;
- page count equals the final PDF page count;
- all page images decode before replacement;
- the exact-PDF link returns the same hash-addressed PDF;
- selecting, copying, clearing, and fragment restoration still work;
- no browser console warnings or errors occur.

Leave page one visible for user review.

- [ ] **Step 7: Commit the reviewed visual baseline**

```bash
git add sample/goldens sample/selftest.sh
git commit -m "test: accept editorial research visuals"
```

---

### Task 7: Final Review and Handoff

**Files:**
- Review: all files changed after design commit `d3d61ef`

**Interfaces:**
- Consumes: all implementation commits and verification evidence.
- Produces: findings-free code review, clean scoped diff, and implementation handoff.

- [ ] **Step 1: Review the cumulative diff against the approved spec**

Run:

```bash
git diff d3d61ef..HEAD --check
git diff --stat d3d61ef..HEAD
git status --short
```

Confirm every specification section maps to code, test, fixture, documentation, or explicit out-of-scope text. Confirm unrelated preview-tool work remains unstaged unless committed in its own prior slice.

- [ ] **Step 2: Run the final verification commands once more**

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/test_preview_companion.mjs
./sample/selftest.sh
./sample/preview-research-paper.sh render
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 3: Report the result**

Hand off the new PDF hash, final page count, files changed, test totals, visual review result, and the live preview URL. Do not publish a release, update consumer pins, or push unless the user separately requests it.
