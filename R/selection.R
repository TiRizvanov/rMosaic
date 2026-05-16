# R/selection.R

#' Persist a data.frame into an R environment
#'
#' @param df data.frame to store
#' @param env environment to store the selection in
#' @return Name of the variable created
#' @keywords internal
#' @noRd
store_mosaic_selection <- function(df, env = .GlobalEnv) {
  if (!exists(".mosaic_sel_counter", envir = env)) {
    assign(".mosaic_sel_counter", 0, envir = env)
  }
  cnt <- get(".mosaic_sel_counter", envir = env) + 1
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
  candidates <- list()
  walk <- function(x) {
    if (!is.list(x)) return()
    if (identical(x$mark, "dot")) {
      x_col <- .mosaic_axis_field(x$x)
      y_col <- .mosaic_axis_field(x$y)
      if (!is.null(x_col) && !is.null(y_col)) {
        candidates[[length(candidates) + 1L]] <<- c(x = x_col, y = y_col)
      }
    }
    for (item in x) walk(item)
  }
  walk(node)
  candidates
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
