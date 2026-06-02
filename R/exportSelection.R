# R/exportSelection.R

#' Run a Mosaic app and export brush/query selections back to R
#'
#' @description
#' Runs a Mosaic app and allows exporting selections to R.
#'
#' @inheritParams mosaic
#' @param selection_env  where to store extracted selections
#' @param title Optional page title
#' @return A Shiny application object. When the user imports a selection, the
#'   selected rows are assigned into \code{selection_env} as
#'   \code{mosaic_sel_<n>}.
#' @export
runMosaicExport <- function(
    spec,
    specType = "auto",
    data,
    title = NULL,
    width = "100%",
    height = "600px",
    selection_env = NULL) {
  runMosaicWithExport(
    spec = spec,
    specType = specType,
    data = data,
    title = title,
    width = width,
    height = height,
    selection_env = selection_env
  )
}
