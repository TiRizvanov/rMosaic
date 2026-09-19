# Reusing a caller-owned DuckDB connection in place, and streaming SQL sources
# to the browser without materialising their rows in R.

example_spec <- list(
  plot = list(
    list(mark = "dot", data = list(from = "points"), x = "x", y = "y")
  )
)

widget_fields <- c("spec", "specType", "specText", "widgetId", "useWasm", "input_tables")

legacy_rows <- function(df) {
  lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
}

# A file-backed DuckDB holding a 'points' table, released when `code` returns.
with_points_db <- function(code) {
  path <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  on.exit(
    {
      DBI::dbDisconnect(con, shutdown = TRUE)
      unlink(path)
    },
    add = TRUE
  )
  DBI::dbExecute(con, paste(
    "CREATE TABLE points AS",
    "SELECT i::INTEGER AS id, (i * 0.25)::DOUBLE AS x, (i * 0.5)::DOUBLE AS y",
    "FROM range(20) t(i)"
  ))
  code(con)
}

# Real observers, DuckDB and SQL; only the transport boundary is captured.
with_mock_session <- function(code) {
  session <- shiny::MockShinySession$new()
  on.exit(if (!session$isEnded()) session$close(), add = TRUE)
  messages <- list()
  session$sendCustomMessage <- function(type, message) {
    messages[[length(messages) + 1L]] <<- list(type = type, message = message)
  }
  code(session, function() messages)
}

ask_widget <- function(session, uid, sql, request) {
  req <- list(type = "query", sql = sql, request = request)
  do.call(session$setInputs, stats::setNames(list(req), paste0(uid, "_mosaic_query")))
}

count_connects <- function(env = parent.frame()) {
  counter <- new.env()
  counter$n <- 0L
  real_connect <- DBI::dbConnect
  testthat::local_mocked_bindings(
    dbConnect = function(...) {
      counter$n <- counter$n + 1L
      real_connect(...)
    },
    .package = "DBI",
    .env = env
  )
  counter
}

forbid_materialising <- function(env = parent.frame()) {
  refuse <- function(...) {
    stop("rows must not be materialised in R", call. = FALSE)
  }
  testthat::local_mocked_bindings(
    dbGetQuery = refuse,
    dbGetQueryArrow = refuse,
    .package = "DBI",
    .env = env
  )
}

test_that("con must be a DBI connection", {
  expect_error(mosaic(example_spec, con = 42), "DBIConnection")
  expect_error(mosaic(example_spec, con = list(), backend = "wasm"), "DBIConnection")
})

test_that("R backend reuses a supplied connection without opening another", {
  with_points_db(function(con) {
    with_mock_session(function(session, messages) {
      connects <- count_connects()
      widget <- shiny::withReactiveDomain(session, {
        mosaic(example_spec, con = con, backend = "r")
      })
      expect_identical(connects$n, 0L)
      expect_named(widget$x, widget_fields)
      expect_null(widget$x$input_tables)
      expect_false(widget$x$useWasm)

      uid <- widget$x$widgetId
      expect_true(identical(session$userData$mosaicConnections[[uid]], con))
      expect_null(session$userData$mosaicOwnedConnections)

      session$flushReact()
      ask_widget(session, uid, "SELECT count(*)::INTEGER AS n FROM points", "r1")
      expect_identical(
        messages()[[1]]$message,
        list(request = "r1", data = list(list(n = 20L)))
      )
    })
  })
})

test_that("a supplied connection survives widget creation and session end", {
  with_points_db(function(con) {
    with_mock_session(function(session, messages) {
      shiny::withReactiveDomain(session, {
        mosaic(example_spec, con = con, backend = "r")
      })
      expect_true(DBI::dbIsValid(con))
      expect_identical(
        DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM points")$n, 20L
      )
      session$close()
      expect_true(session$isEnded())
      expect_true(DBI::dbIsValid(con))
      expect_identical(
        DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM points")$n, 20L
      )
    })
  })
})

test_that("connections opened by mosaic() are still closed at session end", {
  with_mock_session(function(session, messages) {
    connects <- count_connects()
    widget <- shiny::withReactiveDomain(session, {
      mosaic(
        example_spec,
        backend = "r",
        data = list(points = data.frame(id = 1:3, x = 1:3, y = 3:1))
      )
    })
    expect_identical(connects$n, 1L)
    uid <- widget$x$widgetId
    owned <- session$userData$mosaicOwnedConnections[[uid]]
    expect_true(identical(owned, session$userData$mosaicConnections[[uid]]))
    expect_true(DBI::dbIsValid(owned))
    session$close()
    expect_false(DBI::dbIsValid(owned))
  })
})

test_that("data supplied with con is registered into con", {
  with_points_db(function(con) {
    extra <- data.frame(id = 1:3, label = factor(c("a", "b", "c")))
    widget <- mosaic(
      example_spec,
      con = con,
      backend = "r",
      data = list(extra = extra, subset = "SELECT * FROM points WHERE id < 5;")
    )
    expect_named(widget$x, widget_fields)
    expect_null(widget$x$input_tables)
    expect_true(DBI::dbExistsTable(con, "extra"))
    expect_equal(
      DBI::dbGetQuery(con, "SELECT id, label FROM extra ORDER BY id"),
      data.frame(id = 1:3, label = c("a", "b", "c"))
    )
    expect_identical(
      DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM subset")$n, 5L
    )
    # SQL sources are temporary views: nothing is persisted into the database.
    expect_true(
      "subset" %in% DBI::dbGetQuery(con, "SELECT view_name FROM duckdb_views() WHERE temporary")$view_name
    )
    expect_false(
      "subset" %in% DBI::dbGetQuery(con, "SELECT table_name FROM duckdb_tables()")$table_name
    )
  })
})

test_that("SQL strings without con error clearly", {
  expect_error(
    mosaic(example_spec, data = list(points = "SELECT 1"), backend = "r"),
    "supply 'con'"
  )
  expect_error(
    mosaic(example_spec, data = list(points = "SELECT 1"), backend = "wasm"),
    "supply 'con'"
  )
})

test_that("wasm with con but no SQL sources errors clearly", {
  with_points_db(function(con) {
    expect_error(mosaic(example_spec, con = con, backend = "wasm"), "no SQL string")
    expect_error(
      mosaic(
        example_spec,
        con = con,
        backend = "wasm",
        data = list(points = data.frame(x = 1, y = 2))
      ),
      "no SQL string"
    )
  })
})

test_that("wasm file transport streams a SQL source to one file without dbGetQuery", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    forbid_materialising()
    expect_error(DBI::dbGetQuery(con, "SELECT 1"), "materialised")
    dir <- tempfile("mosaic-export-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)

    widget <- mosaic(
      example_spec,
      con = con,
      backend = "wasm",
      data_transport = "file",
      data_dir = dir,
      data = list(points = "SELECT id, x, y FROM points WHERE id < 10;")
    )
    files <- list.files(dir)
    expect_length(files, 1L)
    expect_named(widget$x, c(widget_fields, "input_exports"))
    expect_null(widget$x$spec$data)

    entry <- widget$x$input_tables$points
    export <- widget$x$input_exports$points
    expect_true(export$method %in% c("copy_arrows", "record_batch", "copy_parquet"))
    expect_identical(export$file, files)
    if (identical(export$format, "parquet")) {
      expect_identical(export$method, "copy_parquet")
      expect_identical(entry, list(`__parquet_url` = files))
      tbl <- arrow::read_parquet(file.path(dir, files))
    } else {
      expect_identical(export$format, "arrows")
      expect_identical(entry, list(`__arrow_url` = files, `__arrow_format` = "stream"))
      tbl <- arrow::read_ipc_stream(file.path(dir, files))
    }
    expect_identical(names(tbl), c("id", "x", "y"))
    expect_identical(nrow(tbl), 10L)
    expect_identical(tbl$id, 0:9)
  })
})

test_that("wasm inline transport carries the exported bytes as base64", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    forbid_materialising()
    widget <- mosaic(
      example_spec,
      con = con,
      backend = "wasm",
      data_transport = "inline",
      data = list(points = "SELECT id FROM points WHERE id >= 15")
    )
    entry <- widget$x$input_tables$points
    export <- widget$x$input_exports$points
    expect_null(export$file)
    if (identical(export$format, "parquet")) {
      expect_named(entry, "__parquet_b64")
      expect_false(grepl("\n", entry$`__parquet_b64`, fixed = TRUE))
      tbl <- arrow::read_parquet(jsonlite::base64_dec(entry$`__parquet_b64`))
    } else {
      expect_type(entry, "character")
      expect_false(grepl("\n", entry, fixed = TRUE))
      tbl <- arrow::read_ipc_stream(jsonlite::base64_dec(entry))
    }
    expect_identical(tbl$id, 15:19)
  })
})

test_that("COPY (FORMAT ARROWS) rung writes a readable Arrow IPC stream", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    tryCatch(
      DBI::dbExecute(con, "INSTALL nanoarrow FROM community; LOAD nanoarrow;"),
      error = function(e) skip(paste("nanoarrow extension unavailable:", conditionMessage(e)))
    )
    forbid_materialising()
    exported <- .mosaic_export_query(
      con, "SELECT * FROM points;", tempfile("rung-"), methods = "copy_arrows"
    )
    on.exit(unlink(exported$path), add = TRUE)
    expect_identical(exported$method, "copy_arrows")
    expect_identical(exported$format, "arrows")
    expect_identical(exported$failures, character())
    expect_match(exported$path, "\\.arrows$")
    tbl <- arrow::read_ipc_stream(exported$path)
    expect_identical(names(tbl), c("id", "x", "y"))
    expect_identical(tbl$id, 0:19)
  })
})

test_that("record-batch rung streams through arrow and releases the result", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    forbid_materialising()
    exported <- .mosaic_export_query(
      con, "SELECT * FROM points", tempfile("rung-"), methods = "record_batch"
    )
    on.exit(unlink(exported$path), add = TRUE)
    expect_identical(exported$method, "record_batch")
    expect_identical(exported$format, "arrows")
    tbl <- arrow::read_ipc_stream(exported$path)
    expect_identical(tbl$id, 0:19)
    # The result set was cleared, so the connection accepts another query.
    expect_equal(DBI::dbExecute(con, "CREATE TEMP TABLE after_stream AS SELECT 1 AS v"), 1)
  })
})

test_that("Parquet rung writes a readable Parquet file", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    forbid_materialising()
    exported <- .mosaic_export_query(
      con, "SELECT * FROM points", tempfile("rung-"), methods = "copy_parquet"
    )
    on.exit(unlink(exported$path), add = TRUE)
    expect_identical(exported$method, "copy_parquet")
    expect_identical(exported$format, "parquet")
    expect_match(exported$path, "\\.parquet$")
    tbl <- arrow::read_parquet(exported$path)
    expect_identical(tbl$id, 0:19)
  })
})

test_that("the export ladder falls through and keeps every failure reason", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    forbid_materialising()
    testthat::local_mocked_bindings(
      .mosaic_export_copy_arrows = function(con, sql, path) stop("no nanoarrow here"),
      .package = "rMosaic"
    )
    exported <- .mosaic_export_query(con, "SELECT * FROM points", tempfile("fall-"))
    on.exit(unlink(exported$path), add = TRUE)
    expect_identical(exported$method, "record_batch")
    expect_identical(exported$failures, c(copy_arrows = "no nanoarrow here"))
    expect_identical(nrow(arrow::read_ipc_stream(exported$path)), 20L)

    testthat::local_mocked_bindings(
      .mosaic_export_record_batch = function(con, sql, path) stop("no arrow here"),
      .package = "rMosaic"
    )
    exported <- .mosaic_export_query(con, "SELECT * FROM points", tempfile("fall-"))
    on.exit(unlink(exported$path), add = TRUE)
    expect_identical(exported$method, "copy_parquet")
    expect_identical(
      exported$failures,
      c(copy_arrows = "no nanoarrow here", record_batch = "no arrow here")
    )

    stem <- tempfile("fall-")
    expect_error(
      .mosaic_export_query(con, "SELECT * FROM missing_table", stem),
      "copy_arrows: no nanoarrow here.*record_batch: no arrow here.*copy_parquet: "
    )
    expect_false(file.exists(paste0(stem, ".parquet")))
  })
})

test_that("options(rMosaic.export_methods) restricts the ladder from mosaic()", {
  skip_if_not_installed("arrow")
  with_points_db(function(con) {
    forbid_materialising()
    old <- options(rMosaic.export_methods = "copy_parquet")
    on.exit(options(old), add = TRUE)
    dir <- tempfile("mosaic-parquet-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)

    widget <- mosaic(
      example_spec,
      con = con,
      backend = "wasm",
      data_dir = dir,
      data = list(points = "SELECT id, x, y FROM points")
    )
    files <- list.files(dir)
    expect_length(files, 1L)
    expect_match(files, "^mosaic_points_[0-9a-f]{8}\\.parquet$")
    expect_identical(widget$x$input_tables$points, list(`__parquet_url` = files))
    expect_identical(
      widget$x$input_exports$points,
      list(method = "copy_parquet", format = "parquet", file = files)
    )
    expect_identical(arrow::read_parquet(file.path(dir, files))$id, 0:19)

    inline <- mosaic(
      example_spec,
      con = con,
      backend = "wasm",
      data_transport = "inline",
      data = list(points = "SELECT id FROM points WHERE id < 3")
    )
    expect_named(inline$x$input_tables$points, "__parquet_b64")
    expect_identical(
      arrow::read_parquet(jsonlite::base64_dec(inline$x$input_tables$points$`__parquet_b64`))$id,
      0:2
    )
    expect_identical(inline$x$input_exports$points$method, "copy_parquet")
  })
})

test_that("con = NULL keeps the existing widget contract", {
  df <- data.frame(id = 1:3, x = c(0.5, 1.5, 2.5), y = c("a", "b", "c"))

  widget <- mosaic(example_spec, data = list(points = df), backend = "r")
  expect_named(widget$x, widget_fields)
  expect_false(widget$x$useWasm)
  expect_null(widget$x$input_tables)
  expect_null(widget$x$spec$data)

  inline <- mosaic(
    example_spec,
    data = list(points = df),
    backend = "wasm",
    data_transport = "inline"
  )
  expect_named(inline$x, widget_fields)
  expect_true(inline$x$useWasm)
  expect_identical(inline$x$input_tables$points, legacy_rows(df))

  expect_error(
    mosaic(example_spec, data = list(points = 1:3), backend = "r"),
    "must be a data.frame"
  )
  expect_error(mosaic(example_spec, data = list(df), backend = "wasm"), "must be named")

  skip_if_not_installed("arrow")
  local({
    dir <- tempfile("legacy-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    filed <- mosaic(example_spec, data = list(points = df), backend = "wasm", data_dir = dir)
    files <- list.files(dir)
    expect_length(files, 1L)
    expect_match(files, "^mosaic_points_[0-9a-f]{8}\\.arrows$")
    expect_named(filed$x, widget_fields)
    expect_identical(
      filed$x$input_tables$points,
      list(`__arrow_url` = files, `__arrow_format` = "stream")
    )
    expect_identical(arrow::read_ipc_stream(file.path(dir, files))$id, 1:3)
  })
})


test_that("a SQL data element must be a single statement", {
  db <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbWriteTable(con, "victim", data.frame(x = 1))
  spec <- list(plot = list(list(mark = "dot", data = list(from = "points"), x = "x", y = "y")))
  expect_error(
    mosaic(spec, con = con, backend = "r", data = list(points = "SELECT 1 AS x, 2 AS y; DROP TABLE victim")),
    "single statement")
  expect_true(DBI::dbExistsTable(con, "victim"))
  expect_error(
    mosaic(spec, con = con, backend = "wasm", data_transport = "file", data_dir = tempfile("mosaic_sql_"),
           data = list(points = "SELECT 1 AS x, 2 AS y; DROP TABLE victim")),
    "single statement")
  expect_true(DBI::dbExistsTable(con, "victim"))
  # A trailing semicolon alone is still accepted.
  widget <- mosaic(spec, con = con, backend = "r", data = list(points = "SELECT 1 AS x, 2 AS y;"))
  expect_s3_class(widget, "htmlwidget")
})

test_that("wasm file transport ships exports as a widget dependency attachment", {
  skip_if_not_installed("arrow")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE points AS SELECT i AS id, i * 1.5 AS x FROM range(1000) t(i)")
  data_dir <- tempfile("rmosaic_attach_"); dir.create(data_dir)
  spec <- list(plot = list(list(mark = "dot", data = list(from = "points"), x = "x", y = "id")))
  w <- mosaic(spec, data = list(points = "SELECT id, x FROM points"), backend = "wasm",
              data_transport = "file", data_dir = data_dir, con = con)
  node <- w$x$input_tables$points
  url <- node$`__arrow_url` %||% node$`__parquet_url`
  expect_true(!is.null(url))

  deps <- Filter(function(d) startsWith(d$name, "mosaic-data-"), w$dependencies)
  expect_length(deps, 1L)
  expect_identical(unname(deps[[1]]$attachment), url)

  out <- tempfile("rmosaic_saved_"); dir.create(out)
  html <- file.path(out, "widget.html")
  htmlwidgets::saveWidget(w, html, selfcontained = FALSE)
  expect_length(list.files(out, pattern = url, recursive = TRUE), 1L)
  expect_false(file.exists(file.path(out, url)))

  viewer <- tempfile("rmosaic_viewer_"); dir.create(viewer)
  htmltools::save_html(htmltools::as.tags(w), file = file.path(viewer, "index.html"), libdir = "lib")
  expect_length(list.files(file.path(viewer, "lib"), pattern = url, recursive = TRUE), 1L)
})

test_that("file transport works without data_dir", {
  skip_if_not_installed("arrow")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE points AS SELECT i AS id FROM range(10) t(i)")
  spec <- list(plot = list(list(mark = "dot", data = list(from = "points"), x = "id", y = "id")))
  w <- mosaic(spec, data = list(points = "SELECT id FROM points"), backend = "wasm",
              data_transport = "file", con = con)
  deps <- Filter(function(d) startsWith(d$name, "mosaic-data-"), w$dependencies)
  expect_length(deps, 1L)
  expect_true(dir.exists(deps[[1]]$src$file))
})

test_that("the wrappers forward con to mosaic()", {
  expect_true("con" %in% names(formals(runMosaicApp)))
  expect_true("con" %in% names(formals(runMosaicWithExport)))
  expect_true("con" %in% names(formals(runMosaicExport)))
})
