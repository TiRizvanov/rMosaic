# Run a Mosaic app and export brush/query selections back to R

Runs a Mosaic app and allows exporting selections to R.

## Usage

``` r
runMosaicExport(
  spec,
  specType = "auto",
  data,
  title = NULL,
  width = "100%",
  height = "600px",
  selection_env = NULL
)
```

## Arguments

- spec:

  JSON/YAML (as R list, text, or file) or ESM JS code (text or file).

- specType:

  One of "auto" (default), "json", "yaml", or "esm".

- data:

  Named list of data.frames to register in DuckDB.

- title:

  Optional page title

- width:

  CSS or pixel width (e.g. "100%", "600px", or numeric).

- height:

  CSS or pixel height.

- selection_env:

  where to store extracted selections

## Value

A Shiny application object. When the user imports a selection, the
selected rows are assigned into `selection_env` as `mosaic_sel_<n>`.
