from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOUSE = ROOT / "house.typ"


class HouseStyleTests(unittest.TestCase):
    def test_level_two_heading_hangs_a_marginal_section_number(self):
        source = HOUSE.read_text()
        match = re.search(
            r"show heading\.where\(level: 2\): it => (?P<rule>.*?)\n  show heading\.where\(level: 3\)",
            source,
            re.DOTALL,
        )

        self.assertIsNotNone(match, "missing the level-two heading show rule")
        rule = match.group("rule")
        for contract in (
            "block(above: 1.25em, below: 0.5em, sticky: true,",
            "section-counter.step()",
            "h(-28pt)",
            'box(width: 0pt, align(right, accent-label(size: 7.5pt)[#context section-counter.display("01")]))',
            "h(28pt)",
            "size: 12.5pt",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, rule)
        # the number hangs in the margin, baseline-aligned — not the kicker above
        self.assertNotIn("v(0.2em, weak: true)", rule)

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
        self.assertIn("stroke: (top: hairline-stroke)", abstract)
        self.assertNotIn("stroke: hairline-stroke,", abstract)

    def test_running_header_frames_every_page_with_folio_and_fallback(self):
        source = HOUSE.read_text()
        header = re.search(
            r"header: context \{(?P<rule>.*?)\n    \},\n    footer:",
            source,
            re.DOTALL,
        )

        self.assertIsNotNone(header, "missing the page header context")
        rule = header.group("rule")
        # bounded generic fallback for the running title
        self.assertNotIn("else if title != none", rule)
        self.assertIn('"Research paper"', rule)
        # the frame renders on every page — no first-page suppression
        self.assertNotIn("counter(page).get().first() > 1", rule)
        # blue folio at the right, over a quiet hairline
        self.assertIn('fill: accent, counter(page).display("1")', rule)
        self.assertIn(
            "pdf.artifact(line(length: 100%, stroke: hairline-stroke))", rule
        )

    def test_document_metadata_uses_all_editorial_fields(self):
        source = HOUSE.read_text()
        for contract in ("description:", "keywords:", "date:"):
            self.assertIn(contract, source)

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

    def test_link_rules_preserve_link_elements_for_pdf_annotations(self):
        source = HOUSE.read_text()
        match = re.search(
            r"show link: it => \{(?P<rule>.*?)\n  \}\n  show raw:",
            source,
            re.DOTALL,
        )

        self.assertIsNotNone(match, "missing the link show rule")
        rule = match.group("rule")
        # never rebuild from it.body — that would drop the clickable annotation
        self.assertNotIn("it.body", rule)
        # string-destination links get the accent underline
        self.assertRegex(
            rule,
            r"if type\(it\.dest\) == str \{\s+set text\(fill: accent\)\s+underline\(stroke: 0\.35pt \+ accent, offset: 2pt, it\)",
        )
        self.assertFalse(rule.lstrip().startswith("set text(fill: accent)"))
        # internal (non-string) links pass through unstyled
        self.assertRegex(rule, r"else \{\s+it\s+\}")

    def test_shared_primitives_are_defined_once(self):
        source = HOUSE.read_text()
        # the metadata lookup and the hairline tone/weight each live in one place,
        # not re-implemented at every call site
        self.assertIn("#let first-meta(label, default: none)", source)
        self.assertIn("#let hairline-stroke = 0.5pt + rule-light", source)
        self.assertEqual(source.count("0.5pt + rule-light"), 1)


if __name__ == "__main__":
    unittest.main()
