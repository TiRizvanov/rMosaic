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
  data_transport = c("auto", "file", "inline"),
  data_dir = NULL,
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

- data_transport:

  How \`backend = "wasm"\` input tables are delivered to the browser.
  \`"auto"\` uses \`"file"\` when \`data_dir\` is supplied and otherwise
  falls back to \`"inline"\` for portable widgets; \`"inline"\` keeps
  the row-JSON path; \`"file"\` writes Arrow IPC files to \`data_dir\`
  and registers them in DuckDB-WASM by URL.

- data_dir:

  Directory for \`"file"\` transport. Serve or save the widget from the
  same directory so relative URLs resolve.

- width:

  CSS or pixel width (e.g. "100%", "600px", or numeric).

- height:

  CSS or pixel height.

## Value

An htmlwidget that renders the Mosaic visualization.
