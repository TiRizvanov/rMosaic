# Enhanced ggplot2-style API for rMosaic
#
# This provides a truly ergonomic ggplot2-like experience while maintaining
# full compatibility with the existing spec-based approach.

# Core ggmosaic object ====================================================

#' Create a new Mosaic visualization (ggplot2-style)
#'
#' @param data A data.frame, tibble, or table name (string)
#' @param mapping Default aesthetic mappings created with \code{aes()}
#' @param width Plot width (default: 600)
#' @param height Plot height (default: 400)
#' @return A ggmosaic object
#' @export
#' @examples
#' \dontrun{
#' # Simple histogram
#' ggmosaic(mtcars, aes(x = mpg)) +
#'   geom_histogram()
#'
#' # Scatterplot with color
#' ggmosaic(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
#'   geom_point()
#' }
ggmosaic <- function(data = NULL, mapping = aes(), width = 600, height = 400) {

  # Handle data
  data_name <- NULL
  data_df <- NULL
  data_sql <- NULL

  if (is.data.frame(data)) {
    data_name <- deparse(substitute(data))
    # Clean up name if it's complex
    if (grepl("::", data_name)) {
      data_name <- sub(".*::", "", data_name)
    }
    # Handle piped data (when name is ".")
    if (data_name == ".") {
      data_name <- "data"
    }
    data_df <- data
  } else if (is.character(data)) {
    # Could be table name or SQL query
    if (length(data) == 1 && !grepl("SELECT|FROM|WITH", data, ignore.case = TRUE)) {
      # Simple table name
      data_name <- data
    } else {
      # SQL query
      data_name <- "data"
      data_sql <- paste(data, collapse = "\n")
    }
  } else if (is.list(data) && !is.null(names(data))) {
    # Named list: name = SQL query
    data_name <- names(data)[1]
    data_sql <- data[[1]]
  }

  structure(
    list(
      data = data_df,
      data_name = data_name,
      data_sql = data_sql,
      name = NULL,
      mapping = mapping,
      layers = list(),
      selections = list(),
      options = list(),
      width = width,
      height = height
    ),
    class = "ggmosaic"
  )
}

#' @export
print.ggmosaic <- function(x, ...) {
  cat("<ggmosaic>", "\n")
  if (!is.null(x$data_name)) {
    cat("data:", x$data_name, "\n")
  }
  cat("layers:", length(x$layers), "\n")
  cat("size:", x$width, "x", x$height, "\n")
  invisible(x)
}

# Aesthetic mapping =======================================================

#' Define aesthetic mappings
#'
#' @param ... Named arguments mapping aesthetics to variables
#' @return An aesthetic mapping object
#' @export
#' @examples
#' aes(x = mpg, y = hp)
#' aes(x = mpg, fill = cyl)
aes <- function(...) {
  # Capture expressions without evaluating
  mapping <- as.list(substitute(list(...)))[-1]

  # Convert to character strings
  mapping <- lapply(mapping, function(x) {
    if (is.symbol(x) || is.name(x)) {
      as.character(x)
    } else if (is.call(x)) {
      deparse(x)
    } else {
      x
    }
  })

  structure(mapping, class = "ggmosaic_aes")
}

# Layer addition operator =================================================

#' Add components to a ggmosaic plot
#'
#' @param e1 A ggmosaic object
#' @param e2 A layer, scale, or other component
#' @export
`+.ggmosaic` <- function(e1, e2) {

  # Handle lists (e.g., from fixed_domain("both"))
  if (is.list(e2) && !inherits(e2, c("ggmosaic_layer", "ggmosaic_selection", "ggmosaic_option"))) {
    for (item in e2) {
      e1 <- e1 + item
    }
    return(e1)
  }

  if (inherits(e2, "ggmosaic_layer")) {
    e1$layers <- c(e1$layers, list(e2))
    return(e1)
  }

  if (inherits(e2, "ggmosaic_selection")) {
    e1$selections[[e2$name]] <- e2
    return(e1)
  }

  if (inherits(e2, "ggmosaic_option")) {
    e1$options[[e2$name]] <- e2$value
    return(e1)
  }

  stop("Cannot add object of class ", paste(class(e2), collapse = ", "), " to ggmosaic")
}

# Geom functions (layers) =================================================

.create_layer <- function(geom, mapping = aes(), data = NULL,
                         stat = "identity", position = "identity",
                         filter = NULL, ...) {
  structure(
    list(
      geom = geom,
      mapping = mapping,
      data = data,
      stat = stat,
      position = position,
      filter = filter,
      params = list(...)
    ),
    class = "ggmosaic_layer"
  )
}

#' Histogram layer
#'
#' @param mapping Aesthetic mappings (aes)
#' @param data Override default data
#' @param bins Number of bins (default: 30)
#' @param binwidth Bin width
#' @param fill Fill color
#' @param filter Selection to filter by
#' @param ... Additional mark parameters
#' @export
#' @examples
#' \dontrun{
#' ggmosaic(mtcars, aes(x = mpg)) +
#'   geom_histogram(fill = "steelblue")
#' }
geom_histogram <- function(mapping = aes(), data = NULL, bins = 30,
                          binwidth = NULL, fill = "steelblue",
                          filter = NULL, ...) {
  .create_layer(
    "histogram",
    mapping = mapping,
    data = data,
    filter = filter,
    fill = fill,
    bins = bins,
    binwidth = binwidth,
    ...
  )
}

#' Vertical histogram (counts on x, bins on y)
#'
#' @param mapping Aesthetic mappings (aes)
#' @param data Override default data
#' @param bins Number of bins (default: 30)
#' @param binwidth Bin width
#' @param fill Fill color
#' @param filter Selection to filter by
#' @param ... Additional mark parameters
#' @export
geom_histogram_y <- function(mapping = aes(), data = NULL, bins = 30,
                             binwidth = NULL, fill = "steelblue",
                             filter = NULL, ...) {
  .create_layer(
    "histogramY",
    mapping = mapping,
    data = data,
    filter = filter,
    fill = fill,
    bins = bins,
    binwidth = binwidth,
    ...
  )
}

#' Bar chart layer
#'
#' @param mapping Aesthetic mappings
#' @param data Override default data
#' @param fill Fill color
#' @param filter Selection to filter by
#' @param ... Additional parameters
#' @export
geom_bar <- function(mapping = aes(), data = NULL, fill = "steelblue",
                    filter = NULL, ...) {
  .create_layer(
    "bar",
    mapping = mapping,
    data = data,
    filter = filter,
    fill = fill,
    ...
  )
}

#' Point/dot layer
#'
#' @param mapping Aesthetic mappings
#' @param data Override default data
#' @param size Point size (default: 3)
#' @param alpha Opacity (0-1)
#' @param filter Selection to filter by
#' @param ... Additional parameters
#' @export
geom_point <- function(mapping = aes(), data = NULL, size = 3,
                      alpha = 0.7, filter = NULL, ...) {
  .create_layer(
    "point",
    mapping = mapping,
    data = data,
    filter = filter,
    r = size,
    opacity = alpha,
    ...
  )
}

#' Line layer
#'
#' @param mapping Aesthetic mappings
#' @param data Override default data
#' @param color Line color
#' @param size Line width
#' @param filter Selection to filter by
#' @param ... Additional parameters
#' @export
geom_line <- function(mapping = aes(), data = NULL, color = "steelblue",
                     size = 1.5, filter = NULL, ...) {
  .create_layer(
    "line",
    mapping = mapping,
    data = data,
    filter = filter,
    stroke = color,
    strokeWidth = size,
    ...
  )
}

#' Area layer
#'
#' @param mapping Aesthetic mappings
#' @param data Override default data
#' @param fill Fill color
#' @param alpha Opacity
#' @param filter Selection to filter by
#' @param ... Additional parameters
#' @export
geom_area <- function(mapping = aes(), data = NULL, fill = "steelblue",
                     alpha = 0.5, filter = NULL, ...) {
  .create_layer(
    "area",
    mapping = mapping,
    data = data,
    filter = filter,
    fill = fill,
    fillOpacity = alpha,
    ...
  )
}

#' Heatmap/density layer
#'
#' @param mapping Aesthetic mappings
#' @param data Override default data
#' @param filter Selection to filter by
#' @param ... Additional parameters
#' @export
geom_density2d <- function(mapping = aes(), data = NULL, filter = NULL, ...) {
  .create_layer(
    "heatmap",
    mapping = mapping,
    data = data,
    filter = filter,
    ...
  )
}

#' Tile/raster layer
#'
#' @param mapping Aesthetic mappings
#' @param data Override default data
#' @param filter Selection to filter by
#' @param ... Additional parameters
#' @export
geom_raster <- function(mapping = aes(), data = NULL, filter = NULL, ...) {
  .create_layer(
    "raster",
    mapping = mapping,
    data = data,
    filter = filter,
    ...
  )
}

# Interactive selections ==================================================

#' Create a brush selection
#'
#' @param name Selection name (auto-generated if NULL)
#' @param type Selection type (crossfilter, single, union, intersect)
#' @return A selection object
#' @export
#' @examples
#' \dontrun{
#' brush <- brush_selection()
#' ggmosaic(mtcars, aes(x = mpg)) +
#'   geom_histogram(filter = brush) +
#'   brush_x(brush)
#' }
brush_selection <- function(name = NULL, type = c("crossfilter", "single", "union", "intersect")) {
  type <- match.arg(type)

  if (is.null(name)) {
    name <- paste0("brush_", sample.int(10000, 1))
  }

  structure(
    list(
      name = name,
      type = type
    ),
    class = "ggmosaic_selection"
  )
}

#' Add X-axis brush to plot
#'
#' @param selection A selection created with brush_selection()
#' @export
brush_x <- function(selection) {
  if (!inherits(selection, "ggmosaic_selection")) {
    stop("selection must be created with brush_selection()")
  }

  structure(
    list(
      type = "intervalX",
      selection = selection
    ),
    class = "ggmosaic_layer"
  )
}

#' Add Y-axis brush to plot
#'
#' @param selection A selection created with brush_selection()
#' @export
brush_y <- function(selection) {
  if (!inherits(selection, "ggmosaic_selection")) {
    stop("selection must be created with brush_selection()")
  }

  structure(
    list(
      type = "intervalY",
      selection = selection
    ),
    class = "ggmosaic_layer"
  )
}

#' Add 2D brush to plot
#'
#' @param selection A selection created with brush_selection()
#' @export
brush_xy <- function(selection) {
  if (!inherits(selection, "ggmosaic_selection")) {
    stop("selection must be created with brush_selection()")
  }

  structure(
    list(
      type = "intervalXY",
      selection = selection
    ),
    class = "ggmosaic_layer"
  )
}

# Plot options ============================================================

#' Set fixed domain
#'
#' @param axis Which axis ("x", "y", or "both")
#' @export
fixed_domain <- function(axis = c("x", "y", "both")) {
  axis <- match.arg(axis)

  if (axis == "both") {
    return(list(
      structure(list(name = "xDomain", value = "Fixed"), class = "ggmosaic_option"),
      structure(list(name = "yDomain", value = "Fixed"), class = "ggmosaic_option")
    ))
  }

  name <- paste0(axis, "Domain")
  structure(
    list(name = name, value = "Fixed"),
    class = "ggmosaic_option"
  )
}

#' Set explicit x-axis limits
#'
#' @param min Minimum value
#' @param max Maximum value
#' @export
xlim <- function(min, max) {
  structure(
    list(name = "xDomain", value = c(min, max)),
    class = "ggmosaic_option"
  )
}

#' Set explicit y-axis limits
#'
#' @param min Minimum value
#' @param max Maximum value
#' @export
ylim <- function(min, max) {
  structure(
    list(name = "yDomain", value = c(min, max)),
    class = "ggmosaic_option"
  )
}

#' Set plot size
#'
#' @param width Width in pixels
#' @param height Height in pixels
#' @export
plot_size <- function(width = NULL, height = NULL) {
  opts <- list()

  if (!is.null(width)) {
    opts$width <- structure(
      list(name = "width", value = width),
      class = "ggmosaic_option"
    )
  }

  if (!is.null(height)) {
    opts$height <- structure(
      list(name = "height", value = height),
      class = "ggmosaic_option"
    )
  }

  opts
}

#' Set color scale
#'
#' @param type Scale type (e.g., "symlog", "log", "sqrt")
#' @export
color_scale <- function(type) {
  structure(
    list(name = "colorScale", value = type),
    class = "ggmosaic_option"
  )
}

#' Set color scheme
#'
#' @param scheme Color scheme (e.g., "blues", "oranges", "viridis")
#' @export
color_scheme <- function(scheme) {
  structure(
    list(name = "colorScheme", value = scheme),
    class = "ggmosaic_option"
  )
}

#' Fix color domain (prevents auto-scaling across facets)
#' @export
color_domain_fixed <- function() {
  structure(
    list(name = "colorDomain", value = "Fixed"),
    class = "ggmosaic_option"
  )
}

#' Hide axes
#'
#' @param axes Which axes to hide ("x", "y", or "both")
#' @export
hide_axes <- function(axes = c("both", "x", "y")) {
  axes <- match.arg(axes)

  if (axes == "both") {
    return(list(
      structure(list(name = "xAxis", value = NULL), class = "ggmosaic_option"),
      structure(list(name = "yAxis", value = NULL), class = "ggmosaic_option")
    ))
  }

  name <- paste0(axes, "Axis")
  structure(
    list(name = name, value = NULL),
    class = "ggmosaic_option"
  )
}

#' Set plot margins
#'
#' @param margin Margin value (default 0)
#' @export
plot_margins <- function(margin = 0) {
  structure(
    list(name = "margin", value = margin),
    class = "ggmosaic_option"
  )
}

#' Set axis labels
#'
#' @param x X-axis label
#' @param y Y-axis label
#' @export
axis_labels <- function(x = NULL, y = NULL) {
  opts <- list()

  if (!is.null(x)) {
    opts$xLabel <- structure(
      list(name = "xLabel", value = x),
      class = "ggmosaic_option"
    )
  }

  if (!is.null(y)) {
    opts$yLabel <- structure(
      list(name = "yLabel", value = y),
      class = "ggmosaic_option"
    )
  }

  opts
}

#' Set tick format
#'
#' @param x X-axis tick format
#' @param y Y-axis tick format
#' @export
tick_format <- function(x = NULL, y = NULL) {
  opts <- list()

  if (!is.null(x)) {
    opts$xTickFormat <- structure(
      list(name = "xTickFormat", value = x),
      class = "ggmosaic_option"
    )
  }

  if (!is.null(y)) {
    opts$yTickFormat <- structure(
      list(name = "yTickFormat", value = y),
      class = "ggmosaic_option"
    )
  }

  opts
}

# Build spec from ggmosaic ================================================

.merge_aes <- function(global, local) {
  # Local overrides global
  c(global[!names(global) %in% names(local)], local)
}

.build_layer_spec <- function(layer, base_aes, data_name, selections) {

  # Merge aesthetics
  aes_map <- .merge_aes(base_aes, layer$mapping)

  # Get data source
  layer_data <- if (!is.null(layer$data)) {
    if (is.data.frame(layer$data)) {
      deparse(substitute(layer$data))
    } else {
      layer$data
    }
  } else {
    data_name
  }

  # Build data reference
  data_spec <- list(from = layer_data)
  if (!is.null(layer$filter)) {
    sel_name <- layer$filter$name
    data_spec$filterBy <- paste0("$", sel_name)
  }

  # Build channels
  channels <- list()

  # Handle geom-specific conversions
  if (layer$geom == "histogram") {
    # x must be binned
    if (!is.null(aes_map$x)) {
      if (is.character(aes_map$x)) {
        channels$x <- list(bin = aes_map$x)
      } else {
        channels$x <- aes_map$x
      }
      if (!is.null(layer$params$bins) && is.list(channels$x)) {
        channels$x$steps <- layer$params$bins
      }
    }
    # y is count
    channels$y <- list(count = NULL)
    # fill
    channels$fill <- aes_map$fill %||% layer$params$fill
    if (!is.null(layer$params$z)) channels$z <- layer$params$z
    if (!is.null(layer$params$order)) channels$order <- layer$params$order
    if (!is.null(layer$params$reverse)) channels$reverse <- layer$params$reverse
    # inset for nice bars
    channels$insetLeft <- 0.5
    channels$insetRight <- 0.5

    mark <- "rectY"

  } else if (layer$geom == "histogramY") {
    if (!is.null(aes_map$y)) {
      if (is.character(aes_map$y)) {
        channels$y <- list(bin = aes_map$y)
      } else {
        channels$y <- aes_map$y
      }
      if (!is.null(layer$params$bins) && is.list(channels$y)) {
        channels$y$steps <- layer$params$bins
      }
    }
    channels$x <- list(count = NULL)
    channels$fill <- aes_map$fill %||% layer$params$fill
    if (!is.null(layer$params$z)) channels$z <- layer$params$z
    if (!is.null(layer$params$order)) channels$order <- layer$params$order
    if (!is.null(layer$params$reverse)) channels$reverse <- layer$params$reverse
    channels$insetTop <- 0.5
    channels$insetBottom <- 0.5
    mark <- "rectX"

  } else if (layer$geom == "bar") {
    # Similar to histogram but different defaults
    channels$x <- aes_map$x
    channels$y <- aes_map$y %||% list(count = NULL)
    if (!is.null(layer$params$fill)) {
      channels$fill <- layer$params$fill
    }
    mark <- "rectY"

  } else if (layer$geom == "point") {
    channels$x <- aes_map$x
    channels$y <- aes_map$y
    if (!is.null(aes_map$color) || !is.null(aes_map$fill)) {
      channels$fill <- aes_map$color %||% aes_map$fill
    }
    if (!is.null(layer$params$r)) {
      channels$r <- layer$params$r
    }
    if (!is.null(layer$params$opacity)) {
      channels$opacity <- layer$params$opacity
    }
    mark <- "dot"

  } else if (layer$geom == "line") {
    channels$x <- aes_map$x
    channels$y <- aes_map$y
    if (!is.null(layer$params$stroke)) {
      channels$stroke <- layer$params$stroke
    }
    if (!is.null(layer$params$strokeWidth)) {
      channels$strokeWidth <- layer$params$strokeWidth
    }
    if (!is.null(aes_map$color)) {
      channels$stroke <- aes_map$color
    }
    mark <- "lineY"

  } else if (layer$geom == "area") {
    channels$x <- aes_map$x
    channels$y <- aes_map$y
    if (!is.null(layer$params$fill)) {
      channels$fill <- layer$params$fill
    }
    if (!is.null(layer$params$fillOpacity)) {
      channels$fillOpacity <- layer$params$fillOpacity
    }
    mark <- "areaY"

  } else if (layer$geom == "heatmap") {
    channels$x <- aes_map$x
    channels$y <- aes_map$y
    if (!is.null(aes_map$fill)) {
      channels$fill <- aes_map$fill
    } else {
      channels$fill <- list(count = NULL)
    }
    mark <- "heatmap"

  } else if (layer$geom == "raster") {
    channels$x <- aes_map$x
    channels$y <- aes_map$y
    channels$fill <- aes_map$fill %||% aes_map$color %||% "density"
    if (!is.null(layer$params$pad)) {
      channels$pad <- layer$params$pad
    }
    if (!is.null(layer$params$bandwidth)) {
      channels$bandwidth <- layer$params$bandwidth
    }
    mark <- "raster"

  } else {
    stop("Unknown geom: ", layer$geom)
  }

  # Combine
  c(
    list(mark = mark, data = data_spec),
    channels
  )
}

.build_interactor_spec <- function(layer) {
  sel_name <- layer$selection$name
  list(
    select = layer$type,
    as = paste0("$", sel_name)
  )
}

#' Convert ggmosaic to Mosaic spec
#'
#' @param p A ggmosaic object
#' @return A list with spec and data components
#' @export
build_spec <- function(p) {
  if (!inherits(p, "ggmosaic")) {
    stop("build_spec() requires a ggmosaic object")
  }

  # Extract selections
  all_selections <- list()
  for (layer in p$layers) {
    if (!is.null(layer$filter)) {
      sel <- layer$filter
      all_selections[[sel$name]] <- sel
    }
    if (!is.null(layer$selection)) {
      sel <- layer$selection
      all_selections[[sel$name]] <- sel
    }
  }

  # Build plot layers
  plot_layers <- list()

  for (layer in p$layers) {
    if (inherits(layer, "ggmosaic_layer")) {
      # Regular geom layer
      if (!is.null(layer$geom)) {
        layer_spec <- .build_layer_spec(
          layer,
          p$mapping,
          p$data_name,
          all_selections
        )
        plot_layers <- c(plot_layers, list(layer_spec))
      }

      # Interactor layer
      if (!is.null(layer$type) && !is.null(layer$selection)) {
        interactor_spec <- .build_interactor_spec(layer)
        plot_layers <- c(plot_layers, list(interactor_spec))
      }
    }
  }

  # Build complete spec
  spec <- list(
    plot = plot_layers,
    width = p$width,
    height = p$height
  )
  if (!is.null(p$name)) {
    spec$name <- p$name
  }

  # Add options
  for (opt_name in names(p$options)) {
    spec[[opt_name]] <- p$options[[opt_name]]
  }

  # Add params for selections
  if (length(all_selections) > 0) {
    params <- list()
    for (sel_name in names(all_selections)) {
      sel <- all_selections[[sel_name]]
      params[[sel_name]] <- list(select = sel$type)
    }
    spec$params <- params
  }

  # Prepare data
  data_list <- NULL
  data_spec <- NULL

  if (!is.null(p$data)) {
    # R data.frame
    data_list <- list()
    data_list[[p$data_name]] <- p$data
  } else if (!is.null(p$data_sql)) {
    # SQL query - add to spec's data section
    data_spec <- list()
    data_spec[[p$data_name]] <- p$data_sql
    spec$data <- data_spec
  }

  list(
    spec = spec,
    data = data_list
  )
}

#' Render a ggmosaic plot or layout
#'
#' @param p A ggmosaic object or layout
#' @param backend Backend to use ("wasm" or "r")
#' @param ... Additional arguments passed to runMosaicApp
#' @export
#' @examples
#' \dontrun{
#' p <- ggmosaic(mtcars, aes(x = mpg)) +
#'   geom_histogram()
#'
#' render(p)
#' }
render <- function(p, backend = "wasm", extensions = NULL, ...) {
  UseMethod("render")
}

#' @export
render.default <- function(p, backend = "wasm", extensions = NULL, ...) {
  # Assume it's a ggmosaic object
  built <- build_spec(p)

  # Add extensions config if specified
  if (!is.null(extensions)) {
    built$spec$config <- list(extensions = extensions)
  }

  runMosaicApp(
    spec = built$spec,
    specType = "yaml",
    data = built$data,
    backend = backend,
    width = p$width,
    height = p$height,
    ...
  )
}

# Convenience functions ===================================================

#' Create and render in one step
#'
#' @param data Data source
#' @param ... Layers and options
#' @param backend Backend ("wasm" or "r")
#' @export
#' @examples
#' \dontrun{
#' quick_plot(mtcars,
#'   aes(x = mpg),
#'   geom_histogram()
#' )
#' }
quick_plot <- function(data, ..., backend = "wasm") {
  layers <- list(...)

  # Extract aes if present
  aes_idx <- which(sapply(layers, inherits, "ggmosaic_aes"))
  if (length(aes_idx) > 0) {
    mapping <- layers[[aes_idx[1]]]
    layers <- layers[-aes_idx]
  } else {
    mapping <- aes()
  }

  p <- ggmosaic(data, mapping = mapping)

  for (layer in layers) {
    p <- p + layer
  }

  render(p, backend = backend)
}

# Multi-view layout =======================================================

#' Horizontal concatenation of plots
#'
#' @param ... ggmosaic plots or layout objects to concatenate horizontally
#' @return A layout object
#' @export
#' @examples
#' \dontrun{
#' p1 <- ggmosaic(mtcars, aes(x = mpg)) + geom_histogram()
#' p2 <- ggmosaic(mtcars, aes(x = hp)) + geom_histogram()
#' hconcat(p1, p2) %>% render()
#' }
hconcat <- function(...) {
  plots <- list(...)
  structure(
    list(
      type = "hconcat",
      elements = plots
    ),
    class = "ggmosaic_layout"
  )
}

#' Vertical concatenation of plots
#'
#' @param ... ggmosaic plots or layout objects to concatenate vertically
#' @return A layout object
#' @export
#' @examples
#' \dontrun{
#' p1 <- ggmosaic(mtcars, aes(x = mpg)) + geom_histogram()
#' p2 <- ggmosaic(mtcars, aes(x = hp)) + geom_histogram()
#' vconcat(p1, p2) %>% render()
#' }
vconcat <- function(...) {
  plots <- list(...)
  structure(
    list(
      type = "vconcat",
      elements = plots
    ),
    class = "ggmosaic_layout"
  )
}

#' Add horizontal spacing
#'
#' @param pixels Number of pixels for horizontal spacing
#' @return A spacing element
#' @export
hspace <- function(pixels = 10) {
  structure(
    list(hspace = pixels),
    class = "ggmosaic_spacer"
  )
}

#' Add vertical spacing
#'
#' @param pixels Number of pixels for vertical spacing
#' @return A spacing element
#' @export
vspace <- function(pixels = 10) {
  structure(
    list(vspace = pixels),
    class = "ggmosaic_spacer"
  )
}

#' Color legend for a plot
#'
#' @param for_plot Name of the plot to attach legend to
#' @param columns Number of legend columns
#' @param as Optional selection to filter by
#' @export
legend_color <- function(for_plot, columns = 1, as = NULL) {
  structure(
    list(type = "legend", `for` = for_plot, columns = columns, as = as),
    class = "ggmosaic_ui"
  )
}

#' Menu input bound to a selection
#'
#' @param from Table name
#' @param column Column to drive the menu
#' @param label Label text
#' @param as Selection created with brush_selection()
#' @export
input_menu <- function(from, column, label, as) {
  structure(
    list(type = "menu", from = from, column = column, label = label, as = as),
    class = "ggmosaic_ui"
  )
}

#' Data table bound to a selection
#'
#' @param from Table name
#' @param columns Columns to display
#' @param as Selection the table writes to
#' @param filter Selection to filter by
#' @param width Table width
#' @param height Table height
#' @export
data_table <- function(from, columns, as, filter = NULL, width = 680, height = 215) {
  structure(
    list(
      type = "table",
      from = from,
      columns = columns,
      as = as,
      filter = filter,
      width = width,
      height = height
    ),
    class = "ggmosaic_ui"
  )
}

#' Set a name on a plot for cross-references (e.g., legends)
#' @param p ggmosaic plot
#' @param name plot name
#' @export
plot_name <- function(p, name) {
  if (!inherits(p, "ggmosaic")) stop("plot_name() expects a ggmosaic object")
  p$name <- name
  p
}

# Build layout spec
.build_layout_spec <- function(layout) {
  if (inherits(layout, "ggmosaic")) {
    # Single plot
    return(build_spec(layout))
  }

  if (inherits(layout, "ggmosaic_ui")) {
    sel_ref <- function(as) {
      if (inherits(as, "ggmosaic_selection")) {
        return(paste0("$", as$name))
      }
      as
    }

    ui_spec <- NULL
    params <- list()

    if (layout$type == "menu") {
      ui_spec <- list(
        input = "menu",
        from = layout$from,
        column = layout$column,
        label = layout$label,
        as = sel_ref(layout$as)
      )
      if (inherits(layout$as, "ggmosaic_selection")) {
        params[[layout$as$name]] <- list(select = layout$as$type)
      }
    } else if (layout$type == "table") {
      ui_spec <- list(
        input = "table",
        from = layout$from,
        columns = layout$columns,
        as = sel_ref(layout$as),
        width = layout$width,
        height = layout$height
      )
      if (!is.null(layout$filter)) {
        ui_spec$filterBy <- sel_ref(layout$filter)
        if (inherits(layout$filter, "ggmosaic_selection")) {
          params[[layout$filter$name]] <- list(select = layout$filter$type)
        }
      }
      if (inherits(layout$as, "ggmosaic_selection")) {
        params[[layout$as$name]] <- list(select = layout$as$type)
      }
    } else if (layout$type == "legend") {
      ui_spec <- list(
        legend = "color",
        `for` = layout$`for`,
        columns = layout$columns,
        as = sel_ref(layout$as)
      )
      if (inherits(layout$as, "ggmosaic_selection")) {
        params[[layout$as$name]] <- list(select = layout$as$type)
      }
    } else {
      stop("Unknown UI element type: ", layout$type)
    }

    out_spec <- list(spec = ui_spec, data = list())
    if (length(params)) out_spec$spec$params <- params
    return(out_spec)
  }

  if (inherits(layout, "ggmosaic_spacer")) {
    # Spacing element
    return(list(spec = layout, data = list()))
  }

  if (inherits(layout, "ggmosaic_layout")) {
    # Multi-view layout
    all_data <- list()
    all_data_specs <- list()
    all_params <- list()
    elements_spec <- list()

    add_param_if_missing <- function(params, name, def) {
      if (is.null(params[[name]])) params[[name]] <- def
      params
    }

    for (elem in layout$elements) {
      elem_built <- .build_layout_spec(elem)

      # Collect R data
      if (length(elem_built$data) > 0) {
        all_data <- c(all_data, elem_built$data)
      }

      # Collect SQL data specs
      if (!is.null(elem_built$spec$data)) {
        all_data_specs <- c(all_data_specs, elem_built$spec$data)
        # Remove data from individual spec
        elem_built$spec$data <- NULL
      }

      # Collect params (selections)
      if (!is.null(elem_built$spec$params)) {
        for (nm in names(elem_built$spec$params)) {
          all_params <- add_param_if_missing(all_params, nm, elem_built$spec$params[[nm]])
        }
        # Remove params from individual spec
        elem_built$spec$params <- NULL
      }

      # Add spec
      elements_spec <- c(elements_spec, list(elem_built$spec))
    }

    # Remove duplicate data tables
    if (length(all_data) > 0) {
      all_data <- all_data[!duplicated(names(all_data))]
    }

    # Remove duplicate data specs
    if (length(all_data_specs) > 0) {
      all_data_specs <- all_data_specs[!duplicated(names(all_data_specs))]
    }

    # Create layout spec
    layout_spec <- list()

    # Add params (selections) at the top level
    if (length(all_params) > 0) {
      layout_spec$params <- all_params
    }

    # Add SQL data specs at the top level
    if (length(all_data_specs) > 0) {
      layout_spec$data <- all_data_specs
    }

    layout_spec[[layout$type]] <- elements_spec

    return(list(
      spec = layout_spec,
      data = if (length(all_data) > 0) all_data else NULL
    ))
  }

  stop("Unknown layout type")
}

# Update render to handle layouts
#' @export
render.ggmosaic_layout <- function(p, backend = "wasm", extensions = NULL, ...) {
  built <- .build_layout_spec(p)

  # Add extensions config if specified
  if (!is.null(extensions)) {
    built$spec$config <- list(extensions = extensions)
  }

  runMosaicApp(
    spec = built$spec,
    specType = "yaml",
    data = built$data,
    backend = backend,
    ...
  )
}

# Pipe operator ===========================================================

#' Pipe operator
#' @name %>%
#' @rdname pipe
#' @keywords internal
#' @export
#' @importFrom magrittr %>%
#' @usage lhs \%>\% rhs
NULL
