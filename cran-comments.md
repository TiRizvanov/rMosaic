# Submission notes — rMosaic 0.1.2

## Changes since 0.1.1

Addressing CRAN reviewer feedback (Benjamin Altmann, 28 May 2026):

* `.GlobalEnv` removed as a default argument from `runMosaicExport()`,
  `runMosaicWithExport()`, and `store_mosaic_selection()`. The global
  environment is now resolved lazily inside the function body via
  `globalenv()`, keeping interactive behaviour identical for users while
  complying with CRAN policy.
* `<<-` replaced in `.mosaic_dot_xy_candidates()` with a recursive
  return-value accumulation pattern (no super-assignment).

## Test environments

* local macOS 15.7.3 (aarch64-apple-darwin20), R 4.5.1 — 0 errors,
  0 warnings, 0 notes (`--as-cran --no-manual`)
* win-builder R-devel (2026-05-27 r90083 ucrt, x86_64-w64-mingw32) — 0
  errors, 0 warnings, 1 NOTE (new submission; addressed)
* R-hub v2 (Linux, macOS, Windows) — all green

# Submission notes — rMosaic 0.1.1

## Test environments

* local macOS 15.7.3 (aarch64-apple-darwin20), R 4.5.1 — 0 errors, 0 warnings,
  0 notes (`--as-cran --no-manual`)
* win-builder R-devel (2026-05-27 r90083 ucrt, x86_64-w64-mingw32) — 0 errors,
  0 warnings, 1 NOTE (CRAN incoming feasibility / New submission; spell-check
  on software names — addressed by quoting in DESCRIPTION; invalid file URI
  to LICENSE.md — fixed in README)
* R-hub v2 (Linux, macOS, Windows) — all green
  https://github.com/TiRizvanov/rMosaic/actions

## R CMD check results

0 errors | 0 warnings | 1 NOTE in the local check.

The NOTE is the standard "CRAN incoming feasibility" — first submission. All
sub-checks (mis-spellings, invalid URI) have been addressed in this version of
the tarball.

## Bundled JavaScript

`inst/htmlwidgets/lib/mosaic-bundle.js` (~1.9 MB) is a pre-built bundle of the
UW IDL Mosaic / vgplot library (v0.21.1) plus its DuckDB-WASM connector and
flechette Arrow reader. The bundle is required because the package renders
Mosaic specifications in an htmlwidget without network access; we ship the
JavaScript with the package so users can produce widgets offline. The bundled
JS is upstream-MIT and is documented in `LICENSE` shipped at package root.
