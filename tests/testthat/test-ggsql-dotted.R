test_that("dotted column names get aliased through a vis_source CTE", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE Sepal.Length AS x, Sepal.Width AS y, Species AS color FROM iris DRAW point DRAW smooth"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[1]]$x, "Sepal_Length")
  expect_equal(spec$plot[[1]]$y, "Sepal_Width")
  expect_match(spec$data$vis_source, '"Sepal.Length" AS "Sepal_Length"')
  expect_match(spec$data$vis_source, "FROM iris")
})

test_that("aliasing wraps an existing base SELECT instead of clobbering it", {
  ir <- rMosaic:::.parse_ggsql(
    "SELECT * FROM raw WHERE keep VISUALIZE Sepal.Length AS x, Sepal.Width AS y DRAW point"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_match(spec$data$vis_source, "FROM \\(SELECT \\* FROM raw WHERE keep\\) AS raw_src")
})
