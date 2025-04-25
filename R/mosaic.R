# R/mosaic.R

#' Render a Mosaic visualization in Shiny
#'
#' @param spec      JSON/YAML (as R list, text, or file) or ESM JS code (text or file).
#' @param specType  One of "auto" (default), "json", "yaml", or "esm".
#' @param data      Named list of data.frames to register in DuckDB.
#' @param width     CSS or pixel width (e.g. "100%", "600px", or numeric).
#' @param height    CSS or pixel height.
#' @return An htmlwidget that renders the Mosaic visualization.
#' @export
mosaic <- function(
    spec,
    specType = c("auto", "json", "yaml", "esm"),
    data     = NULL,
    width    = NULL,
    height   = NULL
) {
  specType <- match.arg(specType)

  # 1) Determine format
  fmt <- specType
  if (fmt == "auto") {
    if (is.list(spec)) {
      fmt <- "json"
    } else if (is.character(spec) && length(spec)==1 && file.exists(spec)) {
      ext <- tolower(tools::file_ext(spec))
      fmt <- if (ext %in% c("js","mjs")) "esm" else if (ext %in% c("yaml","yml")) "yaml" else "json"
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
      txt <- if (file.exists(spec)) readLines(spec) else spec
      spec_list <- jsonlite::fromJSON(paste(txt, collapse="\n"), simplifyVector=FALSE)
    }
  } else if (fmt == "yaml") {
    if (is.list(spec)) {
      spec_list <- spec
    } else {
      txt <- if (file.exists(spec)) readLines(spec) else spec
      spec_list <- yaml::read_yaml(text=paste(txt, collapse="\n"))
    }
  } else if (fmt == "esm") {
    if (file.exists(spec)) {
      spec_text <- paste(readLines(spec), collapse="\n")
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
      if (is.numeric(x)) return(as.integer(x))
      if (is.character(x) && grepl("^[0-9]+px$", x))
        return(as.integer(sub("px$","",x)))
      NULL
    }
    if (is.null(spec_list$width)  && !is.null(w <- strip_px(width)))  spec_list$width  <- w
    if (is.null(spec_list$height) && !is.null(h <- strip_px(height))) spec_list$height <- h
  }

  # 4) Spin up DuckDB, load arrow (for Arrow connector) and leave extension loading to JS
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir=":memory:")
  try(DBI::dbExecute(con, "LOAD 'arrow';"), silent=TRUE)

  if (!is.null(data)) {
    stopifnot(is.list(data))
    for (nm in names(data)) {
      df <- data[[nm]]
      stopifnot(inherits(df, "data.frame"))
      df[] <- lapply(df, function(col) if (is.factor(col)) as.character(col) else col)
      DBI::dbWriteTable(con, nm, df, overwrite=TRUE)
    }
    # clear the spec_list$data so JS will use the DuckDB connector
    if (!is.null(spec_list$data)) spec_list$data <- NULL
  }

  # 5) Setup Shiny query handler
  uid     <- paste0("mosaic_", sprintf("%08x", sample.int(.Machine$integer.max,1)))
  session <- shiny::getDefaultReactiveDomain()
  if (!is.null(session)) {
    session$userData$mosaicConnections <-
      c(session$userData$mosaicConnections, setNames(list(con), uid))

    shiny::observeEvent(
      session$input[[paste0(uid, "_mosaic_query")]],
      {
        req <- session$input[[paste0(uid, "_mosaic_query")]]
        if (is.null(req)) return()
        if (identical(req$type, "exec")) {
          DBI::dbExecute(con, req$sql)
          payload <- list(success=TRUE)
        } else {
          dfres <- DBI::dbGetQuery(con, req$sql)
          payload <- lapply(seq_len(nrow(dfres)), function(i) as.list(dfres[i, ,drop=FALSE]))
        }
        session$sendCustomMessage(paste0(uid, "_mosaic_response"),
                                  list(request=req$request, data=payload))
      }, ignoreNULL=TRUE
    )

    # cleanup
    if (is.null(session$userData$.mosaicCleanup)) {
      session$onSessionEnded(function() {
        lapply(session$userData$mosaicConnections, function(cnn) {
          try(DBI::dbDisconnect(cnn), silent=TRUE)
        })
      })
      session$userData$.mosaicCleanup <- TRUE
    }
  }

  # 6) Create widget
  widget_data <- list(
    spec     = spec_list,
    specType = widget_type,
    specText = spec_text,
    widgetId = uid
  )
  htmlwidgets::createWidget(
    name         = "mosaic",
    x            = widget_data,
    width        = width,
    height       = height,
    package      = "mosaicShiny",
    sizingPolicy = htmlwidgets::sizingPolicy(browser.fill=TRUE)
  )
}
