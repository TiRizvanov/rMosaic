test_that("parser returns NULL when VISUALIZE is absent", {
  expect_null(rMosaic:::.parse_ggsql("SELECT * FROM penguins"))
})

test_that("parser extracts aesthetics and FROM source", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE bill_len AS x, bill_dep AS y FROM penguins DRAW point"
  )
  expect_equal(ir$from, "penguins")
  expect_equal(ir$aesthetics$x, "bill_len")
  expect_equal(ir$aesthetics$y, "bill_dep")
  expect_length(ir$layers, 1L)
  expect_equal(ir$layers[[1]]$type, "point")
})

test_that("parser keeps base SELECT and binds SETTING to its layer", {
  sql <- paste(
    "WITH astro AS (SELECT * FROM 'astro.parquet')",
    "SELECT *, year_of_selection - year_of_birth AS age FROM astro",
    "VISUALIZE age AS x, category AS fill",
    "DRAW histogram SETTING binwidth => 1, position => 'identity'",
    "PLACE rule SETTING x => (34, 44), linetype => 'dotted'",
    "SCALE fill TO accent",
    "LABEL title => 'Astronaut Ages'",
    sep = " "
  )
  ir <- rMosaic:::.parse_ggsql(sql)
  expect_match(ir$base_sql, "WITH astro AS")
  expect_equal(ir$layers[[1]]$settings$binwidth, 1)
  expect_equal(ir$layers[[1]]$settings$position, "identity")
  expect_equal(ir$layers[[2]]$type, "rule")
  expect_equal(ir$layers[[2]]$settings$x, list(34, 44))
  expect_equal(ir$scales[[1]]$palette, "accent")
  expect_equal(ir$labels$title, "Astronaut Ages")
})

test_that("top-level SETTING (before DRAW) parses separately from layer SETTING", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t SETTING width => 800 DRAW point SETTING size => 3"
  )
  expect_equal(ir$settings$width, 800)
  expect_equal(ir$layers[[1]]$settings$size, 3)
})

test_that("compile produces a Mosaic plot spec with the expected mark", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE bill_len AS x, bill_dep AS y, species AS color FROM penguins DRAW point"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[1]]$mark, "dot")
  expect_equal(spec$plot[[1]]$fill, "species")
  expect_equal(spec$plot[[1]]$data$from, "penguins")
})

test_that("histogram compiles with binwidth", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE age AS x FROM t DRAW histogram SETTING binwidth => 2"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[1]]$mark, "rectY")
  expect_equal(spec$plot[[1]]$x$bin, "age")
  expect_equal(spec$plot[[1]]$x$step, 2)
})

test_that("PLACE rule compiles to ruleX with dasharray", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE age AS x FROM t DRAW histogram PLACE rule SETTING x => (10, 20), linetype => 'dashed'"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$plot[[2]]$mark, "ruleX")
  expect_equal(spec$plot[[2]]$x, list(10, 20))
  expect_equal(spec$plot[[2]]$strokeDasharray, "4 2")
})

test_that("SCALE fill TO accent sets colorScheme", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, c AS fill FROM t DRAW bar SCALE fill TO accent"
  )
  spec <- rMosaic:::.ggsql_compile_mosaic(ir)
  expect_equal(spec$colorScheme, "accent")
})

test_that("LABEL x/y populate top-level keys; title emits a message and is skipped", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW point LABEL title => 'T', x => 'XL', y => 'YL'"
  )
  expect_message(
    spec <- rMosaic:::.ggsql_compile_mosaic(ir),
    "Mosaic has no native plot title"
  )
  expect_null(spec$title)
  expect_equal(spec$xLabel, "XL")
  expect_equal(spec$yLabel, "YL")
})

test_that("unsupported DRAW types raise a clear error", {
  ir <- rMosaic:::.parse_ggsql(
    "VISUALIZE x AS x, y AS y FROM t DRAW polygon"
  )
  expect_error(
    rMosaic:::.ggsql_compile_mosaic(ir),
    "not supported by the Mosaic backend"
  )
})

test_that("missing data source errors out", {
  ir <- rMosaic:::.parse_ggsql("VISUALIZE x AS x DRAW point")
  expect_error(
    rMosaic:::.ggsql_compile_mosaic(ir),
    "requires a data source"
  )
})
