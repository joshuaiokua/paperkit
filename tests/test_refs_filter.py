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

    def test_invalid_calendar_dates_remain_plain_legacy_text(self):
        for date in ("2026-02-30", "2026-13-01", "2025-02-29", "0000-01-01"):
            with self.subTest(date=date):
                typst = render_typst(f"""
                    ---
                    title: Invalid date fixture
                    date: {date}
                    ---

                    ## Body
                """)
                self.assertNotIn("<paperkit-authored-date>", typst)
                self.assertIn(date, typst)

        leap_day = render_typst("""
            ---
            title: Leap day fixture
            date: 2024-02-29
            ---

            ## Body
        """)
        self.assertIn(
            '#metadata(datetime(year: 2024, month: 2, day: 29)) <paperkit-authored-date>',
            leap_day,
        )

    def test_long_title_uses_a_bounded_running_header_fallback(self):
        typst = render_typst("""
            ---
            title: A deliberately overlong document title that cannot safely fit within one line of fixed running-header furniture
            ---

            ## Body
        """)
        self.assertIn(
            '#metadata("Research paper") <paperkit-running-title>',
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

    def test_preserves_authored_focal_value_anchor(self):
        typst = render_typst("""
            [0.084]{#milestone .focal-value}
        """)
        self.assertIn('<milestone>', typst)
        self.assertIn('<paperkit-focal-value>', typst)

    def test_preserves_authored_table_note_anchor(self):
        typst = render_typst("""
            ::: {#method-note .table-note}
            **Note.** Lower is better.
            :::
        """)
        self.assertIn('<method-note>', typst)
        self.assertIn('<paperkit-table-note>', typst)
