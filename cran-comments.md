# Submission notes — rMosaic 0.1.1

## Test environments

* local macOS 15 (aarch64-apple-darwin20), R 4.5.1 — 0 errors, 0 warnings, 1 NOTE
* (please re-run on win-builder + R-hub before submission)

## R CMD check results

0 errors | 0 warnings | 1 NOTE (new submission)

  > New submission

  This is the first CRAN submission of rMosaic.

## Bundled JavaScript

`inst/htmlwidgets/lib/mosaic-bundle.js` (~1.9 MB) is a pre-built bundle of the
UW IDL Mosaic / vgplot library (v0.21.1) plus its DuckDB-WASM connector and
flechette Arrow reader. The bundle is required because the package renders
Mosaic specifications in an htmlwidget without network access; we ship the
JavaScript with the package so users can produce widgets offline. The bundled
JS is upstream-MIT and is documented in `LICENSE.md`.

## URLs

The `URL` and `BugReports` fields in DESCRIPTION point to
`https://github.com/TiRizvanov/rMosaic`. The repository will be public before
this submission is sent.
