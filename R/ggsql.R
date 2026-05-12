# R/ggsql.R
#
# Public entry point for rendering a ggsql query as a Mosaic widget.
# Compiles the IR produced by [.parse_ggsql()] into a Mosaic JSON spec
# and hands it to [mosaic()].

#' Render a ggsql query as a Mosaic visualization
#'
#' `ggsql()` lets you describe a Mosaic plot using the ggsql dialect
#' (VISUALIZE / DRAW / PLACE / SCALE / LABEL / SETTING) instead of the
#' native Mosaic spec. The same query renders identically in rDeckgl
#' for spatial layers; both packages share the parser.
#'
#' @param sql A character scalar containing ggsql.
#' @param data Optional named list of data.frames to register in the
#'   widget's DuckDB before the spec runs. Use this when the FROM
#'   source in the SQL is not already a table the runtime can see.
#' @param backend Either `"wasm"` (default) or `"r"`. Passed through
#'   to [mosaic()].
#' @param width,height Optional widget dimensions.
#' @param ... Reserved for forward compatibility.
#' @return An htmlwidget produced by [mosaic()].
#' @seealso [.parse_ggsql()], [mosaic()].
#' @export
ggsql <- function(sql, data = NULL,
                  backend = c("wasm", "r"),
                  width = NULL, height = NULL, ...) {
  backend <- match.arg(backend)
  ir <- .parse_ggsql(sql)
  if (is.null(ir)) {
    stop("Input contains no VISUALIZE clause; nothing to render.")
  }
  prep <- .ggsql_mosaic_rename_dotted(ir, data)
  spec <- .ggsql_compile_mosaic(prep$ir, width = width, height = height)
  mosaic(
    spec = spec,
    specType = "json",
    data = prep$data,
    backend = backend,
    width = width %||% spec$width,
    height = height %||% spec$height
  )
}

# Compile IR -> Mosaic spec list ----------------------------------------------

.ggsql_compile_mosaic <- function(ir, width = NULL, height = NULL) {
  source_name <- .ggsql_mosaic_source(ir)

  plot_items <- list()
  for (layer in ir$layers) {
    plot_items <- c(
      plot_items,
      list(.ggsql_mosaic_layer(layer, ir, source_name))
    )
  }

  spec <- list(plot = plot_items)

  # Top-level data section: if the user supplied a base SELECT, expose it
  # as a named source so marks can FROM it. Otherwise we rely on the
  # FROM <table> reference resolving against the widget's DuckDB.
  if (!is.null(ir$base_sql)) {
    spec$data <- list()
    spec$data[[source_name]] <- ir$base_sql
  }

  # Labels. Mosaic only supports per-axis labels (xLabel/yLabel) at the
  # spec root; there is no native plot-level title/subtitle, so we skip
  # those with a one-time message instead of letting Mosaic reject the
  # whole spec.
  if (!is.null(ir$labels[["title"]]) || !is.null(ir$labels[["subtitle"]])) {
    message(
      "Mosaic has no native plot title/subtitle; ignoring LABEL title/subtitle. ",
      "Compose with vconcat or use the rDeckgl backend if you need a heading."
    )
  }
  if (!is.null(ir$labels[["x"]])) spec$xLabel <- ir$labels[["x"]]
  if (!is.null(ir$labels[["y"]])) spec$yLabel <- ir$labels[["y"]]

  # Scales: SCALE fill TO accent  =>  colorScheme: accent.
  # SCALE x TO log => xScale: log. Anything that doesn't map cleanly is
  # passed through under a `<aes>Scale`/`<aes>Scheme` name.
  for (sc in ir$scales) {
    spec <- .ggsql_mosaic_apply_scale(spec, sc)
  }

  # Top-level SETTING: width/height + any pass-through Mosaic options
  # (colorScheme, xDomain, yDomain, margin, ...). Unknown keys go in
  # verbatim, which Mosaic is tolerant of.
  for (nm in names(ir$settings)) {
    val <- ir$settings[[nm]]
    if (nm == "width") {
      spec$width <- val
    } else if (nm == "height") {
      spec$height <- val
    } else if (nm %in% c("coord", "basemap", "view")) {
      # Renderer-specific options that mean nothing here; silently skip.
      next
    } else {
      spec[[nm]] <- val
    }
  }

  if (!is.null(width)) spec$width <- width
  if (!is.null(height)) spec$height <- height
  if (is.null(spec$width)) spec$width <- 640
  if (is.null(spec$height)) spec$height <- 400

  spec
}

# Mosaic's internal SQL builder parses an aesthetic value like
# "Sepal.Length" as a "Sepal"."Length" table.column reference, which
# breaks marks like regressionY. Easiest reliable fix: rename the
# offending columns on the R-side data.frame before we hand it to
# mosaic(), and rewrite the aesthetics to match. Pure column-string
# aesthetics only - sql expressions are left alone.
.ggsql_mosaic_rename_dotted <- function(ir, data) {
  vals <- unique(unlist(ir$aesthetics, use.names = FALSE))
  dotted <- vals[vapply(vals, function(v) {
    is.character(v) && length(v) == 1L && grepl(".", v, fixed = TRUE) &&
      grepl("^[A-Za-z_.][A-Za-z0-9_.]*$", v)
  }, logical(1))]
  if (!length(dotted)) return(list(ir = ir, data = data))

  alias_map <- setNames(
    gsub("[^A-Za-z0-9_]", "_", dotted),
    dotted
  )

  if (is.list(data)) {
    for (nm in names(data)) {
      df <- data[[nm]]
      if (is.data.frame(df)) {
        hits <- which(names(df) %in% names(alias_map))
        if (length(hits)) {
          new_names <- names(df)
          for (i in hits) {
            new_names[[i]] <- unname(alias_map[[new_names[[i]]]])
          }
          names(df) <- new_names
          data[[nm]] <- df
        }
      }
    }
  } else if (is.null(data)) {
    warning(
      "Aesthetic columns contain dots (",
      paste(shQuote(dotted), collapse = ", "),
      ") which Mosaic parses as table.column. Pass `data = list(...)` ",
      "so columns can be renamed, or alias them in your SELECT."
    )
  }

  for (k in names(ir$aesthetics)) {
    v <- ir$aesthetics[[k]]
    if (is.character(v) && length(v) == 1L && v %in% names(alias_map)) {
      ir$aesthetics[[k]] <- unname(alias_map[[v]])
    }
  }
  list(ir = ir, data = data)
}

.ggsql_mosaic_source <- function(ir) {
  if (!is.null(ir$base_sql)) "vis_source"
  else if (!is.null(ir$from)) ir$from
  else stop(
    "VISUALIZE requires a data source: either a SELECT preceding ",
    "VISUALIZE, or `FROM <table>` after the mappings."
  )
}

.ggsql_mosaic_layer <- function(layer, ir, source_name) {
  if (identical(layer$kind, "place")) {
    return(.ggsql_mosaic_place(layer))
  }
  aes_map <- ir$aesthetics
  settings <- layer$settings
  type <- layer$type
  out <- list(data = list(from = source_name))

  if (type == "point" || type == "dot") {
    out$mark <- "dot"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    if (!is.null(aes_map[["color"]])) out$fill <- aes_map[["color"]]
    if (!is.null(aes_map[["fill"]])) out$fill <- aes_map[["fill"]]
    if (!is.null(aes_map[["size"]])) out$r <- aes_map[["size"]]
    if (!is.null(settings[["size"]])) out$r <- settings[["size"]]
    if (!is.null(settings[["opacity"]])) out$opacity <- settings[["opacity"]]
    if (!is.null(settings[["alpha"]]))   out$opacity <- settings[["alpha"]]
  } else if (type == "histogram") {
    out$mark <- "rectY"
    bin_arg <- list(bin = aes_map[["x"]])
    if (!is.null(settings[["binwidth"]])) bin_arg$step <- settings[["binwidth"]]
    if (!is.null(settings[["bins"]]))     bin_arg$steps <- settings[["bins"]]
    out$x <- bin_arg
    out$y <- list(count = "")
    if (!is.null(aes_map[["fill"]]))  out$fill  <- aes_map[["fill"]]
    if (!is.null(aes_map[["color"]])) out$fill  <- aes_map[["color"]]
    out$insetLeft <- 0.5
    out$insetRight <- 0.5
  } else if (type == "histogramy" || type == "histogram_y") {
    out$mark <- "rectX"
    bin_arg <- list(bin = aes_map[["y"]])
    if (!is.null(settings[["binwidth"]])) bin_arg$step <- settings[["binwidth"]]
    if (!is.null(settings[["bins"]]))     bin_arg$steps <- settings[["bins"]]
    out$y <- bin_arg
    out$x <- list(count = "")
    if (!is.null(aes_map[["fill"]])) out$fill <- aes_map[["fill"]]
  } else if (type == "bar") {
    out$mark <- "rectY"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]] %||% list(count = "")
    if (!is.null(aes_map[["fill"]]))  out$fill <- aes_map[["fill"]]
    if (!is.null(aes_map[["color"]])) out$fill <- aes_map[["color"]]
  } else if (type == "line") {
    out$mark <- "lineY"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    if (!is.null(aes_map[["color"]])) out$stroke <- aes_map[["color"]]
    if (!is.null(settings[["linewidth"]])) out$strokeWidth <- settings[["linewidth"]]
  } else if (type == "area") {
    out$mark <- "areaY"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    if (!is.null(aes_map[["fill"]]))  out$fill <- aes_map[["fill"]]
    if (!is.null(aes_map[["color"]])) out$fill <- aes_map[["color"]]
    if (!is.null(settings[["alpha"]])) out$fillOpacity <- settings[["alpha"]]
  } else if (type == "smooth") {
    out$mark <- "regressionY"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    if (!is.null(aes_map[["color"]])) out$stroke <- aes_map[["color"]]
  } else if (type == "boxplot") {
    out$mark <- "boxplotY"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    if (!is.null(aes_map[["color"]])) out$stroke <- aes_map[["color"]]
  } else if (type == "heatmap" || type == "density") {
    out$mark <- "heatmap"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    out$fill <- aes_map[["fill"]] %||% aes_map[["color"]] %||% list(count = "")
  } else if (type == "raster") {
    out$mark <- "raster"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    out$fill <- aes_map[["fill"]] %||% aes_map[["color"]] %||% "density"
  } else if (type == "text") {
    out$mark <- "text"
    out$x <- aes_map[["x"]]
    out$y <- aes_map[["y"]]
    if (!is.null(aes_map[["label"]])) out$text <- aes_map[["label"]]
  } else {
    stop(sprintf(
      "DRAW %s is not supported by the Mosaic backend.",
      layer$type
    ))
  }

  # Pass-through settings keyed by recognised Mosaic channel names.
  passthrough <- c(
    "stroke", "strokeWidth", "strokeOpacity", "fillOpacity", "opacity",
    "z", "order", "reverse", "tip", "frameAnchor", "interval"
  )
  for (nm in names(settings)) {
    if (nm %in% passthrough && is.null(out[[nm]])) out[[nm]] <- settings[[nm]]
  }
  out
}

.ggsql_mosaic_place <- function(layer) {
  type <- layer$type
  settings <- layer$settings
  if (type %in% c("rule", "vline", "rulex")) {
    out <- list(mark = "ruleX")
    if (!is.null(settings[["x"]])) out$x <- settings[["x"]]
    if (!is.null(settings[["stroke"]]))      out$stroke <- settings[["stroke"]]
    if (!is.null(settings[["linetype"]]))    out$strokeDasharray <- .ggsql_linetype(settings[["linetype"]])
    if (!is.null(settings[["strokewidth"]])) out$strokeWidth <- settings[["strokewidth"]]
    out
  } else if (type %in% c("hline", "ruley")) {
    out <- list(mark = "ruleY")
    if (!is.null(settings[["y"]])) out$y <- settings[["y"]]
    if (!is.null(settings[["stroke"]]))      out$stroke <- settings[["stroke"]]
    if (!is.null(settings[["linetype"]]))    out$strokeDasharray <- .ggsql_linetype(settings[["linetype"]])
    if (!is.null(settings[["strokewidth"]])) out$strokeWidth <- settings[["strokewidth"]]
    out
  } else if (type == "text") {
    out <- list(mark = "text")
    for (nm in c("x", "y", "text", "fill", "frameAnchor")) {
      if (!is.null(settings[[nm]])) out[[nm]] <- settings[[nm]]
    }
    out
  } else {
    stop(sprintf("PLACE %s is not supported by the Mosaic backend.", type))
  }
}

.ggsql_linetype <- function(x) {
  if (is.numeric(x)) return(x)
  switch(
    tolower(x),
    "dotted" = "1 2",
    "dashed" = "4 2",
    "longdash" = "8 4",
    "twodash" = "2 2 6 2",
    "solid" = NULL,
    x
  )
}

.ggsql_mosaic_apply_scale <- function(spec, sc) {
  aes_ <- sc[["aesthetic"]]
  pal <- sc[["palette"]]
  if (aes_ %in% c("color", "fill")) {
    # log/sqrt are transforms, not palettes; everything else is a scheme
    if (tolower(pal) %in% c("log", "sqrt", "symlog", "linear")) {
      spec$colorScale <- pal
    } else {
      spec$colorScheme <- pal
    }
  } else if (aes_ %in% c("x", "y", "r", "size", "opacity")) {
    key <- paste0(aes_, "Scale")
    spec[[key]] <- pal
  } else {
    spec[[paste0(aes_, "Scale")]] <- pal
  }
  spec
}
