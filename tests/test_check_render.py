from types import SimpleNamespace
import unittest

import check_render


class Ref:
    def __init__(self, value):
        self.value = value

    def get_object(self):
        return self.value


def type0_font(name: str, *, embedded: bool):
    descriptor = {}
    if embedded:
        descriptor["/FontFile2"] = Ref(b"font program")
    descendant = Ref({
        "/BaseFont": f"/{name}",
        "/FontDescriptor": Ref(descriptor),
    })
    return Ref({
        "/Subtype": "/Type0",
        "/BaseFont": f"/{name}",
        "/DescendantFonts": [descendant],
    })


class CheckRenderTests(unittest.TestCase):
    def test_embedded_fonts_descends_into_type0_font_programs(self):
        reader = SimpleNamespace(pages=[{
            "/Resources": Ref({
                "/Font": Ref({
                    "/F1": type0_font("ABCDEF+Geist-Regular", embedded=True),
                    "/F2": type0_font("GHIJKL+LibertinusSerif", embedded=False),
                }),
            }),
        }])

        fonts = check_render.embedded_fonts(reader)
        self.assertEqual(fonts, {
            "ABCDEF+Geist-Regular": True,
            "GHIJKL+LibertinusSerif": False,
        })

    def test_link_facts_counts_all_links_and_returns_only_external_uris(self):
        reader = SimpleNamespace(pages=[{
            "/Annots": Ref([
                Ref({
                    "/Subtype": "/Link",
                    "/A": Ref({"/S": "/URI", "/URI": "https://jiokua.dev"}),
                }),
                Ref({"/Subtype": "/Link", "/Dest": "section-1"}),
                Ref({"/Subtype": "/Text"}),
            ]),
        }])

        self.assertEqual(
            check_render._link_facts(reader),
            (2, ["https://jiokua.dev"]),
        )

    def test_structure_alt_texts_recurses_and_tagged_pdf_requires_marking(self):
        root = Ref({
            "/MarkInfo": Ref({"/Marked": True}),
            "/StructTreeRoot": Ref({
                "/K": [
                    Ref({"/S": "/P", "/K": []}),
                    Ref({
                        "/S": "/Div",
                        "/K": Ref({
                            "/S": "/Figure",
                            "/Alt": "Calibration error by review cadence",
                        }),
                    }),
                ],
            }),
        })
        reader = SimpleNamespace(trailer={"/Root": root})

        self.assertTrue(check_render.is_tagged_pdf(reader))
        self.assertEqual(
            check_render.structure_alt_texts(reader),
            ["Calibration error by review cadence"],
        )

    def test_document_metadata_normalizes_title_and_author(self):
        reader = SimpleNamespace(metadata={
            "/Title": "Intermittent Evaluation",
            "/Author": "Joshua Iokua",
        })

        self.assertEqual(check_render.document_metadata(reader), {
            "title": "Intermittent Evaluation",
            "author": "Joshua Iokua",
        })

    def test_parse_count_requirement_splits_on_last_equals(self):
        self.assertEqual(
            check_render.parse_count_requirement("effect = evidence=2"),
            ("effect = evidence", 2),
        )
        with self.assertRaisesRegex(ValueError, "TEXT=COUNT"):
            check_render.parse_count_requirement("missing-count")

    def test_validation_failures_cover_new_negative_contracts(self):
        def requirements(**overrides):
            values = {
                "min_pages": 2,
                "sentinel": [],
                "forbid_text": [],
                "sentinel_count": [],
                "require_font": ["Geist", "Literata"],
                "forbid_font": ["Libertinus"],
                "min_links": 0,
                "require_uri_once": [],
                "require_title": None,
                "require_author": None,
                "require_alt": [],
            }
            values.update(overrides)
            return SimpleNamespace(**values)

        facts = {
            "page_count": 3,
            "text": "running running",
            "fonts": {"AAAAAA+Geist-Regular": True, "BBBBBB+Literata": True},
            "link_count": 2,
            "uris": ["https://jiokua.dev"],
            "metadata": {"title": "Paper title", "author": "Joshua Iokua"},
            "tagged": True,
            "alt_texts": ["Calibration chart"],
        }
        cases = [
            (
                "wrong title",
                requirements(require_title="Expected title"),
                {},
                "PDF title",
            ),
            (
                "wrong author",
                requirements(require_author="Expected Author"),
                {},
                "PDF author",
            ),
            (
                "missing tags",
                requirements(),
                {"tagged": False},
                "PDF is not tagged",
            ),
            (
                "missing alt",
                requirements(require_alt=["Missing chart"]),
                {},
                "required structure alt text missing",
            ),
            (
                "duplicate URI",
                requirements(require_uri_once=["https://jiokua.dev"]),
                {"uris": ["https://jiokua.dev", "https://jiokua.dev"]},
                "URI annotations",
            ),
            (
                "forbidden fallback",
                requirements(),
                {"fonts": {**facts["fonts"], "CCCCCC+LibertinusSerif": True}},
                "forbidden font",
            ),
            (
                "wrong text count",
                requirements(sentinel_count=["running=3"]),
                {},
                "text count",
            ),
            (
                "unembedded font",
                requirements(),
                {"fonts": {**facts["fonts"], "DDDDDD+Other": False}},
                "fonts without embedded font programs",
            ),
        ]

        for label, requested, fact_overrides, expected in cases:
            with self.subTest(label=label):
                failures = check_render.validation_failures(
                    requested,
                    **{**facts, **fact_overrides},
                )
                self.assertTrue(
                    any(expected in failure for failure in failures),
                    failures,
                )


if __name__ == "__main__":
    unittest.main()
