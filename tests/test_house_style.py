from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOUSE = ROOT / "house.typ"


class HouseStyleTests(unittest.TestCase):
    def test_level_two_heading_hangs_the_number_and_aligns_with_body_text(self):
        source = HOUSE.read_text()
        match = re.search(
            r"show heading\.where\(level: 2\): it => (?P<rule>.*?)\n  show heading\.where\(level: 3\)",
            source,
            re.DOTALL,
        )

        self.assertIsNotNone(match, "missing the level-two heading show rule")
        rule = match.group("rule")
        for contract in (
            "block(above: 1.5em, below: 0.45em, sticky: true)",
            "columns: (0pt, 1fr)",
            "column-gutter: 0pt",
            "align: (right + horizon, left + horizon)",
            "move(dx: -7pt)",
            "accent-label(size: 7.5pt)",
            "size: 12.5pt",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, rule)

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

    def test_running_header_has_a_bounded_generic_fallback(self):
        source = HOUSE.read_text()
        header = re.search(
            r"header: context \{(?P<rule>.*?)\n    \},\n    footer:",
            source,
            re.DOTALL,
        )

        self.assertIsNotNone(header, "missing the page header context")
        rule = header.group("rule")
        self.assertNotIn("else if title != none", rule)
        self.assertIn('else {\n          "Research paper"\n        }', rule)

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
        self.assertNotIn("it.body", rule)
        self.assertRegex(
            rule,
            r"if type\(it\.dest\) == str \{\s+set text\(fill: accent\)\s+underline\(stroke: 0\.35pt \+ accent, offset: 2pt, it\)",
        )
        self.assertFalse(rule.lstrip().startswith("set text(fill: accent)"))
        self.assertRegex(rule, r"else \{\s+it\s+\}")


if __name__ == "__main__":
    unittest.main()
