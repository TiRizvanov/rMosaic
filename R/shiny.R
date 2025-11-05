#' Shiny output for Mosaic widget
#'
#' Use this in the UI to create a placeholder for the Mosaic visualization.
#' @param outputId output variable name
#' @param width,height CSS dimensions (e.g. '100%', '400px') for the container.
#' @export
mosaicOutput <- function(outputId, width = "100%", height = "400px") {
  htmlwidgets::shinyWidgetOutput(outputId, "mosaic", width, height, package = "rMosaic")
}

#' Shiny render function for Mosaic
#'
#' Use this in the server to render the Mosaic visualization to the output.
#' @param expr An expression that generates a call to \code{\link{mosaic}()}.
#' @export
renderMosaic <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  htmlwidgets::shinyRenderWidget(expr, mosaicOutput, env, quoted = TRUE)
}
