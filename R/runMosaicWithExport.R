#' @importFrom shiny observe observeEvent
NULL

#' Run a Mosaic Shiny App with selection export
#'
#' @description
#' Launches a Shiny application that allows selecting data points and exporting them to an R environment.
#'
#' @inheritParams mosaic
#' @param title Optional page title
#' @param selection_env Environment to store selections in
#' @return A Shiny application object. When the user imports a selection, the
#'   selected rows are assigned into \code{selection_env} as
#'   \code{mosaic_sel_<n>}.
#' @export
runMosaicWithExport <- function(
    spec,
    specType = c("auto", "json", "yaml", "esm"),
    data,
    title = NULL,
    width = "100%",
    height = "600px",
    selection_env = NULL) {
  specType <- match.arg(specType)

  app_options <- list()
  if (
    requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::hasFun("viewer")
  ) {
    app_options$launch.browser <- rstudioapi::viewer
  }

  # Clone the data to keep a reference
  all_data <- data

  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$script(shiny::HTML(
        '
        $(document).ready(function() {
          // Function to capture brush state from Mosaic
          window.captureSelection = function() {
            const brushElement = document.querySelector(
              ".mosaic-brush, [class*=brush][class*=selection], [aria-label*=brush]"
            );
            if (!brushElement) {
              Shiny.setInputValue("selection_params", {
                error: "No Mosaic brush selection was found. Draw an interval selection before importing.",
                timestamp: new Date().getTime()
              });
              return;
            }

            // Get the brush coordinates
            const brushBox = brushElement.getBoundingClientRect();
            const plotElement = document.querySelector(".mark-dot, svg[aria-label], svg");
            const plotBox = plotElement ? plotElement.parentElement.getBoundingClientRect() : null;

            if (!plotBox) {
              Shiny.setInputValue("selection_params", {
                error: "Could not locate the Mosaic plot element for coordinate mapping.",
                timestamp: new Date().getTime()
              });
              return;
            }

            // Calculate relative position in the plot
            const x1 = (brushBox.left - plotBox.left) / plotBox.width;
            const x2 = (brushBox.right - plotBox.left) / plotBox.width;
            const y1 = (plotBox.bottom - brushBox.bottom) / plotBox.height;
            const y2 = (plotBox.bottom - brushBox.top) / plotBox.height;

            // Send the brush coordinates to R
            Shiny.setInputValue("selection_params", {
              x1: x1,
              x2: x2,
              y1: y1,
              y2: y2,
              timestamp: new Date().getTime()
            });

            // Also try to get selected points from table
            const tableRows = document.querySelectorAll("[data-mosaic-input=table] tbody tr");

            if (tableRows && tableRows.length > 0) {
              try {
                const selectedIndices = [];

                tableRows.forEach(function(row, index) {
                  selectedIndices.push(index);
                });

                if (selectedIndices.length > 0) {
                  Shiny.setInputValue("table_indices", {
                    indices: selectedIndices,
                    timestamp: new Date().getTime()
                  });
                }
              } catch(e) {
                console.error("Error processing table:", e);
              }
            }
          };
        });
      '
      ))
    ),
    if (!is.null(title)) shiny::titlePanel(title),
    shiny::fluidRow(
      shiny::column(
        12,
        mosaicOutput("mosaicPlot", width = width, height = height)
      )
    ),
    shiny::fluidRow(
      shiny::column(
        12,
        align = "center",
        shiny::br(),
        shiny::actionButton(
          "importSelectionBtn",
          "Import Selection to R",
          onclick = "window.captureSelection()"
        ),
        shiny::verbatimTextOutput("selectionStatus")
      )
    )
  )

  server <- function(input, output, session) {
    # Render Mosaic plot
    output$mosaicPlot <- renderMosaic({
      mosaic(
        spec = spec,
        specType = specType,
        data = data,
        width = width,
        height = height
      )
    })

    # Status message reactive
    selection_status <- shiny::reactiveVal("No selection imported yet")

    # Handle brush coordinates from JavaScript
    observeEvent(input$selection_params, {
      params <- input$selection_params

      if (is.null(params) || !is.null(params$error)) {
        msg <- if (!is.null(params$error)) {
          params$error
        } else {
          "No selection parameters received"
        }
        selection_status(msg)
        return()
      }

      table_info <- tryCatch(
        .mosaic_first_data_frame(all_data),
        error = function(e) e
      )
      if (inherits(table_info, "error")) {
        selection_status(conditionMessage(table_info))
        return()
      }
      df <- table_info$data

      xy_cols <- .mosaic_find_xy_columns(spec, df)
      if (is.null(xy_cols)) {
        selection_status("Could not determine numeric X and Y columns from the Mosaic spec or data.")
        return()
      }
      x_col <- xy_cols$x
      y_col <- xy_cols$y

      # Calculate domains from the data currently registered with the widget.
      x_min <- min(df[[x_col]], na.rm = TRUE)
      x_max <- max(df[[x_col]], na.rm = TRUE)
      y_min <- min(df[[y_col]], na.rm = TRUE)
      y_max <- max(df[[y_col]], na.rm = TRUE)

      # Map the relative brush coordinates to data values
      x1_val <- x_min + params$x1 * (x_max - x_min)
      x2_val <- x_min + params$x2 * (x_max - x_min)
      y1_val <- y_min + params$y1 * (y_max - y_min)
      y2_val <- y_min + params$y2 * (y_max - y_min)

      # Check if we have valid brush coordinates
      if (anyNA(c(x1_val, x2_val, y1_val, y2_val))) {
        msg <- "Invalid brush coordinates"
        selection_status(msg)
        return()
      }

      # Filter the data frame based on the brush
      selected_df <- df[
        df[[x_col]] >= x1_val &
          df[[x_col]] <= x2_val &
          df[[y_col]] >= y1_val &
          df[[y_col]] <= y2_val,
      ]

      # Make sure we didn't select the whole dataset
      if (nrow(selected_df) < nrow(df) && nrow(selected_df) > 0) {
        # Store the selection
        selection_name <- store_mosaic_selection(selected_df, selection_env)

        # Update status
        msg <- paste0(
          "Selection imported to R as '",
          selection_name,
          "' with ",
          nrow(selected_df),
          " rows"
        )
        selection_status(msg)
      } else if (nrow(selected_df) == 0) {
        msg <- "No data points in selection area"
        selection_status(msg)
      } else {
        msg <- "Full dataset selected, not importing"
        selection_status(msg)
      }
    })

    # Handle table indices if available
    observeEvent(input$table_indices, {
      indices <- input$table_indices$indices

      if (!is.null(indices) && length(indices) > 0) {
        table_info <- tryCatch(
          .mosaic_first_data_frame(all_data),
          error = function(e) e
        )
        if (!inherits(table_info, "error")) {
          df <- table_info$data

          # Check if indices are valid
          if (max(indices) < nrow(df)) {
            # Get rows by index
            selected_df <- df[indices + 1, ] # +1 for R's 1-based indexing

            if (nrow(selected_df) < nrow(df)) {
              # Store the selection
              selection_name <- store_mosaic_selection(
                selected_df,
                selection_env
              )

              # Update status
              msg <- paste0(
                "Selection imported to R as '",
                selection_name,
                "' with ",
                nrow(selected_df),
                " rows"
              )
              selection_status(msg)
            } else {
              msg <- "Full dataset selected, not importing"
              selection_status(msg)
            }
          }
        }
      }
    })

    # Display selection status
    output$selectionStatus <- shiny::renderText({
      selection_status()
    })
  }

  shiny::shinyApp(ui, server, options = app_options)
}
