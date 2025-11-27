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
#' @export
runMosaicWithExport <- function(
    spec,
    specType = c("auto", "json", "yaml", "esm"),
    data,
    title = NULL,
    width = "100%",
    height = "600px",
    selection_env = .GlobalEnv) {
  specType <- match.arg(specType)

  if (
    requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::hasFun("viewer")
  ) {
    options(shiny.launch.browser = rstudioapi::viewer)
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
            // Add debug info
            console.log("Trying to capture selection...");

            // Find the selection coordinates from the brush element
            const brushElement = document.querySelector(".mosaic-brush");
            if (!brushElement) {
              console.log("No brush element found");
              Shiny.setInputValue("selection_params", {
                error: "No brush selection found. Please make a selection first.",
                timestamp: new Date().getTime()
              });
              return;
            }

            // Get the brush coordinates
            const brushBox = brushElement.getBoundingClientRect();
            const plotElement = document.querySelector(".mark-dot");
            const plotBox = plotElement ? plotElement.parentElement.getBoundingClientRect() : null;

            if (!plotBox) {
              console.log("Could not find plot element");
              Shiny.setInputValue("selection_params", {
                error: "Could not find plot element",
                timestamp: new Date().getTime()
              });
              return;
            }

            // Calculate relative position in the plot
            const x1 = (brushBox.left - plotBox.left) / plotBox.width;
            const x2 = (brushBox.right - plotBox.left) / plotBox.width;
            const y1 = (plotBox.bottom - brushBox.bottom) / plotBox.height;
            const y2 = (plotBox.bottom - brushBox.top) / plotBox.height;

            console.log("Brush coordinates:", x1, x2, y1, y2);

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
            console.log("Table rows found:", tableRows.length);

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
                  console.log("Sent indices:", selectedIndices);
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

    # Extract domain info from spec
    observe({
      if (is.list(spec) && "params" %in% names(spec)) {
        if ("plddt_domain" %in% names(spec$params)) {
          x_domain <- spec$params$plddt_domain
          shiny::reactiveValues(x_min = x_domain[1], x_max = x_domain[2])
        }
        if ("pae_domain" %in% names(spec$params)) {
          y_domain <- spec$params$pae_domain
          shiny::reactiveValues(y_min = y_domain[1], y_max = y_domain[2])
        }
      }
    })

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
        message(msg)
        return()
      }

      # Get name of first table in data
      table_name <- names(all_data)[1]
      if (is.null(table_name)) {
        msg <- "No data table found"
        selection_status(msg)
        message(msg)
        return()
      }

      # Get the table data
      df <- all_data[[table_name]]

      # Get X and Y column names from spec
      x_col <- NULL
      y_col <- NULL

      # Extract column names from the spec
      if (
        is.list(spec) && "vconcat" %in% names(spec) && length(spec$vconcat) > 0
      ) {
        for (section in spec$vconcat) {
          if (
            is.list(section) &&
              "hconcat" %in% names(section) &&
              length(section$hconcat) > 0
          ) {
            for (item in section$hconcat) {
              if (
                is.list(item) &&
                  "plot" %in% names(item) &&
                  length(item$plot) > 0
              ) {
                for (plot_item in item$plot) {
                  if (
                    is.list(plot_item) &&
                      "mark" %in% names(plot_item) &&
                      plot_item$mark == "dot"
                  ) {
                    if (
                      "x" %in% names(plot_item) && is.character(plot_item$x)
                    ) {
                      x_col <- plot_item$x
                    }
                    if (
                      "y" %in% names(plot_item) && is.character(plot_item$y)
                    ) {
                      y_col <- plot_item$y
                    }
                  }
                }
              }
            }
          }
        }
      }

      # If we couldn't find the column names, try to guess from the table structure
      if (is.null(x_col) || is.null(y_col)) {
        # Default to first two numeric columns
        numeric_cols <- sapply(df, is.numeric)
        if (sum(numeric_cols) >= 2) {
          x_col <- names(df)[which(numeric_cols)][1]
          y_col <- names(df)[which(numeric_cols)][2]
        } else {
          msg <- "Could not determine X and Y columns"
          selection_status(msg)
          message(msg)
          return()
        }
      }

      # Get domain from spec or calculate from data
      x_min <- if (exists("x_min")) x_min else min(df[[x_col]], na.rm = TRUE)
      x_max <- if (exists("x_max")) x_max else max(df[[x_col]], na.rm = TRUE)
      y_min <- if (exists("y_min")) y_min else min(df[[y_col]], na.rm = TRUE)
      y_max <- if (exists("y_max")) y_max else max(df[[y_col]], na.rm = TRUE)

      # Map the relative brush coordinates to data values
      x1_val <- x_min + params$x1 * (x_max - x_min)
      x2_val <- x_min + params$x2 * (x_max - x_min)
      y1_val <- y_min + params$y1 * (y_max - y_min)
      y2_val <- y_min + params$y2 * (y_max - y_min)

      # Check if we have valid brush coordinates
      if (any(is.na(c(x1_val, x2_val, y1_val, y2_val)))) {
        msg <- "Invalid brush coordinates"
        selection_status(msg)
        message(msg)
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
        message(msg)
      } else if (nrow(selected_df) == 0) {
        msg <- "No data points in selection area"
        selection_status(msg)
        message(msg)
      } else {
        msg <- "Full dataset selected, not importing"
        selection_status(msg)
        message(msg)
      }
    })

    # Handle table indices if available
    observeEvent(input$table_indices, {
      indices <- input$table_indices$indices

      if (!is.null(indices) && length(indices) > 0) {
        # Get name of first table in data
        table_name <- names(all_data)[1]
        if (!is.null(table_name)) {
          df <- all_data[[table_name]]

          # Check if indices are valid
          if (max(indices) <= nrow(df)) {
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
              message(msg)
            } else {
              msg <- "Full dataset selected, not importing"
              selection_status(msg)
              message(msg)
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

  shiny::shinyApp(ui, server)
}
