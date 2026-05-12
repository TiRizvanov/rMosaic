# R/exportSelection.R

#' Run a Mosaic app and export brush/query selections back to R
#'
#' @description
#' Runs a Mosaic app and allows exporting selections to R.
#'
#' @inheritParams mosaic
#' @param selection_env  where to store extracted selections
#' @param title Optional page title
#' @export
runMosaicExport <- function(
    spec,
    specType = "auto",
    data,
    title = NULL,
    width = "100%",
    height = "600px",
    selection_env = .GlobalEnv) {
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
