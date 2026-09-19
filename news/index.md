# Changelog

## rMosaic 0.1.3.9003

- Drop the registered Parquet buffer from the DuckDB-WASM filesystem
  once the table is materialised, so the payload is no longer resident
  twice, and register it under a unique name so two widgets sharing a
  table name on one page cannot overwrite each other.
- Report the real cause when a page saved with `selfcontained = TRUE`
  cannot resolve a file-transport payload.
- Scope an auto-created `data_dir` to the Shiny session and remove it
  when the session ends.

## rMosaic 0.1.3.9002

- Ship `data_transport = "file"` payloads as an html dependency
  attachment of the widget, so the relative Arrow/Parquet URL resolves
  in the RStudio Viewer, in Shiny and after
  `htmlwidgets::saveWidget(selfcontained = FALSE)` into any directory,
  not only when the page is served from `data_dir`. `data_dir` now
  defaults to a session temporary directory.
- [`runMosaicApp()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicApp.md),
  [`runMosaicWithExport()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicWithExport.md)
  and
  [`runMosaicExport()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicExport.md)
  accept and forward `con`, which their inherited documentation already
  referred to.
- Document that the `copy_arrows` rung only loads the nanoarrow
  extension and never installs it, that data.frames overwrite an
  existing table of the same name on a supplied connection, and that the
  widget’s query channel executes the page’s SQL on that connection.

## rMosaic 0.1.3.9001

- [`mosaic()`](https://tirizvanov.github.io/rMosaic/reference/mosaic.md)
  gains a `con` argument. With `backend = "r"` a supplied DuckDB DBI
  connection is queried in place instead of copying data into a fresh
  in-memory DuckDB, so tables that already live in a database file are
  never materialised in R; `data` becomes optional and any data.frames
  it holds are still written to that connection. Supplied connections
  are never disconnected; only connections
  [`mosaic()`](https://tirizvanov.github.io/rMosaic/reference/mosaic.md)
  opened itself are closed when the Shiny session ends.
- `data` elements may now be single SQL strings evaluated on `con`. For
  `backend = "r"` they become temporary views; for `backend = "wasm"`
  they are streamed from DuckDB to the browser payload (Arrow IPC via
  the community ‘nanoarrow’ extension, else record-batch streaming
  through ‘arrow’, else Parquet) without
  [`DBI::dbGetQuery()`](https://dbi.r-dbi.org/reference/dbGetQuery.html).
  The widget records the export method per table under `input_exports`,
  and the JavaScript loader accepts Parquet files and inline Arrow IPC
  or Parquet payloads for DuckDB-WASM. The `rMosaic.export_methods`
  option restricts which export methods are tried.

## rMosaic 0.1.3.9000

- Reduce row-conversion overhead for plain data frames in inline WASM
  data and live R-backend query responses. Attributed columns and custom
  data frames retain the existing conversion path and serialization
  behavior.

## rMosaic 0.1.3

CRAN release: 2026-06-25

### Bug Fixes

- `store_mosaic_selection()` no longer falls back to
  [`globalenv()`](https://rdrr.io/r/base/environment.html). Selections
  are now stored in a package-internal environment
  (`.mosaic_sel_store`), which is never `.GlobalEnv`. Two new exported
  helpers — `get_mosaic_selection(name)` and
  [`list_mosaic_selections()`](https://tirizvanov.github.io/rMosaic/reference/list_mosaic_selections.md)
  — allow users to retrieve stored selections.

## rMosaic 0.1.2

### Bug Fixes

- Remove `.GlobalEnv` as a default argument in
  [`runMosaicExport()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicExport.md),
  [`runMosaicWithExport()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicWithExport.md),
  and the internal `store_mosaic_selection()`. The global environment is
  now resolved inside the function body via
  [`globalenv()`](https://rdrr.io/r/base/environment.html), satisfying
  CRAN policy on modifying `.GlobalEnv`.
- Replace `<<-` in `.mosaic_dot_xy_candidates()` with a purely recursive
  approach that accumulates results through return values, avoiding any
  super-assignment operator.

## rMosaic 0.1.1

### Bug Fixes

- Fixed missing imports for Shiny functions (`req`, `observe`,
  `observeEvent`)
- Improved CRAN compliance with proper LICENSE structure
- Added proper `@importFrom` statements for all external functions

### Package Structure

- Formatted code with styler for consistency
- Added pkgdown website configuration
- Created GitHub Actions workflows for CI/CD
- Improved .Rbuildignore to exclude development files

## rMosaic 0.1.0

### Initial Release

- Initial implementation of Mosaic framework for R
- Core visualization functionality via htmlwidgets
- DuckDB integration for scalable data queries
- Support for JSON, YAML, and ESM specifications
- Shiny integration with reactive bindings

### Features

- **Visualization:** Mosaic 0.21.1 declarative framework
- **Data Backend:** R DuckDB or browser WASM DuckDB
- **Formats:** JSON, YAML, and inline ESM module support
- **Shiny:** Interactive linked visualizations
- **Selection Export:** Extract brush selections back to R

### Documentation

- Comprehensive README with examples
- Documented all exported functions
- Helper apps for common use cases
