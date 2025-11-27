# NYC Taxi Crossfilter

## Introduction

This vignette demonstrates a complex multi-view dashboard with
crossfilter interactions. The example visualizes 1 million NYC taxi
rides using: - Raster density maps for pickup and dropoff locations -
Histogram of pickup times - Interactive brushing across all views

## Example: NYC Taxi Rides with Crossfilter

``` r
library(rMosaic)

# Define the spec
taxi_spec <- list(
  meta = list(
    title       = "NYC Taxi Rides",
    description = paste(
      "Pickup/dropoff points for 1M NYC taxi rides on Jan 1–3, 2010.",
      "Drag to filter both maps.",
      "Requires DuckDB 'httpfs' + 'spatial' extensions.",
      sep = "\n"
    )
  ),
  config = list(extensions = c("httpfs", "spatial")),
  data = list(
    rides = list(
      file   = "https://idl.uw.edu/mosaic-datasets/data/nyc-rides-2010.parquet",
      select = c(
        "pickup_datetime::TIMESTAMP AS datetime",
        "ST_Transform(ST_Point(pickup_latitude, pickup_longitude),'EPSG:4326','ESRI:102718') AS pick",
        "ST_Transform(ST_Point(dropoff_latitude, dropoff_longitude),'EPSG:4326','ESRI:102718') AS drop"
      )
    ),
    trips = paste(
      "SELECT",
      "  (HOUR(datetime) + MINUTE(datetime)/60) AS time,",
      "  ST_X(pick) AS px, ST_Y(pick) AS py,",
      "  ST_X(drop) AS dx, ST_Y(drop) AS dy",
      "FROM rides",
      sep = "\n"
    )
  ),
  params = list(filter = list(select = "crossfilter")),
  vconcat = list(
    list(
      hconcat = list(
        # Left: pickup raster + brush
        list(
          plot = list(
            list(mark = "raster", data = list(from = "trips", filterBy = "$filter"),
                 x = "px", y = "py", bandwidth = 0),
            list(select = "intervalXY", as = "$filter"),
            list(mark = "text", data = list(list(label = "Taxi Pickups")),
                 dx = 10, dy = 10, text = "label",
                 fill = "black", fontSize = "1.2em",
                 frameAnchor = "top-left")
          ),
          width       = 335, height = 550,
          margin      = 0, xAxis = NULL, yAxis = NULL,
          xDomain     = c(975000, 1005000),
          yDomain     = c(190000, 240000),
          colorScale  = "symlog", colorScheme = "blues"
        ),
        # Spacer
        list(hspace = 10),
        # Right: dropoff raster + same brush
        list(
          plot = list(
            list(mark = "raster", data = list(from = "trips", filterBy = "$filter"),
                 x = "dx", y = "dy", bandwidth = 0),
            list(select = "intervalXY", as = "$filter"),
            list(mark = "text", data = list(list(label = "Taxi Dropoffs")),
                 dx = 10, dy = 10, text = "label",
                 fill = "black", fontSize = "1.2em",
                 frameAnchor = "top-left")
          ),
          width       = 335, height = 550,
          margin      = 0, xAxis = NULL, yAxis = NULL,
          xDomain     = c(975000, 1005000),
          yDomain     = c(190000, 240000),
          colorScale  = "symlog", colorScheme = "oranges"
        )
      )
    ),
    # Vertical space
    list(vspace = 10),
    # Histogram + brush
    list(
      plot = list(
        list(mark = "rectY", data = list(from = "trips", filterBy = "$filter"),
             x = list(bin = "time"),
             y = list(count = NULL),
             fill = "steelblue", inset = 0.5),
        list(select = "intervalX", as = "$filter")
      ),
      yTickFormat = "s",
      xLabel      = "Pickup Hour →",
      width       = 680,
      height      = 100
    )
  )
)

# Run the app
runMosaicApp(
  spec     = taxi_spec,
  specType = "json",
  data     = NULL,
  title    = "NYC Taxi Rides (Raster + Crossfilter)",
  backend  = "wasm"
)
```

## Key Features

### Crossfilter Selection

- The `filter` parameter uses `select = "crossfilter"`
- Brushing in any view filters all other views
- Multiple selections are intersected

### Remote Data Loading

- Data loaded directly from Parquet files via URL
- No need to download data locally
- DuckDB handles efficient querying

### Spatial Transformations

- Uses DuckDB’s spatial extension
- Projects coordinates to appropriate CRS
- Efficient raster rendering with `bandwidth = 0`

### Performance

- 1M rows rendered smoothly
- WASM backend for browser-side computation
- Raster aggregation for dense point clouds

## Try It Yourself

1.  Brush a region in the pickup map
2.  Notice the dropoff map and histogram update
3.  Brush a time range in the histogram
4.  See both maps update to show only rides in that time window

This demonstrates Mosaic’s ability to handle large datasets with fluid,
interactive crossfilter selections.
