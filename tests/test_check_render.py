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
        self.assertEqual(
            check_render.unembedded_font_names(fonts),
            ["GHIJKL+LibertinusSerif"],
        )

    def test_link_targets_returns_only_external_uri_actions(self):
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

        self.assertEqual(check_render.link_targets(reader), ["https://jiokua.dev"])

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


if __name__ == "__main__":
    unittest.main()
