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
// v0.2.0 register: a branded research paper. Blue carries links, section labels,
// figure labels, and deliberately focal values. Quiet blue-gray is reserved for
// table headers; structural cards stay transparent and use neutral hairlines.

#let ink           = rgb("#1f1f1b")  // body text
#let muted         = rgb("#585b54")  // subtitle, date, captions, running header
#let faint         = rgb("#666a62")  // reserved
#let accent        = rgb("#0016cc")  // links, labels, focal values
#let accent-strong = rgb("#000080")  // reserved retro navy
#let accent-mist   = rgb("#f2f3fb")  // research-table header wash
#let accent-quiet  = rgb("#e8e8ff")  // reserved stronger callout wash
#let surface       = rgb("#fffffb")  // page fill (print-specific, see above)
#let surface-quiet = rgb("#eef0ea")  // code-block fill
#let rule-light    = rgb("#d6d8d0")  // abstract and structural hairlines
#let rule-strong   = rgb("#bcc0b5")  // reserved stronger rule

// Each face is a FALLBACK CHAIN ending in DejaVu (vendored): Geist/Literata are
// Latin-focused, so glyphs they lack (Δ, ≈, math minus …) would otherwise fall
// back to typst's embedded Libertinus SERIF — a silent brand break the pilot
// caught (check_render's embedded-font list showed LibertinusSerif). DejaVu's
// huge coverage keeps stray glyphs sans and matches the figure font.
#let font-heading   = ("Literata", "DejaVu Sans")        // SemiBold + Italic statics
#let font-body      = ("Geist", "DejaVu Sans")           // Regular/Italic/Bold/BoldItalic
#let font-mono      = ("Geist Mono", "DejaVu Sans Mono") // Regular/SemiBold/Bold; DVSM is typst-embedded
#let weight-heading = 600

#let brand-site-label = "jiokua.dev"
#let brand-site-url = "https://jiokua.dev"
