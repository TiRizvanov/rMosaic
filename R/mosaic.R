# R/mosaic.R

#' @importFrom stats setNames
NULL

#' Render a Mosaic visualization in Shiny
#'
#' @description
#' Renders a Mosaic visualization using the provided specification and data.
#'
#' @param spec      JSON/YAML (as R list, text, or file) or ESM JS code (text or file).
#' @param specType  One of "auto" (default), "json", "yaml", or "esm".
#' @param data      Named list of input tables. Each element is a data.frame
#'   to register in DuckDB or, when `con` is supplied, a single SQL string
#'   evaluated on `con`: with `backend = "r"` it is exposed as a temporary
#'   view named after the element; with `backend = "wasm"` its result is
#'   streamed from DuckDB into the browser payload without materialising the
#'   rows in R. Optional for `backend = "r"` when `con` already holds the
#'   tables the spec refers to.
#' @param backend   Database backend: "r" (default) for R DuckDB or "wasm" for browser WASM DuckDB.
#' @param data_transport How `backend = "wasm"` input tables are delivered to
#'   the browser. `"auto"` uses `"file"` when `data_dir` is supplied and
#'   otherwise falls back to `"inline"` for portable widgets; `"inline"` keeps
#'   the row-JSON path; `"file"` writes Arrow IPC files to `data_dir` and
#'   registers them in DuckDB-WASM by URL. SQL-string elements of `data` are
#'   exported as Arrow IPC streams when DuckDB can write them (the community
#'   'nanoarrow' extension, else record-batch streaming through the 'arrow'
#'   package) and otherwise as Parquet files; the widget payload records the
#'   method used per table under `input_exports`. Set
#'   `options(rMosaic.export_methods = ...)` to a subset of
#'   `c("copy_arrows", "record_batch", "copy_parquet")` to restrict the ladder.
#'   The 'nanoarrow' extension is only loaded, never installed: on a connection
#'   where it is absent the `copy_arrows` rung is skipped.
#' @param data_dir  Directory for `"file"` transport; when omitted a session
#'   temporary directory is used. The exported files travel with the widget as
#'   an html dependency attachment, so the RStudio Viewer, Shiny and
#'   `htmlwidgets::saveWidget(selfcontained = FALSE)` all resolve them
#'   (`selfcontained = TRUE` is not supported for file transport).
#' @param width     CSS or pixel width (e.g. "100\%", "600px", or numeric).
#' @param height    CSS or pixel height.
#' @param con       Optional `DBI::DBIConnection` to a DuckDB database. With
#'   `backend = "r"` the widget queries this connection in place instead of
#'   copying data into a fresh in-memory DuckDB, so tables that already live
#'   in the database are never loaded into R; data.frames in `data` are still
#'   written to it with `overwrite = TRUE`, replacing an existing table of the
#'   same name. In a Shiny session the widget's query channel executes the SQL
#'   the page sends, including `exec` statements, on this connection, so supply
#'   a connection whose contents may change. rMosaic never disconnects a
#'   supplied connection; only the connections it opens itself are closed when
#'   the Shiny session ends. With
#'   `backend = "wasm"` the connection is used solely to export the SQL-string
#'   elements of `data`.
#' @return An htmlwidget that renders the Mosaic visualization.
#' @export
mosaic <- function(
    spec,
    specType = c("auto", "json", "yaml", "esm"),
    data = NULL,
    backend = c("r", "wasm"),
    data_transport = c("auto", "file", "inline"),
    data_dir = NULL,
    width = NULL,
    height = NULL,
    con = NULL) {
  specType <- match.arg(specType)
  backend <- match.arg(backend)
  data_transport <- match.arg(data_transport)
  con_supplied <- !is.null(con)
  if (con_supplied && !inherits(con, "DBIConnection")) {
    stop(
      "'con' must be a DBI connection (DBIConnection), got: ", class(con)[1],
      call. = FALSE
    )
  }
  if (identical(data_transport, "auto")) {
    data_transport <- if (!is.null(data_dir)) "file" else "inline"
  }
  if (identical(data_transport, "file")) {
    if (is.null(data_dir)) data_dir <- .mosaic_session_data_dir("rmosaic-data-")
    if (!is.character(data_dir) || length(data_dir) != 1L || !nzchar(data_dir)) {
      stop("'data_dir' must be a single directory path.", call. = FALSE)
    }
    if (!requireNamespace("arrow", quietly = TRUE)) {
      stop("Package 'arrow' is required when data_transport = 'file'.", call. = FALSE)
    }
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  .mosaic_reset_data_files()
  on.exit(.mosaic_reset_data_files(), add = TRUE)

  use_wasm <- backend == "wasm"
  is_spec_file <- is.character(spec) && length(spec) == 1L && file.exists(spec)

  # 1) Determine format
  fmt <- specType
  if (fmt == "auto") {
    if (is.list(spec)) {
      fmt <- "json"
    } else if (is_spec_file) {
      ext <- tolower(tools::file_ext(spec))
      fmt <- if (ext %in% c("js", "mjs")) {
        "esm"
      } else if (ext %in% c("yaml", "yml")) {
        "yaml"
      } else {
        "json"
      }
    } else if (is.character(spec) && grepl("^\\s*-", spec)) {
      fmt <- "yaml"
    } else if (is.character(spec) && grepl("^\\s*\\{", spec)) {
      fmt <- "json"
    } else {
      fmt <- "json"
    }
  }

  spec_list <- NULL
  spec_text <- NULL
  widget_type <- "json"

  # 2) Parse JSON / YAML or capture inline ESM
  if (fmt == "json") {
    if (is.list(spec)) {
      spec_list <- spec
    } else {
      txt <- if (is_spec_file) readLines(spec) else spec
      spec_list <- jsonlite::fromJSON(
        paste(txt, collapse = "\n"),
        simplifyVector = FALSE
      )
    }
  } else if (fmt == "yaml") {
    if (is.list(spec)) {
      spec_list <- spec
    } else {
      txt <- if (is_spec_file) readLines(spec) else spec
      spec_list <- yaml::read_yaml(text = paste(txt, collapse = "\n"))
    }
  } else if (fmt == "esm") {
    if (is_spec_file) {
      spec_text <- paste(readLines(spec), collapse = "\n")
    } else if (is.character(spec)) {
      spec_text <- spec
    } else {
      stop("For specType='esm', `spec` must be JS code (text or file).")
    }
    widget_type <- "esmText"
  }

  # 3) Embed width/height into spec_list
  if (!is.null(spec_list)) {
    strip_px <- function(x) {
      if (is.numeric(x)) {
        return(as.integer(x))
      }
      if (is.character(x) && grepl("^[0-9]+px$", x)) {
        return(as.integer(sub("px$", "", x)))
      }
      NULL
    }
    if (is.null(spec_list$width) && !is.null(w <- strip_px(width))) {
      spec_list$width <- w
    }
    if (is.null(spec_list$height) && !is.null(h <- strip_px(height))) {
      spec_list$height <- h
    }
  }

  # 4) Resolve the DuckDB connection for the R backend. A supplied connection
  # is queried in place and stays owned by the caller; only a connection
  # opened here may be disconnected later.
  con_owned <- !use_wasm && !con_supplied
  if (con_owned) {
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
    try(DBI::dbExecute(con, "LOAD 'arrow';"), silent = TRUE)
  }

  # 5) Handle data registration
  # Process data differently depending on backend (R DuckDB vs browser WASM)
  input_tables <- NULL
  input_exports <- NULL
  sql_sources <- character()
  if (!is.null(data)) {
    # Validate data input
    if (!is.list(data)) {
      stop("'data' must be a named list of data.frames or SQL strings")
    }
    if (is.null(names(data)) || any(names(data) == "")) {
      stop("All elements in 'data' list must be named")
    }
    sql_sources <- names(data)[vapply(data, .mosaic_is_sql, logical(1))]
    if (length(sql_sources) > 0L && !con_supplied) {
      stop(sprintf(
        "Element(s) %s in 'data' are SQL strings; supply 'con' (a DuckDB DBI connection) to run them.",
        paste(sprintf("'%s'", sql_sources), collapse = ", ")
      ), call. = FALSE)
    }
  }
  if (use_wasm && con_supplied && length(sql_sources) == 0L) {
    stop(
      "'con' was supplied with backend = 'wasm' but 'data' has no SQL string ",
      "elements to export from it; pass SQL strings in 'data' or drop 'con'.",
      call. = FALSE
    )
  }
  if (!is.null(data)) {
    if (!use_wasm) {
      # R backend: register data.frames as DuckDB tables and SQL strings as
      # temporary views on the connection
      for (nm in names(data)) {
        df <- data[[nm]]
        if (.mosaic_is_sql(df)) {
          .mosaic_register_sql_view(con, nm, df)
          next
        }
        if (!inherits(df, "data.frame")) {
          stop(sprintf(
            "Element '%s' in data list must be a data.frame or a single SQL string, got: %s",
            nm,
            class(df)[1]
          ))
        }

        # Convert factors to character for safe serialization
        df[] <- lapply(df, function(col) {
          if (is.factor(col)) as.character(col) else col
        })

        # Register table in DuckDB
        tryCatch(
          {
            DBI::dbWriteTable(con, nm, df, overwrite = TRUE)
          },
          error = function(e) {
            stop(sprintf(
              "Failed to register table '%s' in DuckDB: %s",
              nm,
              e$message
            ))
          }
        )
      }
    } else {
      # WASM backend: serialize data for browser-side processing
      input_tables <- list()
      for (nm in names(data)) {
        df <- data[[nm]]
        if (.mosaic_is_sql(df)) {
          exported <- .mosaic_export_sql_table(con, df, nm, data_transport, data_dir)
          input_tables[[nm]] <- exported$table
          input_exports[[nm]] <- exported$export
          next
        }
        if (!inherits(df, "data.frame")) {
          stop(sprintf(
            "Element '%s' in data list must be a data.frame or a single SQL string, got: %s",
            nm,
            class(df)[1]
          ))
        }

        # Convert factors to character
        df[] <- lapply(df, function(col) {
          if (is.factor(col)) as.character(col) else col
        })

        if (identical(data_transport, "file")) {
          raw_bytes <- arrow::write_to_raw(arrow::as_arrow_table(df), format = "stream")
          input_tables[[nm]] <- .mosaic_write_data_file(raw_bytes, data_dir, nm)
        } else {
          # Convert to row-oriented format for JSON serialization
          input_tables[[nm]] <- .mosaic_rows(df)
        }
      }
    }

    # Clear any existing data specification in the spec
    if (!is.null(spec_list$data)) spec_list$data <- NULL
  }

  # 6) Setup Shiny query handler for R backend
  uid <- paste0("mosaic_", sprintf("%08x", sample.int(.Machine$integer.max, 1)))
  session <- shiny::getDefaultReactiveDomain()

  if (!use_wasm && !is.null(session) && !is.null(con)) {
    session$userData$mosaicConnections <-
      c(session$userData$mosaicConnections, setNames(list(con), uid))
    if (con_owned) {
      session$userData$mosaicOwnedConnections <-
        c(session$userData$mosaicOwnedConnections, setNames(list(con), uid))
    }

    shiny::observeEvent(
      session$input[[paste0(uid, "_mosaic_query")]],
      {
        req <- session$input[[paste0(uid, "_mosaic_query")]]
        if (is.null(req)) {
          return()
        }

        # Use the connection directly from the outer scope
        if (is.null(con)) {
          warning("Connection for widget ", uid, " is not available.")
          return()
        }

        if (identical(req$type, "exec")) {
          DBI::dbExecute(con, req$sql)
          payload <- list(success = TRUE)
        } else {
          dfres <- DBI::dbGetQuery(con, req$sql)
          payload <- .mosaic_rows(dfres)
        }
        session$sendCustomMessage(
          paste0(uid, "_mosaic_response"),
          list(request = req$request, data = payload)
        )
      },
      ignoreNULL = TRUE
    )

    # Cleanup: only connections opened by mosaic() itself; a supplied
    # connection stays open for its owner.
    if (is.null(session$userData$.mosaicCleanup)) {
      session$onSessionEnded(function() {
        lapply(session$userData$mosaicOwnedConnections, function(cnn) {
          try(DBI::dbDisconnect(cnn), silent = TRUE)
        })
      })
      session$userData$.mosaicCleanup <- TRUE
    }
  }

  # 7) Create widget
  widget_data <- list(
    spec = spec_list,
    specType = widget_type,
    specText = spec_text,
    widgetId = uid,
    useWasm = use_wasm,
    input_tables = input_tables
  )
  # Only present when a SQL source was exported, so the payload of every
  # pre-existing call shape is unchanged.
  if (!is.null(input_exports)) {
    widget_data$input_exports <- input_exports
  }

  data_dependency <- if (identical(data_transport, "file")) {
    .mosaic_data_dependency(
      .mosaic_recorded_data_files(), data_dir,
      sprintf("%08x", sample.int(.Machine$integer.max, 1L))
    )
  } else NULL

  htmlwidgets::createWidget(
    name = "mosaic",
    x = widget_data,
    width = width,
    height = height,
    package = "rMosaic",
    dependencies = if (is.null(data_dependency)) NULL else list(data_dependency),
    sizingPolicy = htmlwidgets::sizingPolicy(browser.fill = TRUE)
  )
}

# Files written for `data_transport = "file"` during one mosaic() call. They
# ship as an html dependency attachment so the relative URL in the payload
# resolves in the RStudio Viewer, in Shiny and after saveWidget() into any
# directory, not only when the page is served from `data_dir`.
# An auto-created data directory is scoped to the Shiny session that renders the
# widget: one directory per session instead of one per render, removed when the
# session ends. Outside Shiny it is a session temporary directory as before.
# Re-rendering a widget still writes a new payload into that directory; the
# previous one is removed with the directory when the session ends.
.mosaic_session_data_dir <- function(prefix) {
  session <- if (requireNamespace("shiny", quietly = TRUE)) shiny::getDefaultReactiveDomain() else NULL
  if (is.null(session)) return(tempfile(prefix))
  existing <- session$userData$.mosaic_data_dir
  if (!is.null(existing) && dir.exists(existing)) return(existing)
  path <- tempfile(prefix)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  session$userData$.mosaic_data_dir <- path
  session$onSessionEnded(function() unlink(path, recursive = TRUE))
  path
}

.mosaic_data_file_registry <- new.env(parent = emptyenv())
.mosaic_data_file_registry$files <- character()

.mosaic_reset_data_files <- function() {
  .mosaic_data_file_registry$files <- character()
  invisible(NULL)
}

.mosaic_record_data_file <- function(path) {
  .mosaic_data_file_registry$files <- c(.mosaic_data_file_registry$files, path)
  invisible(path)
}

.mosaic_recorded_data_files <- function() unique(.mosaic_data_file_registry$files)

.mosaic_data_dependency <- function(files, data_dir, uid) {
  files <- files[file.exists(files)]
  if (!length(files)) return(NULL)
  htmltools::htmlDependency(
    name = paste0("mosaic-data-", uid),
    version = as.character(utils::packageVersion("rMosaic")),
    src = c(file = normalizePath(data_dir, winslash = "/", mustWork = TRUE)),
    attachment = stats::setNames(basename(files), paste0("data", seq_along(files))),
    all_files = FALSE
  )
}

# Keep exotic frames/columns on the original path: their subsetting methods
# and attributes are part of the R-facing and JSON serialization contracts.
.mosaic_rows <- function(df) {
  safe <- identical(class(df), "data.frame") &&
    identical(sort(names(attributes(df))), c("class", "names", "row.names")) &&
    all(vapply(df, function(col) {
      is.null(attributes(col)) &&
        typeof(col) %in% c("logical", "integer", "double", "character")
    }, logical(1)))
  if (!safe) {
    return(lapply(seq_len(nrow(df)), function(i) {
      as.list(df[i, , drop = FALSE])
    }))
  }
  columns <- unclass(df)
  attr(columns, "row.names") <- NULL
  lapply(seq_len(nrow(df)), function(i) lapply(columns, `[`, i))
}

.mosaic_data_file_stem <- function(data_dir, name) {
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  safe_name <- gsub("[^A-Za-z0-9_-]+", "_", name)
  file.path(
    data_dir,
    sprintf("mosaic_%s_%08x", safe_name, sample.int(.Machine$integer.max, 1L))
  )
}

.mosaic_write_data_file <- function(raw_bytes, data_dir, name) {
  path <- paste0(.mosaic_data_file_stem(data_dir, name), ".arrows")
  on.exit(.mosaic_record_data_file(path), add = TRUE)
  writeBin(raw_bytes, path)
  list(`__arrow_url` = basename(path), `__arrow_format` = "stream")
}

.mosaic_is_sql <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
}

# DuckDB rejects a trailing terminator inside COPY (...) and CREATE VIEW ... AS.
.mosaic_strip_sql <- function(sql) {
  sql <- sub("[[:space:];]+$", "", sql)
  # DuckDB executes every statement in a string, so a second statement would
  # run on the caller's connection instead of becoming part of the view.
  if (grepl(";", sql, fixed = TRUE)) {
    stop("A SQL data element must be a single statement (no ';' inside): ", sql, call. = FALSE)
  }
  sql
}

.mosaic_register_sql_view <- function(con, name, sql) {
  statement <- sprintf(
    "CREATE OR REPLACE TEMP VIEW %s AS %s",
    DBI::dbQuoteIdentifier(con, name),
    .mosaic_strip_sql(sql)
  )
  tryCatch(
    DBI::dbExecute(con, statement),
    error = function(e) {
      stop(sprintf(
        "Failed to register SQL view '%s' in DuckDB: %s",
        name,
        conditionMessage(e)
      ), call. = FALSE)
    }
  )
  invisible(name)
}

# Export ladder for SQL sources, fastest first. Every rung streams straight
# from DuckDB to a file, so the result is never a data.frame in R.
.mosaic_export_methods <- c("copy_arrows", "record_batch", "copy_parquet")

.mosaic_export_query <- function(con, sql, path_stem,
                                 methods = .mosaic_export_methods) {
  methods <- match.arg(methods, .mosaic_export_methods, several.ok = TRUE)
  sql <- .mosaic_strip_sql(sql)
  failures <- character()
  for (method in methods) {
    format <- if (identical(method, "copy_parquet")) "parquet" else "arrows"
    path <- paste0(path_stem, ".", format)
    failure <- tryCatch(
      {
        switch(method,
          copy_arrows = .mosaic_export_copy_arrows(con, sql, path),
          record_batch = .mosaic_export_record_batch(con, sql, path),
          copy_parquet = .mosaic_export_copy_parquet(con, sql, path)
        )
        NULL
      },
      error = function(e) conditionMessage(e)
    )
    if (is.null(failure)) {
      return(list(path = path, format = format, method = method, failures = failures))
    }
    # A rung may have created a partial file before failing.
    if (file.exists(path)) unlink(path)
    failures[[method]] <- failure
  }
  stop(sprintf(
    "Could not export SQL source with any DuckDB method:\n%s",
    paste(sprintf("  %s: %s", names(failures), failures), collapse = "\n")
  ), call. = FALSE)
}

# Community extension: INSTALL is a local no-op once it is present, so the
# network is only touched on first use; on DuckDB builds without the
# extension the error falls through to the next rung.
.mosaic_export_copy_arrows <- function(con, sql, path) {
  # Only load: installing extensions would mutate a caller-owned connection
  # and touch the network. Without the extension the ladder moves on.
  DBI::dbExecute(con, "LOAD nanoarrow")
  DBI::dbExecute(con, sprintf(
    "COPY (%s) TO %s (FORMAT ARROWS)", sql, DBI::dbQuoteString(con, path)
  ))
  invisible(path)
}

.mosaic_export_record_batch <- function(con, sql, path) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is required for record-batch streaming.", call. = FALSE)
  }
  res <- DBI::dbSendQuery(con, sql, arrow = TRUE)
  on.exit(DBI::dbClearResult(res), add = TRUE)
  reader <- duckdb::duckdb_fetch_record_batch(res)
  arrow::write_ipc_stream(reader, path)
  invisible(path)
}

.mosaic_export_copy_parquet <- function(con, sql, path) {
  DBI::dbExecute(con, sprintf(
    "COPY (%s) TO %s (FORMAT PARQUET)", sql, DBI::dbQuoteString(con, path)
  ))
  invisible(path)
}

.mosaic_export_sql_table <- function(con, sql, name, data_transport, data_dir) {
  methods <- getOption("rMosaic.export_methods", .mosaic_export_methods)
  if (identical(data_transport, "file")) {
    exported <- .mosaic_export_query(
      con, sql, .mosaic_data_file_stem(data_dir, name), methods = methods
    )
    .mosaic_record_data_file(exported$path)
    table <- if (identical(exported$format, "parquet")) {
      list(`__parquet_url` = basename(exported$path))
    } else {
      list(`__arrow_url` = basename(exported$path), `__arrow_format` = "stream")
    }
    file <- basename(exported$path)
  } else {
    exported <- .mosaic_export_query(con, sql, tempfile("mosaic_"), methods = methods)
    on.exit(unlink(exported$path), add = TRUE)
    bytes <- readBin(exported$path, what = "raw", n = file.size(exported$path))
    encoded <- gsub("\n", "", jsonlite::base64_enc(bytes), fixed = TRUE)
    table <- if (identical(exported$format, "parquet")) {
      list(`__parquet_b64` = encoded)
    } else {
      encoded
    }
    file <- NULL
  }
  list(
    table = table,
    export = list(method = exported$method, format = exported$format, file = file)
  )
}
