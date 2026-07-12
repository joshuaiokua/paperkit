from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
FIGURE = ROOT / "sample" / "figs" / "calibration.svg"
SVG = {"svg": "http://www.w3.org/2000/svg"}


class ResearchFigureTests(unittest.TestCase):
    def test_long_category_label_stays_outside_the_plot(self):
        root = ET.parse(FIGURE).getroot()
        labels = root.findall(".//svg:text", SVG)
        label = next(node for node in labels if node.text == "Underpowered subgroup")
        zero_axis = next(
            node
            for node in root.findall(".//svg:line", SVG)
            if node.attrib.get("x1") == node.attrib.get("x2")
            and node.attrib.get("y1") == "48"
            and node.attrib.get("y2") == "342"
            and node.attrib.get("stroke") == "#1F1F1B"
        )

        label_x = float(label.attrib["x"])
        axis_x = float(zero_axis.attrib["x1"])
        self.assertEqual(label.attrib.get("text-anchor"), "end")
        self.assertGreaterEqual(label_x, 200)
        self.assertGreaterEqual(axis_x - label_x, 20)


if __name__ == "__main__":
    unittest.main()
