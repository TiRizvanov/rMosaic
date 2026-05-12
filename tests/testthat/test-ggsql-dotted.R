test_that("rename rewrites both data.frame columns and aesthetics", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE Sepal.Length AS x, Sepal.Width AS y FROM iris DRAW point"
  )
  data <- list(iris = head(iris, 3))
  prep <- rMosaic:::.ggsql_mosaic_rename_dotted(ir, data)
  expect_equal(prep$ir$aesthetics$x, "Sepal_Length")
  expect_equal(prep$ir$aesthetics$y, "Sepal_Width")
  expect_true("Sepal_Length" %in% names(prep$data$iris))
  expect_false("Sepal.Length" %in% names(prep$data$iris))
})

test_that("rename is a no-op when no aesthetic contains a dot", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW point"
  )
  data <- list(t = data.frame(x = 1, y = 2))
  prep <- rMosaic:::.ggsql_mosaic_rename_dotted(ir, data)
  expect_identical(prep$ir, ir)
  expect_identical(prep$data, data)
})

test_that("rename warns when dotted columns are present but no data is supplied", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE Sepal.Length AS x FROM iris DRAW point"
  )
  expect_warning(
    rMosaic:::.ggsql_mosaic_rename_dotted(ir, NULL),
    "Pass `data = list"
  )
})

test_that("compile still produces the standard data: {from: ...} reference", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM iris DRAW point"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[1]]$data$from, "iris")
  expect_null(spec$data)
})
