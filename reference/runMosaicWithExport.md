# Run a Mosaic Shiny App with selection export

Launches a Shiny application that allows selecting data points and
exporting them to an R environment.

## Usage

``` r
runMosaicWithExport(
  spec,
  specType = c("auto", "json", "yaml", "esm"),
  data,
  title = NULL,
  width = "100%",
  height = "600px",
  selection_env = NULL,
  con = NULL
)
```

## Arguments

- spec:

  JSON/YAML (as R list, text, or file) or ESM JS code (text or file).

- specType:

  One of "auto" (default), "json", "yaml", or "esm".

- data:

  Named list of input tables. Each element is a data.frame to register
  in DuckDB or, when \`con\` is supplied, a single SQL string evaluated
  on \`con\`: with \`backend = "r"\` it is exposed as a temporary view
  named after the element; with \`backend = "wasm"\` its result is
  streamed from DuckDB into the browser payload without materialising
  the rows in R. Optional for \`backend = "r"\` when \`con\` already
  holds the tables the spec refers to.

- title:

  Optional page title

- width:

  CSS or pixel width (e.g. "100%", "600px", or numeric).

- height:

  CSS or pixel height.

- selection_env:

  Environment to store selections in

- con:

  Optional \`DBI::DBIConnection\` to a DuckDB database. With \`backend =
  "r"\` the widget queries this connection in place instead of copying
  data into a fresh in-memory DuckDB, so tables that already live in the
  database are never loaded into R; data.frames in \`data\` are still
  written to it with \`overwrite = TRUE\`, replacing an existing table
  of the same name. In a Shiny session the widget's query channel
  executes the SQL the page sends, including \`exec\` statements, on
  this connection, so supply a connection whose contents may change.
  rMosaic never disconnects a supplied connection; only the connections
  it opens itself are closed when the Shiny session ends. With \`backend
  = "wasm"\` the connection is used solely to export the SQL-string
  elements of \`data\`.

## Value

A Shiny application object. When the user imports a selection, the
selected rows are assigned into `selection_env` as `mosaic_sel_<n>`.
