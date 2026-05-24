# Run a Mosaic Shiny App in the RStudio Viewer

Launches a Shiny application displaying the Mosaic visualization.

## Usage

``` r
runMosaicApp(
  spec,
  specType = c("auto", "json", "yaml", "esm"),
  data,
  backend = c("r", "wasm"),
  title = NULL,
  width = "100%",
  height = "600px"
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

- title:

  Optional page title

- width:

  CSS or pixel width (e.g. "100%", "600px", or numeric).

- height:

  CSS or pixel height.

## Value

A Shiny application object.
