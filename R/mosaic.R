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
#' @param data      Named list of data.frames to register in DuckDB.
#' @param backend   Database backend: "r" (default) for R DuckDB or "wasm" for browser WASM DuckDB.
#' @param data_transport How `backend = "wasm"` input tables are delivered to
#'   the browser. `"auto"` uses `"file"` when `data_dir` is supplied and
#'   otherwise falls back to `"inline"` for portable widgets; `"inline"` keeps
#'   the row-JSON path; `"file"` writes Arrow IPC files to `data_dir` and
#'   registers them in DuckDB-WASM by URL.
#' @param data_dir  Directory for `"file"` transport. Serve or save the widget
#'   from the same directory so relative URLs resolve.
#' @param width     CSS or pixel width (e.g. "100\%", "600px", or numeric).
#' @param height    CSS or pixel height.
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
    height = NULL) {
  specType <- match.arg(specType)
  backend <- match.arg(backend)
  data_transport <- match.arg(data_transport)
  if (identical(data_transport, "auto")) {
    data_transport <- if (!is.null(data_dir)) "file" else "inline"
  }
  if (identical(data_transport, "file")) {
    if (!is.character(data_dir) || length(data_dir) != 1L || !nzchar(data_dir)) {
      stop("'data_dir' is required when data_transport = 'file'.", call. = FALSE)
    }
    if (!requireNamespace("arrow", quietly = TRUE)) {
      stop("Package 'arrow' is required when data_transport = 'file'.", call. = FALSE)
    }
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }

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

  # 4) Spin up DuckDB connection for R backend
  con <- NULL
  if (!use_wasm) {
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
    try(DBI::dbExecute(con, "LOAD 'arrow';"), silent = TRUE)
  }

  # 5) Handle data registration
  # Process data differently depending on backend (R DuckDB vs browser WASM)
  input_tables <- NULL
  if (!is.null(data)) {
    # Validate data input
    if (!is.list(data)) {
      stop("'data' must be a named list of data.frames")
    }
    if (is.null(names(data)) || any(names(data) == "")) {
      stop("All elements in 'data' list must be named")
    }

    if (!use_wasm) {
      # R backend: register data.frames as DuckDB tables
      for (nm in names(data)) {
        df <- data[[nm]]
        if (!inherits(df, "data.frame")) {
          stop(sprintf(
            "Element '%s' in data list must be a data.frame, got: %s",
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
        if (!inherits(df, "data.frame")) {
          stop(sprintf(
            "Element '%s' in data list must be a data.frame, got: %s",
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
          input_tables[[nm]] <- lapply(seq_len(nrow(df)), function(i) {
            as.list(df[i, , drop = FALSE])
          })
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
          payload <- lapply(seq_len(nrow(dfres)), function(i) {
            as.list(dfres[i, , drop = FALSE])
          })
        }
        session$sendCustomMessage(
          paste0(uid, "_mosaic_response"),
          list(request = req$request, data = payload)
        )
      },
      ignoreNULL = TRUE
    )

    # Cleanup
    if (is.null(session$userData$.mosaicCleanup)) {
      session$onSessionEnded(function() {
        lapply(session$userData$mosaicConnections, function(cnn) {
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

  htmlwidgets::createWidget(
    name = "mosaic",
    x = widget_data,
    width = width,
    height = height,
    package = "rMosaic",
    sizingPolicy = htmlwidgets::sizingPolicy(browser.fill = TRUE)
  )
}

.mosaic_write_data_file <- function(raw_bytes, data_dir, name) {
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  safe_name <- gsub("[^A-Za-z0-9_-]+", "_", name)
  path <- file.path(
    data_dir,
    sprintf("mosaic_%s_%08x.arrows", safe_name, sample.int(.Machine$integer.max, 1L))
  )
  writeBin(raw_bytes, path)
  list(`__arrow_url` = basename(path), `__arrow_format` = "stream")
}
