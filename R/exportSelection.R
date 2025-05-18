# R/exportSelection.R

#’ Run a Mosaic app and export brush/query selections back to R
#’ @inheritParams mosaic
#’ @param selection_env  where to store extracted selections
#’ @export
runMosaicExport <- function(
    spec, specType="auto", data,
    title=NULL, width="100%", height="600px",
    selection_env = .GlobalEnv
) {
  if (requireNamespace("rstudioapi", quietly=TRUE) &&
      rstudioapi::hasFun("viewer")) {
    options(shiny.launch.browser = rstudioapi::viewer)
  }

  ui <- shiny::fluidPage(
    if (!is.null(title)) shiny::titlePanel(title),
    mosaicOutput("viz", width=width, height=height),
    shiny::actionButton("export_sel","Import selection → R"),
    shiny::verbatimTextOutput("sel_status")
  )

  server <- function(input, output, session) {
    # render
    output$viz <- renderMosaic({
      mosaic(spec, specType, data, width=width, height=height)
    })

    # capture selection events
    session$onFlushed(function() {
      session$sendCustomMessage("mosaic_listen_sel", list())
    }, once=TRUE)

    # define handler from JS
    session$addCustomMessageHandler("mosaic_sel", function(msg) {
      session$userData$last_sel <<- msg  # store in session
    })

    # on button, extract SQL + run
    output$sel_status <- shiny::renderText({
      req(input$export_sel)
      sel <- session$userData$last_sel
      if (is.null(sel$sql)) return("No selection yet")
      # strip trailing ;
      sql <- gsub(";+$","",sel$sql)
      df  <- DBI::dbGetQuery(session$userData$mosaicConnections[[1]], sql)
      nm  <- store_mosaic_selection(df, selection_env)
      paste0("Stored ", nrow(df)," rows into `", nm, "`")
    })
  }

  shiny::shinyApp(ui, server)
}
