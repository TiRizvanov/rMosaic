# Changelog

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
