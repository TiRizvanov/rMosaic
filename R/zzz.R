.onLoad <- function(libname, pkgname) {
  # Optionally, ensure DuckDB can use Arrow (for Arrow returns) by loading the extension
  # DBI::dbExecute(con, "LOAD 'arrow';") when needed (handled per connection in code).
}
