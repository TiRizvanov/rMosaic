# Changelog

## rMosaic 0.1.3

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
