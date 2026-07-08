// brand.typ — paperkit's brand tokens: the single re-skin point.
//
// Provenance: jiokua-portfolio packages/ui/src/styles/foundation.css, translated
// for print. Two DELIBERATE print-specific deviations — do not "fix" them back:
//   · page fill is #fffffb (near-white print surface), not the site's warm paper
//     #F5F1E7 — a print-friendliness call.
//   · headings are Literata SemiBold (600) static, not the site h2's 650 — typst
//     0.14 has no variable-font support (a 0.15 feature), so the nearest upstream
//     static cut wins. Exact-650 escape hatch if it ever matters: instance the
//     variable font once (fonttools varLib.instancer 'Literata[opsz,wght].ttf'
//     wght=650) — Literata's OFL declares no Reserved Font Name.
//
// v0.1.0 register (retro-restrained): accent is the ONLY blue on the page and is
// spent on links alone; accent-strong (the retro navy) and the quieter surface
// tokens beyond code blocks are defined for later use, not spent yet.

#let ink           = rgb("#1f1f1b")  // body text
#let muted         = rgb("#585b54")  // subtitle, date, captions, running header
#let faint         = rgb("#666a62")  // reserved
#let accent        = rgb("#0016cc")  // links — the only blue in v0.1.0
#let accent-strong = rgb("#000080")  // retro navy — reserved, unused in v0.1.0
#let accent-quiet  = rgb("#e8e8ff")  // callout fill — reserved (callouts post-v0.1)
#let surface       = rgb("#fffffb")  // page fill (print-specific, see above)
#let surface-quiet = rgb("#eef0ea")  // code-block fill (table stripes later, maybe)
#let rule-light    = rgb("#d6d8d0")  // H2 hairline, running-header rule
#let rule-strong   = rgb("#bcc0b5")  // H1 rule

#let font-heading   = "Literata"    // vendored statics: SemiBold + SemiBold Italic
#let font-body      = "Geist"       // vendored statics: Regular/Italic/Bold/BoldItalic
#let font-mono      = "Geist Mono"  // vendored statics: Regular/SemiBold/Bold
#let weight-heading = 600
