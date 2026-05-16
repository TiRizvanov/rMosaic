# Dynamic Rendering

## Introduction

This vignette demonstrates dynamic on-the-fly rendering with pan/zoom
interactions. Unlike static visualizations, this example: - Maintains
constant pixel size (2 units) regardless of zoom level - Dynamically
adjusts bin resolution as you zoom - Provides smooth, responsive
interaction even with large datasets

## Example: Dynamic Density Raster

``` r

library(rMosaic)

# Generate mock spatial data
set.seed(42)
n  <- 500000
df <- data.frame(
  x         = runif(n, 0, 100),
  y         = runif(n, 0, 100),
  cell_type = sample(c("TypeA", "TypeB"), n, TRUE, c(0.6, 0.4))
)

# Define Mosaic spec (YAML as R list)
spec <- list(
  meta = list(
    title = "Dynamic Density Raster",
    description = "Zoom in/out – bins stay 2 units wide so resolution sharpens."
  ),

  data = list(spatial = list()),          # df will be registered in DuckDB

  params = list(pixel = 2),               # pixel-size parameter

  plot = list(
    list(                                 # raster mark layer
      mark      = "raster",
      data      = list(from = "spatial"), # all points
      x         = "x",
      y         = "y",
      fill      = "density",              # count per bin
      pixelSize = "$pixel"
    ),
    list(select = "panZoom", x = "$xs", y = "$ys")
  ),

  width       = 700,
  height      = 600,
  colorScale  = "sqrt",
  colorScheme = "viridis"
)

# Launch the application
runMosaicApp(
  spec  = spec,
  data  = list(spatial = df),
  title = "Dynamic Raster Demo",
  backend  = "wasm"
)
```

## Key Features

### Dynamic Binning

- As you zoom in, bins stay constant size (2 units)
- Resolution increases automatically
- No manual bin size adjustment needed

### Pan/Zoom Interaction

- `select = "panZoom"` enables smooth navigation
- Drag to pan
- Scroll to zoom
- Double-click to reset view

### Performance

- Only visible data is rendered
- Efficient DuckDB queries update on zoom/pan
- Handles 10,000+ points smoothly

### Color Encoding

- `colorScale = "sqrt"` provides better contrast for density
- `viridis` palette is perceptually uniform
- Density automatically updates with zoom level

## Use Cases

This pattern is ideal for: - **Spatial transcriptomics**: Cell locations
with dynamic resolution - **Microscopy data**: Pan/zoom through large
tissue sections - **Geographic data**: Explore patterns at multiple
scales - **Scatter plots**: Dense point clouds that need detail at
different zoom levels

## Try It Yourself

1.  Zoom in on a dense region
2.  Notice how resolution increases (more detail visible)
3.  Pan around to explore different areas
4.  Zoom out to see the full distribution
5.  Double-click to reset the view

Compare this to a fixed-resolution raster where: - Zooming in reveals
pixelated bins - Zooming out may show too much detail - Bin size is
static regardless of view

## Advanced: Customizing Pixel Size

You can expose the `pixelSize` parameter as a user control:

``` r

spec_with_slider <- spec
spec_with_slider$vconcat <- list(
  spec_with_slider$plot,
  list(vspace = 10),
  list(
    input = "slider",
    label = "Pixel Size",
    min = 1,
    max = 10,
    step = 1,
    as = "$pixel"
  )
)

runMosaicApp(
  spec = spec_with_slider,
  data = list(spatial = df),
  title = "Dynamic Raster with Pixel Size Control"
)
```

This demonstrates Mosaic’s ability to create responsive, zoom-dependent
visualizations that adapt to user navigation.
