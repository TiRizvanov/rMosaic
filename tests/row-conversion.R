# Base-R regression tests: source checkout or installed package namespace.
source_dir <- Sys.getenv("RMOSAIC_SOURCE", "")
if (nzchar(source_dir)) {
  implementation <- new.env(parent = asNamespace("rMosaic"))
  sys.source(file.path(source_dir, "R", "mosaic.R"), implementation)
} else {
  implementation <- asNamespace("rMosaic")
}
legacy_rows <- function(df) {
  lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
}
stopifnot("internal row converter exists" =
  exists(".mosaic_rows", implementation, inherits = FALSE))
rows <- get(".mosaic_rows", implementation)
plain <- data.frame(id = c(1L, NA_integer_, 3L),
                    value = c(1.25, NaN, Inf),
                    label = c("a", NA_character_, "z"),
                    flag = c(TRUE, FALSE, NA))
stopifnot(identical(rows(plain), legacy_rows(plain)))
# Deterministic performance contract, not a timing threshold.
local({
  calls <- 0L
  trace("[.data.frame", tracer = function() calls <<- calls + 1L,
        print = FALSE, where = baseenv())
  on.exit(untrace("[.data.frame", where = baseenv()))
  rows(plain)
  stopifnot("plain rows avoid data.frame dispatch" = calls == 0L)
})
cat("PASS: plain rows preserve objects without data.frame dispatch\n")

inline_rows <- function(df) {
  implementation$mosaic(list(plot = list()), backend = "wasm",
                        data_transport = "inline", data = list(tbl = df))$x$input_tables$tbl
}
local({
  calls <- 0L
  trace(".mosaic_rows", tracer = function() calls <<- calls + 1L,
        print = FALSE, where = implementation)
  on.exit(untrace(".mosaic_rows", where = implementation))
  stopifnot(identical(inline_rows(plain), legacy_rows(plain)))
  stopifnot("inline widget uses the row converter" = calls == 1L)
})
cat("PASS: real inline widget uses optimized conversion\n")

local({
  calls <- 0L
  trace(".mosaic_rows", tracer = function() calls <<- calls + 1L,
        print = FALSE, where = implementation)
  on.exit(untrace(".mosaic_rows", where = implementation))
  session <- shiny::MockShinySession$new()
  on.exit(session$close(), add = TRUE)
  messages <- list()
  # Capture only the transport boundary; observers, DuckDB and SQL are real.
  session$sendCustomMessage <- function(type, message) {
    messages[[length(messages) + 1L]] <<- list(type = type, message = message)
  }
  widget <- shiny::withReactiveDomain(session, {
    implementation$mosaic(list(plot = list()), backend = "r")
  })
  uid <- widget$x$widgetId
  con <- session$userData$mosaicConnections[[uid]]
  session$flushReact()
  sqls <- c(
    "SELECT i::INTEGER AS id, i * 0.125 AS value, 'x' AS label, i > 1 AS flag FROM range(3) t(i)",
    "SELECT DATE '2020-01-01' AS day, TIMESTAMP '2020-01-01 12:34:56' AS stamp, NULL::DOUBLE AS missing",
    "SELECT 1::INTEGER AS id WHERE FALSE"
  )
  for (i in seq_along(sqls)) {
    expected <- legacy_rows(DBI::dbGetQuery(con, sqls[[i]]))
    req <- list(type = "query", sql = sqls[[i]], request = paste0("r", i))
    do.call(session$setInputs, setNames(list(req), paste0(uid, "_mosaic_query")))
    observed <- messages[[length(messages)]]
    stopifnot(identical(observed$type, paste0(uid, "_mosaic_response")),
              identical(observed$message, list(request = req$request, data = expected)),
              identical(shiny:::toJSON(observed$message$data), shiny:::toJSON(expected)))
  }
  stopifnot("live query uses the row converter" = calls == length(sqls))
  req <- list(type = "exec", sql = "CREATE TABLE empty_table (id INTEGER)", request = "exec")
  do.call(session$setInputs, setNames(list(req), paste0(uid, "_mosaic_query")))
  stopifnot(identical(messages[[length(messages)]]$message,
                      list(request = "exec", data = list(success = TRUE))),
            calls == length(sqls))
})
cat("PASS: real Shiny/DuckDB query and exec paths\n")

# Exotic columns/frames deliberately retain baseline dispatch and attributes.
fixtures <- list(plain = plain, one_row = plain[1, , drop = FALSE],
                 zero_rows = plain[FALSE, , drop = FALSE],
                 zero_columns = data.frame(row.names = c("a", "b")),
                 empty = data.frame(),
                 factor = data.frame(x = factor(c("b", NA, "a"))),
                 ordered = data.frame(x = ordered(c("b", NA, "a"))),
                 date = data.frame(x = as.Date(c("2020-01-01", NA, "2021-02-03"))),
                 posix = data.frame(x = as.POSIXct(c("2020-01-01", NA, "2021-02-03"), tz = "America/New_York")),
                 matrix = data.frame(x = I(matrix(c(1, NA, 3, 4, 5, 6), nrow = 3))),
                 asis = data.frame(x = I(c("a", NA, "b"))))
fixtures$list <- data.frame(id = 1:3)
fixtures$list$x <- list(list(a = 1, b = c(2, 3)), NULL, list())
fixtures$raw_matrix <- data.frame(id = 1:3)
fixtures$raw_matrix$x <- matrix(1:6, nrow = 3,
                              dimnames = list(c("r1", "r2", "r3"), c("a", "b")))
fixtures$posixlt <- data.frame(id = 1:3)
fixtures$posixlt$x <- as.POSIXlt(fixtures$posix$x)
fixtures$column_attribute <- plain
attr(fixtures$column_attribute$value, "label") <- "custom label"
fixtures$frame_attribute <- plain
attr(fixtures$frame_attribute, "source") <- list(note = "keep me")
fixtures$named_column <- plain
names(fixtures$named_column$value) <- c("one", "two", "three")
fixtures$row_names <- plain
rownames(fixtures$row_names) <- c("custom", "NA", "row")
fixtures$duplicate_names <- plain
names(fixtures$duplicate_names) <- c("x", "x", "", "flag")
fixtures$missing_names <- plain
names(fixtures$missing_names) <- c(NA_character_, "", "z", "flag")
fixtures$raw <- data.frame(id = 1:3)
fixtures$raw$x <- as.raw(c(0, 1, 255))
fixtures$complex <- data.frame(x = c(1+2i, NA_complex_, 0i))
`[.mosaic_test_frame` <- function(x, i, j, ..., drop = FALSE) {
  result <- NextMethod("[")
  attr(result, "subset_marker") <- "custom method ran"
  result
}
fixtures$subclass <- structure(plain, class = c("mosaic_test_frame", "data.frame"))
# Compare errors as well as JSON for values the unchanged serializer rejects.
encode <- function(fun, value) {
  tryCatch(list(json = fun(value)), error = function(e) list(error = conditionMessage(e)))
}
for (name in names(fixtures)) {
  df <- fixtures[[name]]
  original <- df
  expected <- legacy_rows(df)
  actual <- rows(df)
  stopifnot(identical(actual, expected), identical(df, original))
  for (serializer in list(htmlwidgets:::toJSON, shiny:::toJSON)) {
    stopifnot(identical(encode(serializer, actual), encode(serializer, expected)))
  }
  normalized <- df
  normalized[] <- lapply(normalized, function(col) {
    if (is.factor(col)) as.character(col) else col
  })
  expected_inline <- legacy_rows(normalized)
  actual_inline <- inline_rows(df)
  stopifnot(identical(actual_inline, expected_inline),
            identical(encode(htmlwidgets:::toJSON, actual_inline),
                      encode(htmlwidgets:::toJSON, expected_inline)))
}
cat(sprintf("PASS: %d fixtures, exact R objects and widget/Shiny JSON or errors\n",
            length(fixtures)))
