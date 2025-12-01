# R/runMosaicApp.R

#' Run a Mosaic Shiny App in the RStudio Viewer
#'
#' @inheritParams mosaic
#' @param title   Optional page title
#' @export
runMosaicApp <- function(
  spec,
  specType = c("auto", "json", "yaml", "esm"),
  data,
  backend = c("r", "wasm"),
  extensions = NULL,
  title = NULL,
  width = "100%",
  height = "600px"
) {
  specType <- match.arg(specType)
  backend <- match.arg(backend)

  if (
    requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::hasFun("viewer")
  ) {
    options(shiny.launch.browser = rstudioapi::viewer)
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
        extensions = extensions,
        width = width,
        height = height
      )
    })
  }
  shiny::shinyApp(ui, server)
}
