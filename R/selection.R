# R/selection.R

# ’ Persist a data.frame into an R environment
# ’ @param df    data.frame to store
# ’ @param env   environment (default .GlobalEnv)
# ’ @return name of the variable created
store_mosaic_selection <- function(df, env = .GlobalEnv) {
  if (!exists(".mosaic_sel_counter", envir = env)) {
    assign(".mosaic_sel_counter", 0, envir = env)
  }
  cnt <- get(".mosaic_sel_counter", envir = env) + 1
  assign(".mosaic_sel_counter", cnt, envir = env)
  nm <- paste0("mosaic_sel_", cnt)
  assign(nm, df, envir = env)
  nm
}
