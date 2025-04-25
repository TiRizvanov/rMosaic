# mosaicShiny

**mosaicShiny** embeds the [Mosaic](https://github.com/uwdata/mosaic) declarative visualization framework in R and Shiny, letting you define interactive, data-driven plots via JSON, YAML, or inline ESM specs and back them with DuckDB for high-performance querying.

---

## Features

- **Declarative specs** in JSON, YAML, or inline ESM/JS  
- **Automatic DuckDB** setup and data loading (in-memory or on-disk)  
- **Scalable**, server-driven queries via Shiny → DuckDB → Mosaic  
- **Linked interactions**: brushing, cross-filtering, pan/zoom, selection  
- **Flexible data sources**: R data.frames, Parquet/CSV files, SQL queries  
- **Zero JavaScript** required to get started  

---

## Installation

```r
# If you are in the package directory:
install.packages("mosaicShiny")

# Or install development version from GitHub:
# install.packages("remotes")
remotes::install_github("TiRizvanov/mosaicShiny")
```

---

## Quick Start

```r
library(mosaicShiny)

# Prepare a small data.frame
df <- data.frame(
  x = rnorm(200),
  y = rnorm(200),
  grp = sample(LETTERS[1:3], 200, TRUE)
)

# A simple dot-plot spec in JSON
spec_json <- '{
  "meta": {
    "title": "Iris-like Demo"
  },
  "data": {
    "df": {}
  },
  "plot": [
    {
      "mark": "dot",
      "data": {"from": "df"},
      "x": "x",
      "y": "y",
      "fill": "grp"
    }
  ],
  "width": 600,
  "height": 400
}'

# Run in the viewer
runMosaicApp(
  spec     = spec_json,
  specType = "json",
  data     = list(df = df),
  title    = "mosaicShiny Demo"
)
```

---

## Spec Formats

You can provide your spec as:

- **R list** (JSON/YAML)  
- **Character string** (inline JSON or YAML)  
- **File path** (`.json`, `.yaml`, `.js`/`.mjs` for ESM)  
- **Inline ESM** (raw JS module text via `specType = "esm"`)

See the [examples directory](./inst/examples) for many ready-to-run demos:
- Voronoi & Delaunay  
- Sortable, infinite-scroll tables  
- Contour/heatmap sliders  
- SPLOM with linked brushing  
- Map & histogram cross-filter (NYC taxis)  
- And more…

---

## Shiny Integration

Use in any Shiny app:

```r
ui <- fluidPage(
  mosaicOutput("vis", width="100%", height="600px")
)
server <- function(input, output, session) {
  output$vis <- renderMosaic({
    mosaic(
      spec     = spec_json,
      specType = "json",
      data     = list(df = df),
      width    = "100%",
      height   = "600px"
    )
  })
}
shinyApp(ui, server)
```

---

## Exporting Selections

If you need to pull back brush selections into R, use the `runMosaicExport()` helper:

```r
runMosaicExport(
  spec       = spec_json,
  specType   = "json",
  data       = list(df = df),
  title      = "Export Demo"
)
```

Click the **Import Selection** button to grab the current brush as an R data.frame.

---

## Development

- **Test**: `devtools::test()`  
- **Lint**: `lintr::lint_package()`  
- **Build**: `devtools::build()`  
- **Check**: `devtools::check()`  

We recommend using the [`usethis`](https://cran.r-project.org/package=usethis) and [`devtools`](https://cran.r-project.org/package=devtools) packages for a smooth workflow.

---

## Contributing

1. Fork the repo  
2. Create a feature branch  
3. Write code + tests  
4. Submit a PR  

Please file any issues on [GitHub Issues](https://github.com/yourusername/mosaicShiny/issues).

---

## License

MIT © Your Name or Organization  
See [LICENSE](./LICENSE) for details.
```

**Notes**  
- Update all placeholder links (e.g. `yourusername`) to your actual GitHub account or package URLs.  
- Expand the **Examples** section with specifics of the demos you include.  
- If you publish to CRAN, include CRAN badges and documentation links at the top.
