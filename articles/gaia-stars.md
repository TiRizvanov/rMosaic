# Gaia Star Catalog

## Introduction

This vignette demonstrates visualizing astronomical data from the Gaia
star catalog. The example showcases: - 5 million stars from the 1.8
billion element catalog - Raster density visualization revealing the
Milky Way - Hertzsprung-Russell diagram (color vs. magnitude) -
Crossfilter interactions between multiple views

**Note:** This example uses remote Parquet data (may take a few seconds
to load).

## Example: Gaia Star Catalog

``` r

library(rMosaic)
library(DBI)
library(duckdb)

# Build the spec
gaia_spec <- list(
  meta = list(
    title       = "Gaia Star Catalog",
    description = paste(
      "A 5M row sample of the 1.8B element Gaia star catalog.",
      "A `raster` sky map reveals our Milky Way galaxy.",
      "Select high parallax stars in the histogram to reveal a",
      "Hertzsprung-Russell diagram in the plot of stellar color vs. magnitude on the right.",
      "_You may need to wait a few seconds for the dataset to load._",
      sep = "\n\n"
    )
  ),
  data = list(
    gaia = paste(
      "-- compute u and v with natural earth projection",
      "WITH prep AS (",
      "  SELECT",
      "    radians((-l + 540) % 360 - 180) AS lambda,",
      "    radians(b) AS phi,",
      "    asin(sqrt(3)/2 * sin(phi)) AS t,",
      "    t^2 AS t2,",
      "    t2^3 AS t6,",
      "    *",
      "  FROM 'https://idl.uw.edu/mosaic-datasets/data/gaia-5m.parquet'",
      "  WHERE parallax BETWEEN -5 AND 20",
      "    AND phot_g_mean_mag IS NOT NULL",
      "    AND bp_rp IS NOT NULL",
      ")",
      "SELECT",
      "  (1.340264 * \"lambda\" * cos(t)) /",
      "    (sqrt(3)/2 * (1.340264",
      "      + (-0.081106 * 3 * t2)",
      "      + (t6 * (0.000893 * 7 + 0.003796 * 9 * t2)))) AS u,",
      "  t * (1.340264",
      "      + (-0.081106 * t2)",
      "      + (t6 * (0.000893 + 0.003796 * t2))) AS v,",
      "  * EXCLUDE('t','t2','t6')",
      "FROM prep",
      sep = "\n"
    )
  ),
  params = list(
    brush      = list(select = "crossfilter"),
    bandwidth  = 0,
    pixelSize  = 2,
    scaleType  = "sqrt"
  ),
  hconcat = list(
    list(
      vconcat = list(
        # Top: Sky map with Natural Earth projection
        list(
          plot = list(
            list(mark = "raster",
                 data = list(from = "gaia", filterBy = "$brush"),
                 x = "u", y = "v",
                 fill = "density",
                 bandwidth = "$bandwidth",
                 pixelSize = "$pixelSize"
            ),
            list(select = "intervalXY", pixelSize = 2, as = "$brush")
          ),
          xyDomain     = "Fixed",
          colorScale   = "$scaleType",
          colorScheme  = "viridis",
          width        = 440,
          height       = 250,
          marginLeft   = 25,
          marginTop    = 20,
          marginRight  = 1
        ),
        # Bottom row: magnitude and parallax histograms
        list(
          hconcat = list(
            # Magnitude histogram
            list(
              plot = list(
                list(mark = "rectY",
                     data = list(from = "gaia", filterBy = "$brush"),
                     x = list(bin = "phot_g_mean_mag"),
                     y = list(count = NULL),
                     fill  = "steelblue",
                     inset = 0.5
                ),
                list(select = "intervalX", as = "$brush")
              ),
              xDomain     = "Fixed",
              yScale      = "$scaleType",
              yGrid       = TRUE,
              width       = 220,
              height      = 120,
              marginLeft  = 65
            ),
            # Parallax histogram
            list(
              plot = list(
                list(mark = "rectY",
                     data = list(from = "gaia", filterBy = "$brush"),
                     x = list(bin = "parallax"),
                     y = list(count = NULL),
                     fill  = "steelblue",
                     inset = 0.5
                ),
                list(select = "intervalX", as = "$brush")
              ),
              xDomain     = "Fixed",
              yScale      = "$scaleType",
              yGrid       = TRUE,
              width       = 220,
              height      = 120,
              marginLeft  = 65
            )
          )
        )
      )
    ),
    list(hspace = 10),
    # Right: Hertzsprung-Russell diagram (color vs. magnitude)
    list(
      plot = list(
        list(mark = "raster",
             data = list(from = "gaia", filterBy = "$brush"),
             x = "bp_rp",
             y = "phot_g_mean_mag",
             fill = "density",
             bandwidth = "$bandwidth",
             pixelSize = "$pixelSize"
        ),
        list(select = "intervalXY", pixelSize = 2, as = "$brush")
      ),
      xyDomain     = "Fixed",
      colorScale   = "$scaleType",
      colorScheme  = "viridis",
      yReverse     = TRUE,
      width        = 230,
      height       = 370,
      marginLeft   = 25,
      marginTop    = 20,
      marginRight  = 1
    )
  )
)

# Launch the app
runMosaicApp(
  spec     = gaia_spec,
  specType = "yaml",
  data     = NULL,         # all data loaded via DuckDB + remote Parquet
  title    = "Gaia Star Catalog",
  backend = "wasm"
)
```

## Key Features

### Natural Earth Projection

- SQL query transforms galactic coordinates (l, b) to projected (u, v)
- Shows the Milky Way’s disk and bulge structure
- Computed entirely in DuckDB for efficiency

### Hertzsprung-Russell Diagram

- Right panel shows stellar color (bp_rp) vs. magnitude
- Reveals main sequence, giant branch, and white dwarfs
- Select high parallax stars (nearby) to see clearer patterns

### Multiple Crossfilter Brushes

- Sky map brushing
- Magnitude histogram brushing
- Parallax histogram brushing
- H-R diagram brushing
- All views update simultaneously

### Performance

- 5M rows rendered smoothly
- Raster aggregation with configurable `pixelSize`
- Square root color scale (`scaleType = "sqrt"`) for better contrast
- WASM backend for browser-side computation

## Try It Yourself

1.  Brush the parallax histogram to select nearby stars (parallax \> 5)
2.  Notice the H-R diagram reveals clear stellar sequences
3.  Brush a region in the sky map to focus on a specific area
4.  Experiment with different parallax ranges to see distance effects

This demonstrates Mosaic’s ability to handle millions of rows with
complex spatial transformations and coordinated interactions.
