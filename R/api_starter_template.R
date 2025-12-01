#' Programmatic API for rMosaic
#'
#' This file provides a programmatic R interface for creating Mosaic visualizations.
#' Users can use R functions instead of writing JSON/YAML specs.
#'
#' @name api
#' @keywords internal
NULL

# ============================================================================
# Core Infrastructure
# ============================================================================

#' Create a new mosaic element
#' @keywords internal
new_mosaic_element <- function(spec, class = NULL) {
  structure(
    list(spec = spec),
    class = c(class, "mosaic_element")
  )
}

#' Check if object is a mosaic element
#' @keywords internal
is_mosaic_element <- function(x) {
  inherits(x, "mosaic_element")
}

#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a

# ============================================================================
# Selection Class (R6)
# ============================================================================

#' Selection class for interactive selections
#'
#' @description
#' Create interactive selections for filtering and linking plots.
#'
#' @export
#' @examples
#' \dontrun{
#' brush <- Selection$crossfilter()
#' single <- Selection$single()
#' }
Selection <- R6::R6Class(
  "Selection",
  public = list(
    #' @field type Selection type
    type = NULL,

    #' @field name Selection parameter name
    name = NULL,

    #' @description Create a new Selection
    #' @param type Selection type (crossfilter, single, intersect, union)
    #' @param name Optional name for the selection parameter
    initialize = function(type, name = NULL) {
      self$type <- type
      self$name <- name %||% paste0("$", make.names(paste0("sel_", type, "_", sample(1000, 1))))
    },

    #' @description Get spec representation
    as_spec = function() {
      list(select = self$type)
    }
  )
)

#' @export
Selection$crossfilter <- function() {
  sel <- Selection$new("crossfilter")
  sel$name <- "$brush"  # Default name
  sel
}

#' @export
Selection$single <- function() {
  Selection$new("single")
}

#' @export
Selection$intersect <- function() {
  Selection$new("intersect")
}

#' @export
Selection$union <- function() {
  Selection$new("union")
}

# ============================================================================
# Data Reference
# ============================================================================

#' Reference a data source
#'
#' @param table Table name in the data list
#' @param filterBy Optional selection to filter by
#' @return A data reference object
#' @export
#' @examples
#' \dontrun{
#' from("mtcars")
#' brush <- Selection$crossfilter()
#' from("mtcars", filterBy = brush)
#' }
from <- function(table, filterBy = NULL) {
  spec <- list(from = table)

  if (!is.null(filterBy)) {
    if (inherits(filterBy, "Selection")) {
      spec$filterBy <- filterBy$name
    } else {
      spec$filterBy <- filterBy
    }
  }

  new_mosaic_element(spec, "data_ref")
}

# ============================================================================
# Channel Functions
# ============================================================================

#' Bin a continuous variable
#'
#' @param column Column name to bin
#' @param step Optional bin step size
#' @return A binning channel
#' @export
bin <- function(column, step = NULL) {
  spec <- list(bin = column)
  if (!is.null(step)) spec$step <- step
  new_mosaic_element(spec, "channel")
}

#' Count aggregation
#'
#' @return A count aggregation channel
#' @export
count <- function() {
  new_mosaic_element(list(count = NULL), "channel")
}

#' Sum aggregation
#'
#' @param column Column to sum
#' @return A sum aggregation channel
#' @export
sum_agg <- function(column) {
  new_mosaic_element(list(sum = column), "channel")
}

#' Mean aggregation
#'
#' @param column Column to average
#' @return A mean aggregation channel
#' @export
mean_agg <- function(column) {
  new_mosaic_element(list(mean = column), "channel")
}

# ============================================================================
# Mark Functions
# ============================================================================

#' Create a rectY mark (bar chart/histogram)
#'
#' @param data Data reference from from()
#' @param encoding Named list of channel encodings (x, y, fill, etc.)
#' @return A mark specification
#' @export
#' @examples
#' \dontrun{
#' rectY(
#'   from("mtcars"),
#'   list(x = bin("mpg"), y = count(), fill = "steelblue")
#' )
#' }
rectY <- function(data, encoding = list()) {
  spec <- list(mark = "rectY")

  # Add data
  if (is_mosaic_element(data)) {
    spec$data <- data$spec
  } else {
    spec$data <- data
  }

  # Add encodings
  for (channel in names(encoding)) {
    val <- encoding[[channel]]
    if (is_mosaic_element(val)) {
      spec[[channel]] <- val$spec
    } else {
      spec[[channel]] <- val
    }
  }

  new_mosaic_element(spec, "mark")
}

#' Create a dot mark (scatterplot)
#'
#' @param data Data reference from from()
#' @param encoding Named list of channel encodings
#' @return A mark specification
#' @export
dot <- function(data, encoding = list()) {
  spec <- list(mark = "dot")

  if (is_mosaic_element(data)) {
    spec$data <- data$spec
  } else {
    spec$data <- data
  }

  for (channel in names(encoding)) {
    val <- encoding[[channel]]
    if (is_mosaic_element(val)) {
      spec[[channel]] <- val$spec
    } else {
      spec[[channel]] <- val
    }
  }

  new_mosaic_element(spec, "mark")
}

#' Create a line mark
#'
#' @param data Data reference from from()
#' @param encoding Named list of channel encodings
#' @return A mark specification
#' @export
line <- function(data, encoding = list()) {
  spec <- list(mark = "line")

  if (is_mosaic_element(data)) {
    spec$data <- data$spec
  } else {
    spec$data <- data
  }

  for (channel in names(encoding)) {
    val <- encoding[[channel]]
    if (is_mosaic_element(val)) {
      spec[[channel]] <- val$spec
    } else {
      spec[[channel]] <- val
    }
  }

  new_mosaic_element(spec, "mark")
}

# ============================================================================
# Interactors
# ============================================================================

#' Create an X-axis interval brush
#'
#' @param as Selection to bind to
#' @return An interactor specification
#' @export
intervalX <- function(as = NULL) {
  spec <- list(select = "intervalX")

  if (!is.null(as)) {
    if (inherits(as, "Selection")) {
      spec$as <- as$name
    } else {
      spec$as <- as
    }
  }

  new_mosaic_element(spec, "interactor")
}

#' Create a Y-axis interval brush
#'
#' @param as Selection to bind to
#' @return An interactor specification
#' @export
intervalY <- function(as = NULL) {
  spec <- list(select = "intervalY")

  if (!is.null(as)) {
    if (inherits(as, "Selection")) {
      spec$as <- as$name
    } else {
      spec$as <- as
    }
  }

  new_mosaic_element(spec, "interactor")
}

#' Create a 2D interval brush
#'
#' @param as Selection to bind to
#' @return An interactor specification
#' @export
intervalXY <- function(as = NULL) {
  spec <- list(select = "intervalXY")

  if (!is.null(as)) {
    if (inherits(as, "Selection")) {
      spec$as <- as$name
    } else {
      spec$as <- as
    }
  }

  new_mosaic_element(spec, "interactor")
}

# ============================================================================
# Plot & Layout Functions
# ============================================================================

#' Fixed domain constant
#' @export
Fixed <- structure(list(), class = "mosaic_fixed")

#' Create a plot with marks and interactors
#'
#' @param ... Marks and interactors to include
#' @param width Plot width in pixels
#' @param height Plot height in pixels
#' @param xDomain X-axis domain (use Fixed or c(min, max))
#' @param yDomain Y-axis domain (use Fixed or c(min, max))
#' @return A plot specification
#' @export
#' @examples
#' \dontrun{
#' plot(
#'   rectY(from("mtcars"), list(x = bin("mpg"), y = count())),
#'   intervalX(as = brush),
#'   width = 600,
#'   height = 400,
#'   xDomain(Fixed)
#' )
#' }
plot <- function(..., width = NULL, height = NULL,
                 xDomain = NULL, yDomain = NULL) {
  elements <- list(...)

  spec <- list(plot = list())

  # Extract marks and interactors
  for (elem in elements) {
    if (is_mosaic_element(elem)) {
      spec$plot <- append(spec$plot, list(elem$spec))
    } else if (is.list(elem)) {
      spec$plot <- append(spec$plot, list(elem))
    }
  }

  # Add options
  if (!is.null(width)) spec$width <- width
  if (!is.null(height)) spec$height <- height

  if (!is.null(xDomain)) {
    if (identical(xDomain, Fixed)) {
      spec$xDomain <- "Fixed"
    } else {
      spec$xDomain <- xDomain
    }
  }

  if (!is.null(yDomain)) {
    if (identical(yDomain, Fixed)) {
      spec$yDomain <- "Fixed"
    } else {
      spec$yDomain <- yDomain
    }
  }

  new_mosaic_element(spec, "plot_spec")
}

#' Vertical concatenation of plots
#'
#' @param ... Plot elements to stack vertically
#' @return A layout specification
#' @export
vconcat <- function(...) {
  elements <- list(...)
  specs <- lapply(elements, function(e) {
    if (is_mosaic_element(e)) e$spec else e
  })
  new_mosaic_element(list(vconcat = specs), "layout")
}

#' Horizontal concatenation of plots
#'
#' @param ... Plot elements to place horizontally
#' @return A layout specification
#' @export
hconcat <- function(...) {
  elements <- list(...)
  specs <- lapply(elements, function(e) {
    if (is_mosaic_element(e)) e$spec else e
  })
  new_mosaic_element(list(hconcat = specs), "layout")
}
