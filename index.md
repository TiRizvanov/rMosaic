# rMosaic

R bindings for the [Mosaic](https://github.com/uwdata/mosaic)
declarative visualization framework from UW IDL. Define linked,
interactive plots from R or Shiny — brushing, cross-filtering, pan/zoom,
and selection — backed by DuckDB for high-performance querying. Specs
can be written as JSON, YAML, or inline ESM/JavaScript.

The Mosaic JavaScript libraries (v0.21.1) and a DuckDB-WASM connector
are bundled inside the package under `inst/htmlwidgets/`, so the widget
renders without network access.

## Installation

Once on CRAN:

``` r

install.packages("rMosaic")
```

Development version from GitHub:

``` r

# install.packages("remotes")
remotes::install_github("TiRizvanov/rMosaic")
```

## Quick start

``` r

library(rMosaic)

df <- data.frame(
  x   = rnorm(200),
  y   = rnorm(200),
  grp = sample(LETTERS[1:3], 200, replace = TRUE)
)

spec <- '{
  "meta": { "title": "rMosaic demo" },
  "data": { "df": {} },
  "plot": [{
    "mark": "dot",
    "data": { "from": "df" },
    "x": "x", "y": "y", "fill": "grp"
  }],
  "width": 600, "height": 400
}'

runMosaicApp(
  spec     = spec,
  specType = "json",
  data     = list(df = df),
  title    = "rMosaic demo"
)
```

[`mosaic()`](https://tirizvanov.github.io/rMosaic/reference/mosaic.md)
accepts specs as an R list, a JSON or YAML character string, a file path
(`.json`, `.yaml`, `.js`, `.mjs`), or an inline ESM module via
`specType = "esm"`.

## Shiny integration

``` r

library(shiny)
library(rMosaic)

ui <- fluidPage(
  mosaicOutput("vis", width = "100%", height = "600px")
)

server <- function(input, output, session) {
  output$vis <- renderMosaic({
    mosaic(spec = spec, specType = "json", data = list(df = df))
  })
}

shinyApp(ui, server)
```

## Exporting selections back to R

[`runMosaicExport()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicExport.md)
(and
[`runMosaicWithExport()`](https://tirizvanov.github.io/rMosaic/reference/runMosaicWithExport.md))
launch the widget with an **Import Selection** button that pulls the
current brush back into R as a `data.frame`:

``` r

runMosaicExport(spec = spec, specType = "json", data = list(df = df))
```

## Learning more

The package ships several vignettes that walk through real-world
dashboards:

| Vignette                    | Topic                                  |
|-----------------------------|----------------------------------------|
| `getting-started`           | Core API and the spec lifecycle        |
| `format-json`, `format-esm` | Spec format options                    |
| `dynamic-rendering`         | Pan/zoom with on-the-fly binning       |
| `taxi-crossfilter`          | Multi-view dashboard, 1M+ rows         |
| `athletes-dashboard`        | Tables and linked selections           |
| `gaia-stars`                | Astronomy dataset, 5M points           |
| `protein-design-explorer`   | Marginal histograms, raster, and table |

Open any of them with, e.g.,
[`vignette("getting-started", package = "rMosaic")`](https://tirizvanov.github.io/rMosaic/articles/getting-started.md).

## Contributing

Issues and pull requests are welcome on
[GitHub](https://github.com/TiRizvanov/rMosaic/issues). Please report
bugs to the package maintainer listed in `DESCRIPTION`.

## License

MIT — see [LICENSE](https://tirizvanov.github.io/rMosaic/LICENSE) and
[LICENSE.md](https://tirizvanov.github.io/rMosaic/LICENSE.md) for the
full text, including the third-party Mosaic license bundled with the
JavaScript assets.

## Acknowledgements

Developed in the [Dries Lab](https://www.drieslab.com/) at Boston
University. Funding support was provided by the Dries Lab and the Boston
University Undergraduate Research Opportunities Program (UROP).
