# R/runMosaicApp.R

#' Run a Mosaic Shiny App in the RStudio Viewer
#'
#' @description
#' Launches a Shiny application displaying the Mosaic visualization.
#'
#' @inheritParams mosaic
#' @param title   Optional page title
#' @return A Shiny application object.
#' @export
runMosaicApp <- function(
    spec,
    specType = c("auto", "json", "yaml", "esm"),
    data,
    backend = c("r", "wasm"),
    title = NULL,
    width = "100%",
    height = "600px") {
  specType <- match.arg(specType)
  backend <- match.arg(backend)

  app_options <- list()
  if (
    requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::hasFun("viewer")
  ) {
    app_options$launch.browser <- rstudioapi::viewer
  }

  ui <- shiny::fluidPage(
    if (!is.null(title)) shiny::titlePanel(title),
    shiny::p(paste(
      "Using",
      ifelse(
        backend == "wasm",
        "WASM DuckDB (browser-side)",
        "R DuckDB (server-side)"
      ),
      "backend"
    )),
    mosaicOutput("mosaicPlot", width = width, height = height)
  )
  server <- function(input, output, session) {
    output$mosaicPlot <- renderMosaic({
      mosaic(
        spec = spec,
        specType = specType,
        data = data,
        backend = backend,
        width = width,
        height = height
      )
    })
  }
  shiny::shinyApp(ui, server, options = app_options)
}
