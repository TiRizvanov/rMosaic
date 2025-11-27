# Render a Mosaic visualization in Shiny

Renders a Mosaic visualization using the provided specification and
data.

## Usage

``` r
mosaic(
  spec,
  specType = c("auto", "json", "yaml", "esm"),
  data = NULL,
  backend = c("r", "wasm"),
  width = NULL,
  height = NULL
)
```

## Arguments

- spec:

  JSON/YAML (as R list, text, or file) or ESM JS code (text or file).

- specType:

  One of "auto" (default), "json", "yaml", or "esm".

- data:

  Named list of data.frames to register in DuckDB.

- backend:

  Database backend: "r" (default) for R DuckDB or "wasm" for browser
  WASM DuckDB.

- width:

  CSS or pixel width (e.g. "100%", "600px", or numeric).

- height:

  CSS or pixel height.

## Value

An htmlwidget that renders the Mosaic visualization.
