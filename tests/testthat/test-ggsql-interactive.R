test_that("DRAW intervalxy compiles to a Mosaic interactor + auto-named param", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW point DRAW intervalxy"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_length(spec$plot, 2L)
  expect_equal(spec$plot[[2]]$select, "intervalXY")
  expect_equal(spec$plot[[2]]$as, "$brush_1")
  expect_equal(spec$params$brush_1$select, "intersect")
})

test_that("SETTING as => 'name' on interactor sets the param key", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW point DRAW intervalx SETTING as => 'mybrush'"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[2]]$select, "intervalX")
  expect_equal(spec$plot[[2]]$as, "$mybrush")
  expect_equal(spec$params$mybrush$select, "intersect")
})

test_that("SETTING type => 'crossfilter' overrides the param selection kind", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW point DRAW intervalxy SETTING type => 'crossfilter'"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$params$brush_1$select, "crossfilter")
})

test_that("SETTING filterby => 'name' adds filterBy to a layer", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW point SETTING filterby => 'sel' DRAW intervalxy SETTING as => 'sel'"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[1]]$data$filterBy, "$sel")
  expect_equal(spec$plot[[2]]$as, "$sel")
})

test_that("aliases (brush_x/brush_y/brush_xy) resolve to the right select type", {
  for (kw_type in list(
    c("brush_x", "intervalX"),
    c("brush_y", "intervalY"),
    c("brush_xy", "intervalXY")
  )) {
    ir <- rMosaic:::.parse_ggsql(
      sprintf("VISUALIZE x AS x, y AS y FROM t DRAW point DRAW %s", kw_type[1])
    )
    spec <- rMosaic:::.ggsql_compile_mosaic(ir)
    expect_equal(spec$plot[[2]]$select, kw_type[2],
                 info = paste("alias:", kw_type[1]))
  }
})
