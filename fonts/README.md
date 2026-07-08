# Vendored fonts

All faces are committed in-repo so renders are hermetic (`--ignore-system-fonts` +
`--font-path=fonts`; typst searches this directory recursively). Verify integrity with
`shasum -a 256 -c MANIFEST.sha256` from this directory. Each family keeps its own
license file beside its TTFs.

| family | files | role | source (pinned) | license |
|---|---|---|---|---|
| Geist | Regular · Italic · Bold · BoldItalic | body text | [vercel/geist-font v1.7.2 release zip](https://github.com/vercel/geist-font/releases/tag/v1.7.2), sha256 `7fc800d2ac6b92844895196e5041aca55d814c15db70c44f79b3b83ab82b04e2` (GitHub's published asset digest) | `geist/OFL.txt` (SIL OFL 1.1) |
| Geist Mono | Regular · SemiBold · Bold | code, running-header furniture | same zip | `geist/OFL.txt` (one OFL covers both families) |
| Literata | SemiBold · SemiBoldItalic | headings (600 — see brand.typ for the 650 note) | [googlefonts/literata @ `0c2761b7`](https://github.com/googlefonts/literata/tree/0c2761b727a1b3a7cffd313c37f0f5163dfc7a63/fonts/ttf) — repo archived 2026-04, permanently frozen | `literata/OFL.txt` (SIL OFL 1.1) |
| DejaVu Sans | Regular · Bold · Oblique · BoldOblique | figure SVG text (matplotlib's bundled default names this family) | [dejavu-fonts 2.37 release zip](https://github.com/dejavu-fonts/dejavu-fonts/releases/tag/version_2_37), sha256 `7576310b219e04159d35ff61dd4a4ec4cdba4f35c00e002a136f00e96a908b0a` | `dejavu/LICENSE` (Bitstream Vera / public-domain changes) |

Why DejaVu stays even though no template text uses it: report figures are SVGs whose
`<text>` elements name "DejaVu Sans". typst warns-but-exits-0 on a missing font, so
without this family figure text silently falls back — `check_render.py` asserts the
family is embedded for any figure-bearing document.
