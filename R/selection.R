# R/selection.R

# Package-level environment; selections are stored here by default so that
# the package never writes to .GlobalEnv.
.mosaic_sel_store <- new.env(parent = emptyenv())

#' Retrieve a stored Mosaic selection
#'
#' @description
#' After pressing "Import Selection" in a \code{\link{runMosaicWithExport}}
#' app, the selected data are stored inside the package under the name printed
#' in the status bar (e.g. \code{"mosaic_sel_1"}). Use this function to
#' retrieve a selection by that name.
#'
#' @param name Character scalar: the variable name returned by the import
#'   button (e.g. \code{"mosaic_sel_1"}).
#' @return The stored \code{data.frame}, or \code{NULL} with a warning if the
#'   name is not found.
#' @seealso \code{\link{list_mosaic_selections}}
#' @export
get_mosaic_selection <- function(name) {
  if (!exists(name, envir = .mosaic_sel_store, inherits = FALSE)) {
    warning("No Mosaic selection named '", name, "' found.")
    return(NULL)
  }
  get(name, envir = .mosaic_sel_store, inherits = FALSE)
}

#' List all stored Mosaic selections
#'
#' @description
#' Returns the names of all selections currently held in the package store.
#'
#' @return Character vector of selection names.
#' @seealso \code{\link{get_mosaic_selection}}
#' @export
list_mosaic_selections <- function() {
  ls(.mosaic_sel_store)
}

#' Persist a data.frame into an R environment
#'
#' @param df data.frame to store
#' @param env environment to store the selection in; defaults to the
#'   package-internal store (never \code{.GlobalEnv})
#' @return Name of the variable created
#' @keywords internal
#' @noRd
store_mosaic_selection <- function(df, env = NULL) {
  if (is.null(env)) env <- .mosaic_sel_store
  if (!exists(".mosaic_sel_counter", envir = env, inherits = FALSE)) {
    assign(".mosaic_sel_counter", 0L, envir = env)
  }
  cnt <- get(".mosaic_sel_counter", envir = env, inherits = FALSE) + 1L
  assign(".mosaic_sel_counter", cnt, envir = env)
  nm <- paste0("mosaic_sel_", cnt)
  assign(nm, df, envir = env)
  nm
}


.mosaic_first_data_frame <- function(data) {
  if (!is.list(data) || length(data) == 0) {
    stop("'data' must be a non-empty named list of data.frames.")
  }
  if (is.null(names(data)) || !all(nzchar(names(data)))) {
    stop("All elements in 'data' must be named.")
  }
  table_name <- names(data)[[1]]
  df <- data[[table_name]]
  if (!inherits(df, "data.frame")) {
    stop(sprintf("Data element '%s' must be a data.frame.", table_name))
  }
  list(name = table_name, data = df)
}


.mosaic_axis_field <- function(axis) {
  if (is.character(axis) && length(axis) == 1L && nzchar(axis)) {
    return(axis)
  }
  if (is.list(axis) && is.character(axis$field) && length(axis$field) == 1L) {
    return(axis$field)
  }
  NULL
}


.mosaic_dot_xy_candidates <- function(node) {
  walk <- function(x) {
    if (!is.list(x)) return(list())
    found <- list()
    if (identical(x$mark, "dot")) {
      x_col <- .mosaic_axis_field(x$x)
      y_col <- .mosaic_axis_field(x$y)
      if (!is.null(x_col) && !is.null(y_col)) {
        found <- list(c(x = x_col, y = y_col))
      }
    }
    c(found, unlist(lapply(x, walk), recursive = FALSE))
  }
  walk(node)
}


.mosaic_find_xy_columns <- function(spec, df) {
  candidates <- .mosaic_dot_xy_candidates(spec)
  if (length(candidates) > 0) {
    for (candidate in candidates) {
      if (
        all(candidate %in% colnames(df)) &&
          is.numeric(df[[candidate[["x"]]]]) &&
          is.numeric(df[[candidate[["y"]]]])
      ) {
        return(as.list(candidate))
      }
    }
  }

  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  if (length(numeric_cols) >= 2L) {
    return(list(x = numeric_cols[[1]], y = numeric_cols[[2]]))
  }

  NULL
}
