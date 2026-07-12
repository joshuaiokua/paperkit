# Paperkit figure style

This is the producer contract for figures placed in Paperkit research papers.
The repository that owns the data also owns figure generation. Commit the SVG
there, regenerate it from that repository's lockfile, and hand Paperkit a
presentation-ready asset.

## Deliverable

- SVG, transparent background, real text (not outlined glyphs).
- Full text-measure composition; Paperkit scales the image to the paper column.
- No internal chart title. The paper caption owns figure number, title,
  interpretation boundary, note, and source.
- Meaningful Markdown alt text that states the chart type, principal comparison,
  direction, uncertainty encoding, and invalid states.
- No embedded bitmap unless the underlying evidence is inherently raster.

## Color semantics

| role | value | use |
|---|---|---|
| focal | `#0016CC` | one comparison, series, or value that carries the argument |
| ink | `#1F1F1B` | baseline, comparison marks, primary labels |
| muted | `#585B54` | secondary labels, axis description, notes |
| guide | `#D6D8D0` | sparse grid or confidence guides |
| header mist | `#F2F3FB` | tables only; do not use as a chart panel fill |
| paper | transparent | let Paperkit's `#FFFFFB` page show through |

Blue is semantic emphasis, not decoration. Do not assign a new color to every
series. Prefer ink plus direct labels for comparisons.

## Typography

- Geist for descriptive labels and series names.
- Geist Mono for ticks, values, statistics, confidence bounds, and state labels.
- No Literata inside plots; Literata belongs to the paper's editorial hierarchy.
- Keep labels readable at final column width. A label that works only at 100%
  SVG zoom is too small.
- Use consistent numeric precision and a real Unicode minus where supported by
  the approved fallback fonts.

## Axes and guides

- Use sparse guides only where they help compare values.
- Keep the zero line or decision baseline stronger than other guides.
- Do not draw an outer chart box.
- Prefer direct labels. Use a legend only when direct labels would collide or
  materially increase search time; if needed, place it below or to the left.
- Keep ticks in Geist Mono and axis descriptions in Geist.
- Do not truncate a quantitative axis in a way that visually inflates an effect
  unless the caption explicitly explains the analytical reason.

## States and uncertainty

- Show uncertainty with intervals or another analysis-appropriate encoding.
- Put point/value labels clear of intervals; collision is a rendering defect.
- Keep unavailable, invalid, suppressed, or underpowered states in the figure.
- Encode invalid states with neutral texture plus an explicit label such as
  `No estimate`; never rely on color alone and never silently drop the category.

## Evidence-first annotation

- No marketing callouts, decorative arrows, badges, or oversized takeaways.
- Put interpretation in the paper prose and caption, not inside the plotting
  area.
- A chart may identify a threshold, baseline, or registered comparison when
  that mark is part of the analysis.

## Caption contract

Paperkit places the caption below an image and renders the automatic `Figure N`
label in blue Geist Mono. Author the rich caption contract directly in Markdown:

```markdown
![**Calibration error by review cadence.** Weekly and milestone review are
directly labeled; the underpowered subgroup remains visible as a hatched state.](figs/calibration.svg){fig-alt="Horizontal bar chart showing lower calibration error for weekly and milestone review than continuous monitoring, with an underpowered subgroup labeled No estimate." fig-note="Error bars show 95% confidence intervals." fig-source="Paperkit research-operations simulation."}
```

`fig-alt` supplies the accessible image text independently of the visible lead
and explanation. `fig-note` and `fig-source` add the quieter caption layers.
Legacy images without attributes remain supported and continue to use Pandoc's
caption and alt-text behavior.

Table captions appear above tables. Table notes and sources follow the table as
separate paragraphs.

## Producer checklist

- [ ] regenerated from the owning repository's pinned environment;
- [ ] transparent SVG with no internal title or outer box;
- [ ] exact Paperkit palette and type roles;
- [ ] focal blue used once and intentionally;
- [ ] direct labels do not collide with marks or intervals;
- [ ] invalid states use texture and text;
- [ ] meaningful alt text is present in Markdown;
- [ ] caption includes interpretation boundary, note, and source;
- [ ] inspected at final paper width, not only in the plotting tool.
