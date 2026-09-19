# Writes one DuckDB-WASM widget per SQL export method into the directory given
# as the first argument. wasm-payloads.cjs loads them in a real browser.
# Usage: Rscript tests/browser/export-widgets.R /absolute/output-dir
# Set RMOSAIC_SOURCE to a source checkout to test it instead of the installed
# package.
args <- commandArgs(trailingOnly = TRUE)
stopifnot("Pass the output directory" = length(args) == 1L)
out <- args[[1]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
out <- normalizePath(out)

source_dir <- Sys.getenv("RMOSAIC_SOURCE", "")
if (nzchar(source_dir)) {
  pkgload::load_all(source_dir, quiet = TRUE)
} else {
  library(rMosaic)
}

rows <- 200L
db_path <- file.path(out, "points.duckdb")
unlink(db_path)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
DBI::dbExecute(con, sprintf(paste(
  "CREATE TABLE points AS",
  "SELECT i::INTEGER AS id, sin(i / 7.0)::DOUBLE AS x, cos(i / 11.0)::DOUBLE AS y",
  "FROM range(%d) t(i)"
), rows))

spec <- list(
  plot = list(
    list(mark = "dot", data = list(from = "points"), x = "x", y = "y", fill = "steelblue")
  ),
  width = 480,
  height = 320
)

extension_available <- tryCatch(
  {
    DBI::dbExecute(con, "INSTALL nanoarrow FROM community; LOAD nanoarrow;")
    TRUE
  },
  error = function(e) {
    message("copy_arrows skipped: ", conditionMessage(e))
    FALSE
  }
)

cases <- list(
  list(file = "arrows-copy.html", methods = "copy_arrows", transport = "file"),
  list(file = "arrows-stream.html", methods = "record_batch", transport = "file"),
  list(file = "parquet.html", methods = "copy_parquet", transport = "file"),
  list(file = "inline-arrow.html", methods = "record_batch", transport = "inline"),
  list(file = "inline-parquet.html", methods = "copy_parquet", transport = "inline")
)
if (!extension_available) {
  cases <- Filter(function(case) !identical(case$methods, "copy_arrows"), cases)
}

# The browser payload must never come from a materialised data.frame.
guard <- function(...) stop("dbGetQuery must not run for browser payloads", call. = FALSE)
real_get_query <- DBI::dbGetQuery
unlockBinding("dbGetQuery", asNamespace("DBI"))
assign("dbGetQuery", guard, envir = asNamespace("DBI"))

manifest <- lapply(cases, function(case) {
  options(rMosaic.export_methods = case$methods)
  widget <- mosaic(
    spec,
    con = con,
    backend = "wasm",
    data_transport = case$transport,
    data_dir = if (identical(case$transport, "file")) out else NULL,
    data = list(points = "SELECT id, x, y FROM points")
  )
  export <- widget$x$input_exports$points
  stopifnot(identical(export$method, case$methods))
  htmlwidgets::saveWidget(
    widget, file.path(out, case$file), selfcontained = FALSE, libdir = "lib"
  )
  list(
    file = case$file,
    method = export$method,
    format = export$format,
    transport = case$transport,
    payload_file = export$file
  )
})

assign("dbGetQuery", real_get_query, envir = asNamespace("DBI"))
DBI::dbDisconnect(con, shutdown = TRUE)
jsonlite::write_json(
  list(rows = rows, widgets = manifest),
  file.path(out, "expected.json"),
  auto_unbox = TRUE, pretty = TRUE, null = "null"
)
cat(sprintf("Wrote %d widgets to %s\n", length(manifest), out))
