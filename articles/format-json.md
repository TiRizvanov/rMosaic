# Using JSON Format

## Introduction

This vignette demonstrates how to define Mosaic visualizations using
JSON format. JSON is useful when working with external specifications or
generating specs programmatically.

## Example: Voronoi Diagram with JSON

This is the same voronoi diagram from the getting-started vignette, but
defined using JSON format:

``` r

library(rMosaic)

# Generate synthetic penguins dataset
set.seed(42)
penguins_df <- data.frame(
  bill_length = rnorm(150, mean = 40, sd = 5),
  bill_depth  = rnorm(150, mean = 18, sd = 3),
  species     = sample(c("Adelie", "Gentoo", "Chinstrap"), 150, replace = TRUE)
)

# Define YAML spec first (as R list)
voronoi_yaml <- list(
  params = list(
    mesh = 0,
    hull = 0
  ),
  vconcat = list(
    list(
      plot = list(
        list(
          mark = "voronoi",
          data = list(from = "penguins"),
          x = "bill_length",
          y = "bill_depth",
          stroke = "white",
          strokeWidth = 1,
          strokeOpacity = 0.5,
          fill = "species",
          fillOpacity = 0.2
        ),
        list(
          mark = "hull",
          data = list(from = "penguins"),
          x = "bill_length",
          y = "bill_depth",
          stroke = "species",
          strokeOpacity = "$hull",
          strokeWidth = 1.5
        ),
        list(
          mark = "delaunayMesh",
          data = list(from = "penguins"),
          x = "bill_length",
          y = "bill_depth",
          z = "species",
          stroke = "species",
          strokeOpacity = "$mesh",
          strokeWidth = 1
        ),
        list(
          mark = "dot",
          data = list(from = "penguins"),
          x = "bill_length",
          y = "bill_depth",
          fill = "species",
          r = 2
        ),
        list(mark = "frame")
      ),
      width  = 680,
      height = 480
    ),
    list(
      hconcat = list(
        list(
          input   = "menu",
          label   = "Delaunay Mesh",
          options = list(
            list(value = 0,   label = "Hide"),
            list(value = 0.5, label = "Show")
          ),
          as = "$mesh"
        ),
        list(hspace = 5),
        list(
          input   = "menu",
          label   = "Convex Hull",
          options = list(
            list(value = 0, label = "Hide"),
            list(value = 1, label = "Show")
          ),
          as = "$hull"
        )
      )
    )
  )
)

# Convert to JSON string
voronoi_json <- jsonlite::toJSON(voronoi_yaml, auto_unbox = TRUE, pretty = TRUE)

# Run the application with JSON spec
runMosaicApp(
  spec     = voronoi_json,
  specType = "json",
  data     = list(penguins = penguins_df),
  title    = "Voronoi Diagram (JSON)"
)
```

## Working with JSON

You can also load JSON from a file:

``` r

# Save spec to file
writeLines(voronoi_json, "voronoi_spec.json")

# Load and use
json_spec <- readLines("voronoi_spec.json")
runMosaicApp(
  spec     = paste(json_spec, collapse = "\n"),
  specType = "json",
  data     = list(penguins = penguins_df),
  title    = "Voronoi from File"
)
```

## When to Use JSON

- Loading specs from external files or APIs
- Generating specs programmatically
- Sharing specs with non-R users
- Version controlling specifications separately from R code

**Note:** YAML format (R lists) is generally more convenient for
defining specs directly in R code, as shown in the getting-started
vignette.
