# Olympic Athletes Dashboard

## Introduction

This vignette demonstrates a comprehensive dashboard combining multiple
input widgets, scatterplot with brushing, and an interactive table.
Features include: - Menu filters for sport and sex - Search box for
athlete names - Scatterplot with regression lines - Interactive table
with hover highlighting

## Example: Olympic Athletes Dashboard

``` r

library(rMosaic)
library(DBI)
library(duckdb)

# Generate mock athlete data
set.seed(123)
n <- 500
athletes_df <- data.frame(
  name        = paste("Athlete", seq_len(n)),
  nationality = sample(c("USA", "CAN", "GBR", "AUS", "CHN", "RUS"), n, replace = TRUE),
  sex         = sample(c("male", "female"), n, replace = TRUE),
  height      = round(rnorm(n, mean = 1.75, sd = 0.10), 2),
  weight      = round(rnorm(n, mean = 70, sd = 10.0), 1),
  sport       = sample(
    c("athletics", "swimming", "boxing", "judo", "cycling", "volleyball"),
    n, replace = TRUE
  ),
  stringsAsFactors = FALSE
)

# Build the dashboard spec
olympics_spec <- list(
  meta = list(
    title       = "Olympic Athletes",
    description = "An interactive dashboard of athlete statistics. The menus and searchbox filter the display and are automatically populated by backing data columns."
  ),
  params = list(
    # Filter for Sport/Sex/Name inputs
    category = list(select = "intersect"),
    query    = list(select = "intersect", include = "$category"),
    # Separate hover selection for highlighting
    hover    = list(select = "intersect", empty = TRUE)
  ),
  hconcat = list(
    list(
      vconcat = list(
        # Row 1: Sport menu, Sex menu, Name search
        list(
          hconcat = list(
            list(
              input  = "menu",
              label  = "Sport",
              as     = "$category",
              from   = "athletes",
              column = "sport"
            ),
            list(
              input  = "menu",
              label  = "Sex",
              as     = "$category",
              from   = "athletes",
              column = "sex"
            ),
            list(
              input    = "search",
              label    = "Name",
              filterBy = "$category",
              as       = "$query",
              from     = "athletes",
              column   = "name",
              type     = "contains"
            )
          )
        ),
        # Vertical gap
        list(vspace = 10),
        # Row 2: Scatterplot + regression + brushing + hover
        list(
          plot = list(
            # All filtered athletes (faded)
            list(
              mark    = "dot",
              data    = list(from = "athletes", filterBy = "$query"),
              x       = "weight",
              y       = "height",
              fill    = "sex",
              r       = 2,
              opacity = 0.1
            ),
            # Regression lines by sex
            list(
              mark   = "regressionY",
              data   = list(from = "athletes", filterBy = "$query"),
              x      = "weight",
              y      = "height",
              stroke = "sex"
            ),
            # Brush to update query filter
            list(
              select = "intervalXY",
              as     = "$query",
              brush  = list(fillOpacity = 0, stroke = "black")
            ),
            # Highlight hovered points
            list(
              mark        = "dot",
              data        = list(from = "athletes", filterBy = "$hover"),
              x           = "weight",
              y           = "height",
              fill        = "sex",
              stroke      = "currentColor",
              strokeWidth = 1,
              r           = 3
            )
          ),
          xyDomain    = "Fixed",
          colorDomain = "Fixed",
          margins     = list(left = 35, top = 20, right = 1),
          width       = 570,
          height      = 350
        ),
        # Small gap
        list(vspace = 5),
        # Row 3: Interactive table driving hover
        list(
          input    = "table",
          from     = "athletes",
          maxWidth = 570,
          height   = 250,
          filterBy = "$query",
          as       = "$hover",
          columns  = c("name", "nationality", "sex", "height", "weight", "sport"),
          width    = list(
            name        = 180,
            nationality = 100,
            sex         = 50,
            height      = 50,
            weight      = 50,
            sport       = 100
          )
        )
      )
    )
  )
)

# Launch the app
runMosaicApp(
  spec     = olympics_spec,
  specType = "yaml",
  data     = list(athletes = athletes_df),
  title    = "Olympic Athletes Dashboard",
  backend  = "wasm"
)
```

## Key Features

### Multiple Selection Types

1.  **Category Selection (`$category`)**
    - Sport and Sex menus update this param
    - Uses `intersect` to combine filters
2.  **Query Selection (`$query`)**
    - Includes category selection
    - Plus name search
    - Plus scatterplot brushing
3.  **Hover Selection (`$hover`)**
    - Separate from query
    - Highlights rows in table
    - Shows corresponding points in plot

### Coordinated Views

- **Menus → Plot**: Filter visible points
- **Search → Table**: Filter table rows
- **Brush → All**: Update query selection
- **Table Hover → Plot**: Highlight specific athletes

### Regression Analysis

The `regressionY` mark automatically: - Fits separate lines by sex -
Updates as filters change - Shows relationship between weight and height

## Interactive Workflow

1.  Select a sport from the menu
2.  Brush a region in the scatterplot
3.  Hover over rows in the table to see corresponding points
4.  Search for specific athlete names
5.  Notice how all views stay coordinated

This example demonstrates Mosaic’s power for building complex,
multi-widget dashboards with coordinated interactions.
