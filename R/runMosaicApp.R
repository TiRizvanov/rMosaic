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
    title   = NULL,
    width   = "100%",
    height  = "600px"
) {
  specType <- match.arg(specType)

  if (requireNamespace("rstudioapi", quietly=TRUE) &&
      rstudioapi::hasFun("viewer")
  ) {
    options(shiny.launch.browser = rstudioapi::viewer)
  }

  ui <- shiny::fluidPage(
    if (!is.null(title)) shiny::titlePanel(title),
    mosaicOutput("mosaicPlot", width = width, height = height)
  )
  server <- function(input, output, session) {
    output$mosaicPlot <- renderMosaic({
      mosaic(
        spec     = spec,
        specType = specType,
        data     = data,
        width    = width,
        height   = height
      )
    })
  }
  shiny::shinyApp(ui, server)
}
