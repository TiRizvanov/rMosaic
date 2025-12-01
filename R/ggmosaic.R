# R/ggmosaic.R
#
# A lightweight ggplot-style DSL for building Mosaic specs in R.
# The helpers return plain lists compatible with the existing `mosaic()`
# widget, so users can choose between JSON/YAML specs or this R-side grammar.

# Small utility to generate stable selection names
.mz_id_counter <- local({
  i <- 0L
  function(prefix = "sel") {
    i <<- i + 1L
    paste0(prefix, i)
  }
})

# Internal helpers --------------------------------------------------------
.mz_merge_selections <- function(a, b) {
  if (is.null(a)) a <- list()
  if (is.null(b)) b <- list()
  all <- c(a, b)
  if (!length(all)) return(list())
  uniq <- list()
  seen <- character()
  for (s in all) {
    nm <- s$name
    if (is.null(nm) || nm %in% seen) next
    uniq[[length(uniq) + 1L]] <- s
    seen <- c(seen, nm)
  }
  uniq
}

.mz_with_selections <- function(obj, sels) {
  if (!length(sels)) return(obj)
  attr(obj, "mz_selections") <- .mz_merge_selections(attr(obj, "mz_selections"), sels)
  obj
}

.mz_collect_selections <- function(obj, acc = list()) {
  sel_attr <- attr(obj, "mz_selections")
  if (length(sel_attr)) acc <- .mz_merge_selections(acc, sel_attr)
  if (is.list(obj)) {
    for (el in obj) {
      acc <- .mz_collect_selections(el, acc)
    }
  }
  acc
}

.mz_selection_ref <- function(sel) {
  if (!inherits(sel, "mz_selection")) {
    stop("`as` must be a Selection object created with Selection$*()", call. = FALSE)
  }
  ref <- paste0("$", sel$name)
  .mz_with_selections(ref, list(sel))
}

.mz_from_value <- function(x) {
  # Pass through most values; attach selection refs if present
  if (inherits(x, "mz_selection")) {
    return(.mz_selection_ref(x))
  }
  if (inherits(x, "mz_expr")) {
    return(unclass(x))
  }
  x
}

# Selection API -----------------------------------------------------------

#' Selection builders
#'
#' Helpers to declare Mosaic selections that can be referenced in plots and
#' layouts. Each selection gets a unique name (or the name you provide) and is
#' automatically added to the spec `params` during `mosaic_spec()`.
#'
#' @export
Selection <- list(
  crossfilter = function(name = NULL) {
    structure(
      list(name = name %||% .mz_id_counter("brush"), type = "crossfilter"),
      class = "mz_selection"
    )
  },
  single = function(name = NULL) {
    structure(
      list(name = name %||% .mz_id_counter("sel"), type = "single"),
      class = "mz_selection"
    )
  },
  union = function(name = NULL) {
    structure(
      list(name = name %||% .mz_id_counter("sel"), type = "union"),
      class = "mz_selection"
    )
  },
  intersect = function(name = NULL) {
    structure(
      list(name = name %||% .mz_id_counter("sel"), type = "intersect"),
      class = "mz_selection"
    )
  }
)

# Expressions / aggregations ---------------------------------------------

wrap_expr <- function(x) {
  structure(x, class = c("mz_expr", "list"))
}

#' Bin a field
#' @export
bin <- function(field, ...) {
  opts <- list(...)
  val <- if (length(opts)) c(list(field = field), opts) else field
  wrap_expr(list(bin = val))
}

#' Count aggregation
#' @export
count <- function(field = "") {
  wrap_expr(list(count = if (is.null(field)) "" else field))
}

#' Count distinct aggregation
#' @export
distinct <- function(field) {
  wrap_expr(list(distinct = field))
}

#' Descending sort helper
#' @export
desc <- function(field) {
  wrap_expr(list(desc = field))
}

# Data references ---------------------------------------------------------

#' Reference a data source with optional filter
#' @export
from <- function(table, filterBy = NULL) {
  out <- list(from = table)
  if (!is.null(filterBy)) {
    out$filterBy <- .mz_from_value(filterBy)
  }
  .mz_with_selections(out, attr(out$filterBy, "mz_selections"))
}

# Interactors -------------------------------------------------------------

#' Interval selection along X
#' @export
intervalX <- function(as) {
  ref <- .mz_selection_ref(as)
  .mz_with_selections(
    list(select = "intervalX", as = ref),
    attr(ref, "mz_selections")
  )
}

#' Interval selection along Y
#' @export
intervalY <- function(as) {
  ref <- .mz_selection_ref(as)
  .mz_with_selections(
    list(select = "intervalY", as = ref),
    attr(ref, "mz_selections")
  )
}

#' 2D interval selection
#' @export
intervalXY <- function(as) {
  ref <- .mz_selection_ref(as)
  .mz_with_selections(
    list(select = "intervalXY", as = ref),
    attr(ref, "mz_selections")
  )
}

# Options / domains -------------------------------------------------------

#' Constant for fixed domains (equivalent to JSON value "Fixed")
#' @export
Fixed <- structure("Fixed", class = "mz_constant")

.mz_option <- function(name, value) {
  structure(
    list(name = name, value = value),
    class = "mz_option"
  )
}

#' Set x-domain
#' @export
xDomain <- function(value) .mz_option("xDomain", value)

#' Set y-domain
#' @export
yDomain <- function(value) .mz_option("yDomain", value)

#' Legend helper
#' @export
legend <- function(value) .mz_option("legend", value)

# Marks -------------------------------------------------------------------

.mz_mark <- function(type, data = NULL, channels = list(), ...) {
  parts <- list(mark = type)

  if (!is.null(data)) {
    parts$data <- data
  }

  if (length(channels)) {
    # Convert any selections/expressions
    channels <- lapply(channels, .mz_from_value)
    parts <- c(parts, channels)
  }

  extra <- list(...)
  if (length(extra)) {
    extra <- lapply(extra, .mz_from_value)
    parts <- c(parts, extra)
  }

  sels <- list()
  if (!is.null(data)) {
    sels <- .mz_merge_selections(sels, attr(data, "mz_selections"))
  }
  sels <- .mz_merge_selections(sels, attr(channels, "mz_selections"))
  sels <- .mz_merge_selections(sels, attr(extra, "mz_selections"))

  .mz_with_selections(parts, sels)
}

#' Generic mark constructor for any Mosaic mark type
#' @export
mark <- function(type, data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark(type, data = data, channels = channels, ...)
}

#' Rectangular bars along Y (histogram/bar)
#' @export
rectY <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("rectY", data = data, channels = channels, ...)
}

#' Rectangular bars along X
#' @export
rectX <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("rectX", data = data, channels = channels, ...)
}

#' Dot mark
#' @export
dot <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("dot", data = data, channels = channels, ...)
}

#' Line mark (Y-oriented)
#' @export
lineY <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("lineY", data = data, channels = channels, ...)
}

#' Area mark (Y-oriented)
#' @export
areaY <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("areaY", data = data, channels = channels, ...)
}

#' Bar mark (Y-oriented shortcut)
#' @export
barY <- function(data, channels, ...) {
  rectY(data, channels, ...)
}

#' Heatmap / rect binning
#' @export
heatmap <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("heatmap", data = data, channels = channels, ...)
}

#' Table mark
#' @export
tableMark <- function(data, channels, ...) {
  if (!is.list(channels)) stop("`channels` must be a list of channel mappings.")
  .mz_mark("table", data = data, channels = channels, ...)
}

# Plot + layout -----------------------------------------------------------

#' Compose a single plot view
#'
#' @param ... Mark/interactor elements and option helpers (e.g., `xDomain(Fixed)`).
#' @param width,height Optional width/height.
#' @export
plot <- function(..., width = NULL, height = NULL) {
  items <- list(...)

  plot_elems <- list()
  opts <- list()
  sels <- list()

  for (it in items) {
    if (inherits(it, "mz_option")) {
      opts[[it$name]] <- it$value
      sels <- .mz_merge_selections(sels, attr(it$value, "mz_selections"))
    } else if (is.list(it) && (length(it$mark) || length(it$select))) {
      plot_elems[[length(plot_elems) + 1L]] <- it
      sels <- .mz_merge_selections(sels, attr(it, "mz_selections"))
    } else {
      stop("Unsupported item passed to plot(): ", deparse(it))
    }
  }

  spec <- c(list(plot = plot_elems), opts)
  if (!is.null(width)) spec$width <- width
  if (!is.null(height)) spec$height <- height

  .mz_with_selections(spec, sels)
}

#' Vertical concatenation
#' @export
vconcat <- function(...) {
  items <- list(...)
  sels <- .mz_collect_selections(items)
  .mz_with_selections(list(vconcat = lapply(items, unclass)), sels)
}

#' Horizontal concatenation
#' @export
hconcat <- function(...) {
  items <- list(...)
  sels <- .mz_collect_selections(items)
  .mz_with_selections(list(hconcat = lapply(items, unclass)), sels)
}

#' Build a Mosaic spec from DSL components
#' @export
mosaic_spec <- function(...) {
  items <- list(...)
  if (!length(items)) stop("Provide at least one plot/layout element.")

  # If multiple items are passed without explicit concat, stack vertically
  body <- if (length(items) == 1L) {
    unclass(items[[1L]])
  } else {
    list(vconcat = lapply(items, unclass))
  }

  sels <- .mz_collect_selections(items)
  if (length(sels)) {
    params <- body$params %||% list()
    for (sel in sels) {
      if (is.null(params[[sel$name]])) {
        params[[sel$name]] <- list(select = sel$type)
      }
    }
    body$params <- params
  }

  structure(body, class = c("mz_spec", "list"))
}

#' Render a Mosaic widget from the DSL
#'
#' @inheritParams mosaic
#' @param ... DSL elements passed to `mosaic_spec()`
#' @export
mosaic_plot <- function(..., data = NULL, backend = c("r", "wasm"), width = NULL, height = NULL) {
  spec <- mosaic_spec(...)
  mosaic(
    spec = spec,
    specType = "json",
    data = data,
    backend = backend,
    width = width,
    height = height
  )
}

#' Null-coalescing helper
`%||%` <- function(x, y) if (is.null(x)) y else x
