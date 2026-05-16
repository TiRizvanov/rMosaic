# Protein Design Explorer

## Introduction

This vignette adapts the Mosaic [Protein Design
Explorer](https://idl.uw.edu/mosaic/examples/protein-design.html)
example for rMosaic. It explores synthesized protein minibinders
generated via RFDiffusion and combines:

- Menus for process parameters
- Marginal histograms for pLDDT and pAE
- A raster scatterplot for dense protein design metrics
- A linked table for inspecting selected designs

For pAE, lower values are better. For pLDDT, higher values are better.

**Note:** This example uses a remote Parquet file and may take a few
seconds to load.

## Example: Protein Design Explorer

``` r

library(rMosaic)

protein_data_url <- "https://idl.uw.edu/mosaic/data/protein-design.parquet"

protein_spec <- list(
  meta = list(
    title = "Protein Design Explorer",
    description = paste(
      "Explore synthesized proteins generated via RFDiffusion.",
      "Minibinders are small proteins that bind to a specific protein target.",
      "The dashboard links parameter menus, marginal histograms, a pLDDT vs. pAE raster plot, and a table of selected designs.",
      sep = "\n\n"
    ),
    credit = paste(
      "Adapted from a UW CSE 512 project by Christina Savvides,",
      "Alexander Shida, Riti Biswas, and Nora McNamara-Bordewick.",
      "Data from the UW Institute for Protein Design."
    )
  ),
  data = list(
    proteins = list(file = protein_data_url)
  ),
  params = list(
    query = list(select = "crossfilter"),
    point = list(select = "intersect", empty = TRUE),
    plddt_domain = c(67, 94.5),
    pae_domain = c(5, 29),
    scheme = "observable10"
  ),
  vconcat = list(
    # Parameter menus filter all downstream views.
    list(
      hconcat = list(
        list(
          input = "menu",
          from = "proteins",
          column = "partial_t",
          label = "Partial t",
          as = "$query"
        ),
        list(
          input = "menu",
          from = "proteins",
          column = "noise",
          label = "Noise",
          as = "$query"
        ),
        list(
          input = "menu",
          from = "proteins",
          column = "gradient_decay_function",
          label = "Gradient Decay",
          as = "$query"
        ),
        list(
          input = "menu",
          from = "proteins",
          column = "gradient_scale",
          label = "Gradient Scale",
          as = "$query"
        )
      )
    ),
    list(vspace = "1.5em"),
    # Top marginal histogram for pLDDT.
    list(
      hconcat = list(
        list(
          plot = list(
            list(
              mark = "rectY",
              data = list(from = "proteins", filterBy = "$query"),
              x = list(bin = "plddt_total", steps = 60),
              y = list(count = NULL),
              z = "version",
              fill = "version",
              order = "z",
              reverse = TRUE,
              insetLeft = 0.5,
              insetRight = 0.5
            )
          ),
          width = 600,
          height = 55,
          xAxis = NULL,
          yAxis = NULL,
          xDomain = "$plddt_domain",
          colorDomain = "Fixed",
          colorScheme = "$scheme",
          marginLeft = 40,
          marginRight = 0,
          marginTop = 0,
          marginBottom = 0
        ),
        list(hspace = 5),
        list(
          legend = "color",
          `for` = "scatter",
          columns = 1,
          as = "$query"
        )
      )
    ),
    # Main raster scatterplot plus right marginal histogram for pAE.
    list(
      hconcat = list(
        list(
          name = "scatter",
          plot = list(
            list(mark = "frame", stroke = "#ccc"),
            list(
              mark = "raster",
              data = list(from = "proteins", filterBy = "$query"),
              x = "plddt_total",
              y = "pae_interaction",
              fill = "version",
              pad = 0
            ),
            list(
              select = "intervalXY",
              as = "$query",
              brush = list(stroke = "currentColor", fill = "transparent")
            ),
            list(
              mark = "dot",
              data = list(from = "proteins", filterBy = "$point"),
              x = "plddt_total",
              y = "pae_interaction",
              fill = "version",
              stroke = "currentColor",
              strokeWidth = 0.5
            )
          ),
          opacityDomain = c(0, 2),
          opacityClamp = TRUE,
          colorDomain = "Fixed",
          colorScheme = "$scheme",
          xDomain = "$plddt_domain",
          yDomain = "$pae_domain",
          xLabelAnchor = "center",
          yLabelAnchor = "center",
          marginTop = 0,
          marginLeft = 40,
          marginRight = 0,
          width = 600,
          height = 450
        ),
        list(
          plot = list(
            list(
              mark = "rectX",
              data = list(from = "proteins", filterBy = "$query"),
              x = list(count = NULL),
              y = list(bin = "pae_interaction", steps = 60),
              z = "version",
              fill = "version",
              order = "z",
              reverse = TRUE,
              insetTop = 0.5,
              insetBottom = 0.5
            )
          ),
          width = 55,
          height = 450,
          xAxis = NULL,
          yAxis = NULL,
          marginTop = 0,
          marginLeft = 0,
          marginRight = 0,
          yDomain = "$pae_domain",
          colorDomain = "Fixed",
          colorScheme = "$scheme"
        )
      )
    ),
    list(vspace = "1em"),
    list(
      input = "table",
      as = "$point",
      filterBy = "$query",
      from = "proteins",
      columns = c(
        "version",
        "pae_interaction",
        "plddt_total",
        "noise",
        "gradient_decay_function",
        "gradient_scale",
        "movement"
      ),
      width = 680,
      height = 215
    )
  )
)

runMosaicApp(
  spec = protein_spec,
  specType = "yaml",
  data = NULL,
  title = "Protein Design Explorer",
  backend = "wasm",
  height = "900px"
)
```

## Key Features

### Crossfilter Menus and Brushing

The `query` parameter uses `select = "crossfilter"`, so menus and the
scatterplot brush all contribute to a single linked filter.

### Dense Metric View

The central `raster` mark aggregates tens of thousands of protein
designs by `plddt_total` and `pae_interaction`, colored by design
`version`.

### Marginal Distributions

The top and right histograms use the same `query` filter as the central
plot, making it easier to compare pLDDT and pAE distributions after
filtering by process parameters.

### Linked Table

The table is filtered by the current query and writes to a separate
`point` selection. Hovering or selecting table rows highlights
corresponding records in the scatterplot.

## Try It Yourself

1.  Select values from the parameter menus to compare design settings.
2.  Brush the lower-right region of the scatterplot to focus on low pAE
    and high pLDDT designs.
3.  Inspect the linked table to see parameter values for promising
    designs.
