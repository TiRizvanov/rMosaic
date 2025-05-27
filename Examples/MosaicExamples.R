library(mosaicShiny)
library(arrow)
library(base64enc)
# 1) JSON (string)
json_spec <- '{
  "plot": [{
    "mark":"dot","data":{"from":"iris"},
    "x":"Sepal.Length","y":"Sepal.Width","color":"Species"
  }],
  "width":700,"height":500
}'

# 2) YAML (R list)
yaml_spec <- list(
  plot = list(list(
    mark  = "dot",
    data  = list(from="iris"),
    x     = "Sepal.Length",
    y     = "Sepal.Width",
    color = "Species"
  )),
  width  = 700,
  height = 500
)

# 3) ESM from raw JS text
esm_text <- "
import { plot, dot, from, width, height } from 'https://esm.sh/@uwdata/vgplot@0.15.0';
export default plot(
  dot(from('iris'), { x:'Sepal.Length', y:'Sepal.Width', color:'Species' }),
  width(700), height(500)
);
"

# Launch each in the Viewer:
runMosaicApp(json_spec, specType="json", data=list(iris=iris), title="JSON Iris")
runMosaicApp(yaml_spec, specType="yaml", data=list(iris=iris), title="YAML Iris")
runMosaicApp(esm_text, specType="esm", data=list(iris=iris), title="ESM Iris")








#First Example


# ▶︎ APPLE STOCK — JSON
library(mosaicShiny)

# 1) Mock data: 100 days of “Close” prices
set.seed(42)
mock_aapl <- data.frame(
  Date  = seq.Date(Sys.Date() - 99, Sys.Date(), by = "day"),
  Close = cumsum(runif(100, -1, 1)) + 150
)

# 2) JSON spec string
json_spec <- '{
  "plot":[{"mark":"lineY","data":{"from":"aapl"},"x":"Date","y":"Close"}],
  "width":680,"height":200
}'

# 3) Launch the app
runMosaicApp(
  spec       = json_spec,
  specType   = "json",
  data       = list(aapl = mock_aapl),
  title      = "AAPL via JSON",
  width      = 680,
  height     = 200
)



# ▶︎ APPLE STOCK — YAML
library(mosaicShiny)

# reuse mock_aapl from above

# 1) YAML spec as an R list
yaml_spec <- list(
  data = list(aapl = list()),
  plot = list(list(
    mark = "lineY",
    data = list(from = "aapl"),
    x    = "Date",
    y    = "Close"
  )),
  width  = 680,
  height = 200
)

# 2) Launch the app
runMosaicApp(
  spec       = yaml_spec,
  specType   = "yaml",
  data       = list(aapl = mock_aapl),
  title      = "AAPL via YAML",
  width      = 680,
  height     = 200
)




# ▶︎ APPLE STOCK — ESM
library(mosaicShiny)

# reuse mock_aapl

# 1) Inline ESM spec (JS module as text)
esm_spec <- "
export default plot(
  lineY(from('aapl'), { x:'Date', y:'Close' }),
  width(680), height(200)
);
"

# 2) Launch the app
runMosaicApp(
  spec       = esm_spec,
  specType   = "esm",
  data       = list(aapl = mock_aapl),
  title      = "AAPL via ESM",
  width      = 680,
  height     = 200
)











# Second ex


# install.packages("mosaicShiny")  # if you haven’t already
library(mosaicShiny)

# 1) Synthetic "penguins" dataset
set.seed(42)
penguins_df <- data.frame(
  bill_length = rnorm(150, mean=40, sd=5),
  bill_depth  = rnorm(150, mean=18, sd=3),
  species     = sample(c("Adelie","Gentoo","Chinstrap"), 150, replace = TRUE)
)

# 2) YAML spec (as an R list)
voronoi_yaml <- list(
  params = list(
    mesh = 0,
    hull = 0
  ),
  vconcat = list(
    # Main plot
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
          strokeOpacity = "$hull",    # ← literal param reference
          strokeWidth = 1.5
        ),
        list(
          mark = "delaunayMesh",
          data = list(from = "penguins"),
          x = "bill_length",
          y = "bill_depth",
          z = "species",
          stroke = "species",
          strokeOpacity = "$mesh",    # ← literal param reference
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
    # The two menus
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

# 3) JSON spec (from the YAML)
voronoi_json <- jsonlite::toJSON(voronoi_yaml, auto_unbox = TRUE, pretty = TRUE)

# 4) ESM spec (raw JS text) — unchanged
voronoi_esm <- "
const $mesh = Param.value(0);
const $hull = Param.value(0);

export default vconcat(
  plot(
    voronoi(
      from('penguins'),
      { x: 'bill_length', y: 'bill_depth',
        stroke: 'white', strokeWidth: 1,
        strokeOpacity: 0.2, fill: 'species', fillOpacity: 0.2 }
    ),
    hull(
      from('penguins'),
      { x: 'bill_length', y: 'bill_depth',
        stroke: 'species', strokeOpacity: $hull, strokeWidth: 1.5 }
    ),
    delaunayMesh(
      from('penguins'),
      { x: 'bill_length', y: 'bill_depth', z: 'species',
        stroke: 'species', strokeOpacity: $mesh, strokeWidth: 1 }
    ),
    dot(
      from('penguins'),
      { x: 'bill_length', y: 'bill_depth',
        fill: 'species', r: 2 }
    ),
    frame(),
    width(680),
    height(480)
  ),
  hconcat(
    menu({
      label: 'Delaunay Mesh',
      options: [
        { value: 0,   label: 'Hide' },
        { value: 0.5, label: 'Show' }
      ],
      as: $mesh
    }),
    hspace(5),
    menu({
      label: 'Convex Hull',
      options: [
        { value: 0, label: 'Hide' },
        { value: 1, label: 'Show' }
      ],
      as: $hull
    })
  )
);

"

# --- RUN ONE AT A TIME (stop the app before switching) ---

## A) YAML
runMosaicApp(
  spec     = voronoi_yaml,
  specType = "yaml",
  data     = list(penguins = penguins_df),
  title    = "Voronoi Diagram (YAML)"
)

## B) JSON
runMosaicApp(
  spec     = voronoi_json,
  specType = "json",
  data     = list(penguins = penguins_df),
  title    = "Voronoi Diagram (JSON)"
)

## C) ESM
runMosaicApp(
  spec     = voronoi_esm,
  specType = "esm",
  data     = list(penguins = penguins_df),
  title    = "Voronoi Diagram (ESM)"
)










# third
library(nycflights13)    # Flight data
library(mosaicShiny)     # Your package

# JSON specification for an interactive, sortable table:
json_sortable <- '{
  "meta": {
    "title": "Sortable Table",
    "description": "A sortable, infinite‑scroll table over the flights dataset."
  },
  "input": "table",
  "from": "flights",
  "height": 300
}'

# Simply pass the data frame; mosaicShiny will create the DuckDB table:
runMosaicApp(
  json_sortable,
  specType = "json",
  data     = list(flights = nycflights13::flights),
  title    = "Flights (JSON Sortable)"
)


library(nycflights13)
library(mosaicShiny)

# 1) Define the spec as an R list (YAML)
yaml_sortable <- list(
  meta = list(
    title       = "Sortable Table",
    description = "A sortable, infinite‑scroll table over the flights dataset."
  ),
  input  = "table",
  from   = "flights",
  height = 300
)

# 2) Run in the Viewer
runMosaicApp(
  yaml_sortable,
  specType = "yaml",
  data     = list(flights = nycflights13::flights),
  title    = "Flights (YAML Sortable)"
)


library(nycflights13)
library(mosaicShiny)

# 1) Define the ESM spec as a JS module exporting a Mosaic spec object:
esm_sortable <- "
export default {
  meta: {
    title: 'Sortable Table',
    description: 'A sortable, infinite‑scroll table over the flights dataset.'
  },
  input: 'table',
  from: 'flights',
  height: 300
};
"

# 2) Launch it (mosaicShiny will auto-write `flights` into DuckDB)
runMosaicApp(
  esm_sortable,
  specType = "esm",
  data     = list(flights = nycflights13::flights),
  title    = "Flights (ESM Sortable)"
)











# fourth

# install.packages(c("palmerpenguins","mosaicShiny"))
library(palmerpenguins)
library(mosaicShiny)

# 1) Prepare the data
penguins <- na.omit(palmerpenguins::penguins)

# 2) Build the spec as an R list (JSON‐equivalent)
spec <- list(
  meta = list(
    title       = "Pan & Zoom",
    description = paste(
      "Linked panning and zooming across plots: drag to pan, scroll to zoom.",
      "`panZoom` interactors update bound selections per axis."
    )
  ),
  # telling mosaicShiny we'll supply 'penguins' via data=…
  data = list(penguins = list()),

  # top‐level layout: two columns of two plots each
  hconcat = list(
    # left column
    list(
      vconcat = list(
        # top‐left
        list(
          plot = list(
            list(mark = "frame"),
            list(
              mark     = "dot",
              data     = list(from = "penguins"),
              x        = "bill_length_mm",
              y        = "bill_depth_mm",
              fill     = "species",
              r        = 2,
              clip     = TRUE
            ),
            # panZoom selection bound into $xs/$ys
            list(select = "panZoom", x = "$xs", y = "$ys")
          ),
          width  = 320, height = 240
        ),
        # gutter
        list(vspace = 10),
        # bottom‐left
        list(
          plot = list(
            list(mark = "frame"),
            list(
              mark     = "dot",
              data     = list(from = "penguins"),
              x        = "bill_length_mm",
              y        = "flipper_length_mm",
              fill     = "species",
              r        = 2,
              clip     = TRUE
            ),
            list(select = "panZoom", x = "$xs", y = "$zs")
          ),
          width  = 320, height = 240
        )
      )
    ),
    # horizontal gutter
    list(hspace = 10),

    # right column
    list(
      vconcat = list(
        # top‐right
        list(
          plot = list(
            list(mark = "frame"),
            list(
              mark     = "dot",
              data     = list(from = "penguins"),
              x        = "body_mass_g",
              y        = "bill_depth_mm",
              fill     = "species",
              r        = 2,
              clip     = TRUE
            ),
            list(select = "panZoom", x = "$ws", y = "$ys")
          ),
          width  = 320, height = 240
        ),
        list(vspace = 10),
        # bottom‐right
        list(
          plot = list(
            list(mark = "frame"),
            list(
              mark     = "dot",
              data     = list(from = "penguins"),
              x        = "body_mass_g",
              y        = "flipper_length_mm",
              fill     = "species",
              r        = 2,
              clip     = TRUE
            ),
            list(select = "panZoom", x = "$ws", y = "$zs")
          ),
          width  = 320, height = 240
        )
      )
    )
  )
)

# 3) Run it, passing the penguins df in `data=…`
runMosaicApp(
  spec     = spec,
  specType = "json",                      # "auto" also works, since spec is a list
  data     = list(penguins = penguins),
  title    = "Pan & Zoom (penguins)"
)





# NYC Taxi with dots


library(mosaicShiny)

taxi_spec_dots <- list(

  meta = list(
    title       = "NYC Taxi Rides",
    description = paste(
      "Pickup and dropoff points for 1M NYC taxi rides on Jan 1–3, 2010.",
      "This example projects lon/lat coordinates in the database upon load.",
      "Select a region in one plot to filter the other.",
      "Requires DuckDB's spatial + httpfs extensions.",
      "\n\n_You may need to wait a few seconds for the Parquet to stream and extensions to load._",
      sep="\n"
    )
  ),

  # Tell Mosaic which DuckDB extensions to install+load
  config = list(
    extensions = c("httpfs", "spatial")
  ),

  # Data sources - use a sample for better performance
  data = list(
    rides = list(
      file   = "https://idl.uw.edu/mosaic-datasets/data/nyc-rides-2010.parquet",
      select = c(
        "pickup_datetime::TIMESTAMP AS datetime",
        "ST_Transform(ST_Point(pickup_latitude, pickup_longitude), 'EPSG:4326','ESRI:102718') AS pick",
        "ST_Transform(ST_Point(dropoff_latitude, dropoff_longitude), 'EPSG:4326','ESRI:102718') AS drop"
      )
    ),
    trips = paste(
      "SELECT",
      "  (HOUR(datetime) + MINUTE(datetime)/60) AS time,",
      "  ST_X(pick) AS px, ST_Y(pick) AS py,",
      "  ST_X(drop) AS dx, ST_Y(drop) AS dy",
      "FROM rides",
      "LIMIT 10000", # Smaller sample for better performance
      sep="\n"
    )
  ),

  # Crossfilter selection
  params = list(
    filter = list(select = "crossfilter")
  ),

  # Layout: two maps above, histogram below
  vconcat = list(
    list(
      hconcat = list(
        list(
          plot = list(
            # Use dot mark instead of raster
            list(
              mark      = "dot",
              data      = list(from="trips", filterBy="$filter"),
              x         = "px",
              y         = "py",
              fill      = "steelblue",
              fillOpacity = 0.2,
              size      = 8
            ),
            list(
              select = "intervalXY",
              as = "$filter"
            ),
            list(
              mark       = "text",
              data       = list(list(label="Taxi Pickups")),
              dx         = 10, dy=10,
              text       = "label",
              fill       = "white",
              fontSize   = "1.2em",
              frameAnchor= "top-left"
            )
          ),
          width       = 335,
          height      = 550,
          margin      = 0,
          xAxis       = NULL,
          yAxis       = NULL,
          xDomain     = c(975000,1005000),
          yDomain     = c(190000,240000)
        ),
        list(hspace = 10),
        list(
          plot = list(
            # Use dot mark instead of raster
            list(
              mark      = "dot",
              data      = list(from="trips", filterBy="$filter"),
              x         = "dx",
              y         = "dy",
              fill      = "orange",
              fillOpacity = 0.2,
              size      = 8
            ),
            list(
              select = "intervalXY",
              as = "$filter"
            ),
            list(
              mark       = "text",
              data       = list(list(label="Taxi Dropoffs")),
              dx         = 10, dy=10,
              text       = "label",
              fill       = "white",
              fontSize   = "1.2em",
              frameAnchor= "top-left"
            )
          ),
          width       = 335,
          height      = 550,
          margin      = 0,
          xAxis       = NULL,
          yAxis       = NULL,
          xDomain     = c(975000,1005000),
          yDomain     = c(190000,240000)
        )
      )
    ),

    list(vspace = 10),

    list(
      plot = list(
        list(
          mark = "rectY",
          data = list(from="trips", filterBy="$filter"),
          x    = list(bin="time"),
          y    = list(count=NULL),
          fill = "steelblue",
          inset= 0.5
        ),
        list(
          select = "intervalX",
          as = "$filter"
        )
      ),
      yTickFormat = "s",
      xLabel      = "Pickup Hour →",
      width       = 680,
      height      = 100
    )
  )
)

# Run it:
runMosaicApp(
  spec     = taxi_spec_dots,
  specType = "json",
  data     = NULL,
  title    = "NYC Taxi Rides with Dot Visualization"
)







#Hexbins

library(mosaicShiny)

# Modified spec without the unsupported background attribute
taxi_spec_fixed <- list(

  meta = list(
    title       = "NYC Taxi Rides",
    description = paste(
      "Pickup and dropoff points for 1M NYC taxi rides on Jan 1–3, 2010.",
      "Select a region in one plot to filter the other.",
      "Requires DuckDB's spatial + httpfs extensions.",
      "\n\n_You may need to wait a few seconds for the Parquet to stream and extensions to load._",
      sep="\n"
    )
  ),

  # Tell Mosaic which DuckDB extensions to install+load
  config = list(
    extensions = c("httpfs", "spatial")
  ),

  # Data sources - use smaller sample size for better performance
  data = list(
    rides = list(
      file   = "https://idl.uw.edu/mosaic-datasets/data/nyc-rides-2010.parquet",
      select = c(
        "pickup_datetime::TIMESTAMP AS datetime",
        "ST_Transform(ST_Point(pickup_latitude, pickup_longitude), 'EPSG:4326','ESRI:102718') AS pick",
        "ST_Transform(ST_Point(dropoff_latitude, dropoff_longitude), 'EPSG:4326','ESRI:102718') AS drop"
      )
    ),
    trips = paste(
      "SELECT",
      "  (HOUR(datetime) + MINUTE(datetime)/60) AS time,",
      "  ST_X(pick) AS px, ST_Y(pick) AS py,",
      "  ST_X(drop) AS dx, ST_Y(drop) AS dy",
      "FROM rides",
      "LIMIT 100000",  # Limit records for better performance
      sep="\n"
    )
  ),

  # Crossfilter selection
  params = list(
    filter = list(select = "crossfilter")
  ),

  # Layout: two maps above, histogram below
  vconcat = list(
    list(
      hconcat = list(
        list(
          plot = list(
            # Use hexbin instead of raster
            list(
              mark      = "hexbin",
              data      = list(from="trips", filterBy="$filter"),
              x         = "px",
              y         = "py",
              fill      = list(count=NULL),
              size      = 8
            ),
            # Add selection interactor
            list(
              select = "intervalXY",
              as = "$filter"
            ),
            list(
              mark       = "text",
              data       = list(list(label="Taxi Pickups")),
              dx         = 10, dy=10,
              text       = "label",
              fill       = "white",
              fontSize   = "1.2em",
              frameAnchor= "top-left"
            )
          ),
          width       = 335, height = 550,
          margin      = 0,
          xAxis       = NULL, yAxis = NULL,
          xDomain     = c(975000,1005000),
          yDomain     = c(190000,240000),
          colorScheme = "blues"
        ),
        list(hspace = 10),
        list(
          plot = list(
            # Use hexbin instead of raster
            list(
              mark      = "hexbin",
              data      = list(from="trips", filterBy="$filter"),
              x         = "dx",
              y         = "dy",
              fill      = list(count=NULL),
              size      = 8
            ),
            # Add selection interactor
            list(
              select = "intervalXY",
              as = "$filter"
            ),
            list(
              mark       = "text",
              data       = list(list(label="Taxi Dropoffs")),
              dx         = 10, dy=10,
              text       = "label",
              fill       = "white",
              fontSize   = "1.2em",
              frameAnchor= "top-left"
            )
          ),
          width       = 335, height = 550,
          margin      = 0,
          xAxis       = NULL, yAxis = NULL,
          xDomain     = c(975000,1005000),
          yDomain     = c(190000,240000),
          colorScheme = "oranges"
        )
      )
    ),

    list(vspace = 10),

    list(
      plot = list(
        list(
          mark = "rectY",
          data = list(from="trips", filterBy="$filter"),
          x    = list(bin="time"),
          y    = list(count=NULL),
          fill = "steelblue",
          inset= 0.5
        ),
        # Add selection interactor to the histogram
        list(
          select = "intervalX",
          as = "$filter"
        )
      ),
      yTickFormat = "s",
      xLabel      = "Pickup Hour →",
      width       = 680,
      height      = 100
    )
  )
)

# Run it:
runMosaicApp(
  spec     = taxi_spec_fixed,
  specType = "json",
  data     = NULL,
  title    = "NYC Taxi Rides with Selection"
)








# Raster

# 1) Define the spec
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

# 2) Run the app
runMosaicApp(
  spec     = taxi_spec,
  specType = "json",
  data     = NULL,
  title    = "NYC Taxi Rides (Raster + Crossfilter)"
)








# ─────────────────────────────────────────────────────────────────────────────
# Olympic Athletes Dashboard (fixed selection logic)
# ─────────────────────────────────────────────────────────────────────────────

# 1) load mosaicShiny
library(mosaicShiny)

# 2) generate some mock athlete data
set.seed(123)
n <- 500
athletes_df <- data.frame(
  name        = paste("Athlete", seq_len(n)),
  nationality = sample(c("USA","CAN","GBR","AUS","CHN","RUS"), n, replace=TRUE),
  sex         = sample(c("male","female"),         n, replace=TRUE),
  height      = round(rnorm(n, mean=1.75, sd=0.1),  2),
  weight      = round(rnorm(n, mean=70,   sd=10),   1),
  sport       = sample(
    c("athletics","swimming","boxing","judo",
      "cycling","volleyball"),
    n, replace=TRUE
  ),
  stringsAsFactors = FALSE
)

# 3) build the spec as an R list
spec <- list(
  params = list(
    # single crossfilter to accumulate menus/search/brush
    filter = list(select = "crossfilter"),
    # separate hover selection for table→scatter linking
    hover  = list(select = "intersect", empty = TRUE)
  ),

  hconcat = list(
    list(vconcat = list(
      # row 1: menus + search
      list(hconcat = list(
        list(input   = "menu",
             label   = "Sport",
             from    = "athletes",
             column  = "sport",
             as      = "$filter"),
        list(input   = "menu",
             label   = "Sex",
             from    = "athletes",
             column  = "sex",
             as      = "$filter"),
        list(input    = "search",
             label    = "Name",
             from     = "athletes",
             column   = "name",
             type     = "contains",
             as       = "$filter")
      )),

      # small gap
      list(vspace = 10),

      # row 2: scatter + regression + brush + hover
      list(plot = list(
        # scatter of filtered athletes
        list(mark    = "dot",
             data    = list(from = "athletes", filterBy = "$filter"),
             x       = "weight",
             y       = "height",
             fill    = "sex",
             r       = 2,
             opacity = 0.2),

        # regression over that same filtered set
        list(mark   = "regressionY",
             data   = list(from = "athletes", filterBy = "$filter"),
             x      = "weight",
             y      = "height",
             stroke = "sex"),

        # brush to update the same crossfilter
        list(select = "intervalXY",
             as     = "$filter",
             brush  = list(fillOpacity = 0, stroke = "black")),

        # hovered points, driven by the table
        list(mark        = "dot",
             data        = list(from = "athletes", filterBy = "$hover"),
             x           = "weight",
             y           = "height",
             fill        = "sex",
             stroke      = "currentColor",
             strokeWidth = 1,
             r           = 3)
      ),
      # keep the axes fixed
      xyDomain    = "Fixed",
      colorDomain = "Fixed",
      margins     = list(left = 35, top = 20, right = 1),
      width       = 570,
      height      = 350),

      # tiny vertical space
      list(vspace = 5),

      # row 3: the table input (drives $hover)
      list(
        input    = "table",
        from     = "athletes",
        maxWidth = 570,
        height   = 250,
        filterBy = "$filter",
        as       = "$hover",
        columns  = c("name","nationality","sex","height","weight","sport"),
        width    = list(
          name        = 180,
          nationality = 100,
          sex         = 50,
          height      = 50,
          weight      = 50,
          sport       = 100
        )
      )
    ))
  )
)

# 4) launch it!
runMosaicApp(
  spec     = spec,
  specType = "auto",
  data     = list(athletes = athletes_df),
  title    = "Olympic Athletes Dashboard (fixed)"
)









# Protein Analysis
library(mosaicShiny)

# Create data for protein design explorer
set.seed(123) # For reproducibility

# First, create the exact data shown in the example table
real_examples <- data.frame(
  version = c("v1", "v1", "v1", "v1", "v1", "v1", "v1", "v1", "v3", "v3", "v2", "v2", "v2", "v1", "v1", "v1"),
  pae_interaction = c(21.025, 22.111, 21.456, 20.623, 22.149, 19.583, 20.298, 21.652, 18.732, 21.422, 21.091, 22.049, 20.766, 18.904, 19.067, 18.999),
  plddt_total = c(75.48, 85.021, 85.675, 86.773, 87.177, 85.753, 86.372, 84.957, 88.236, 87.415, 83.348, 77.387, 86.833, 87.987, 78.832, 88.256),
  noise = c(1, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 0, 0, 0, 0, 0, 0),
  gradient_decay_function = c("gdquadratic", "gdquadratic", "gdcubic", "gdcubic", "gdcubic", "gdcubic", "gdcubic", "gdcubic", "gdcubic", "gdcubic", "gdquadratic", "gdquadratic", "gdquadratic", "gdcubic", "gdcubic", "gdcubic"),
  gradient_scale = c(2, 2, 2, 2, 2, 2, 2, 2, 2, 0.01, 4, 4, 4, 2, 2, 2),
  movement = c("moved", "moved", "og", "og", "og", "og", "og", "og", "og", "og", "og", "og", "og", "moved", "moved", "moved"),
  partial_t = rep(0.3, 16)
)

# Generate a larger dataset - 2000 points
n_additional <- 2000
v1_prop <- 0.7  # 70% v1
v2_prop <- 0.2  # 20% v2
v3_prop <- 0.1  # 10% v3

# Create wider range for pae_interaction (15-28 instead of 18-23)
additional_data <- data.frame(
  version = sample(c("v1", "v2", "v3"), n_additional, replace = TRUE,
                   prob = c(v1_prop, v2_prop, v3_prop)),
  # Wider range for pae_interaction with a bimodal distribution
  pae_interaction = round(c(
    # Most v1 values clustered around 19-22
    rnorm(n_additional * 0.5, mean = 20.5, sd = 1.5),
    # A secondary cluster around 24-27
    rnorm(n_additional * 0.3, mean = 25.5, sd = 1.2),
    # Some outliers on the lower end
    runif(n_additional * 0.2, min = 15, max = 18)
  )[sample(n_additional)], 3),

  # pLDDT has a slight negative correlation with pae_interaction
  plddt_total = NA,

  noise = sample(c(0, 0.1, 0.5, 1), n_additional, replace = TRUE,
                 prob = c(0.3, 0.2, 0.3, 0.2)),
  gradient_decay_function = sample(c("gdcubic", "gdquadratic"), n_additional, replace = TRUE,
                                   prob = c(0.6, 0.4)),
  gradient_scale = sample(c(0.01, 2, 4), n_additional, replace = TRUE,
                          prob = c(0.2, 0.5, 0.3)),
  movement = sample(c("og", "moved"), n_additional, replace = TRUE,
                    prob = c(0.6, 0.4)),
  partial_t = sample(c(0.2, 0.3, 0.4, 0.5), n_additional, replace = TRUE)
)

# Create a slight negative correlation between pae and plddt
additional_data$plddt_total <- round(90 - additional_data$pae_interaction * 0.3 +
                                       rnorm(n_additional, mean = 0, sd = 3), 3)

# Ensure values are within reasonable ranges
additional_data$plddt_total <- pmax(pmin(additional_data$plddt_total, 94), 67)

# Combine the real examples with the additional data
protein_data <- rbind(real_examples, additional_data)

# Define the protein design explorer spec
protein_spec <- list(
  meta = list(
    title = "Protein Design Explorer",
    description = paste(
      "Explore synthesized proteins generated via RFDiffusion.",
      "\"Minibinders\" are small proteins that bind to a specific protein target.",
      "When designing a minibinder, a researcher inputs the structure of the",
      "target protein and other parameters into the AI diffusion model.",
      "\n\nThe metric pAE (predicted alignment error) measures how accurate a model was at",
      "predicting the minibinder shape, whereas pLDDT (predicted local distance",
      "difference test) measures a model's confidence in minibinder structure",
      "prediction. For pAE lower is better, for pLDDT higher is better.",
      sep = "\n"
    )
  ),

  # Define parameters - updated domain for wider pae range
  params = list(
    query = list(select = "crossfilter"),
    point = list(select = "intersect", empty = TRUE),
    plddt_domain = c(67, 94.5),
    pae_domain = c(15, 29)  # Updated to match the wider range of data
  ),

  # Layout structure
  vconcat = list(
    # First row - menu filters
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

    # Spacing
    list(vspace = "1.5em"),

    # Top histogram
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

    # Main scatter plot and side histogram
    list(
      hconcat = list(
        list(
          name = "scatter",
          plot = list(
            # Frame border
            list(
              mark = "frame",
              stroke = "#ccc"
            ),
            # Use dot plot as requested
            list(
              mark = "dot",
              data = list(from = "proteins", filterBy = "$query"),
              x = "plddt_total",
              y = "pae_interaction",
              fill = "version",
              stroke = NULL,
              fillOpacity = 0.5,
              size = 20
            ),
            # Selection interactor
            list(
              select = "intervalXY",
              as = "$query",
              brush = list(stroke = "currentColor", fill = "transparent")
            ),
            # Points for selected items
            list(
              mark = "dot",
              data = list(from = "proteins", filterBy = "$point"),
              x = "plddt_total",
              y = "pae_interaction",
              fill = "version",
              stroke = "black",
              strokeWidth = 1.5,
              size = 60
            )
          ),
          colorDomain = "Fixed",
          xDomain = "$plddt_domain",
          yDomain = "$pae_domain",
          xLabel = "pLDDT Total (higher is better) →",
          yLabel = "↑ pAE Interaction (lower is better)",
          xLabelAnchor = "center",
          yLabelAnchor = "center",
          marginTop = 0,
          marginLeft = 40,
          marginRight = 0,
          width = 600,
          height = 450
        ),
        # Side histogram
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
          colorDomain = "Fixed"
        )
      )
    ),

    # Spacing
    list(vspace = "1em"),

    # Data table
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
      height = 215,
      width = 680
    )
  )
)

# Run with the new export function
runMosaicApp(
  spec = protein_spec,
  specType = "json",
  data = list(proteins = protein_data),
  title = "Protein Design Explorer with Selection Export"
)




#WASM
runMosaicApp(
  spec = protein_spec,
  specType = "json",
  data = list(proteins = protein_data),
  title = "Protein Design Explorer with Selection Export",
  backend = "wasm"
)







# star example



# install.packages(c("mosaicShiny","duckdb","DBI","jsonlite","yaml"))
library(mosaicShiny)
library(DBI)
library(duckdb)
library(jsonlite)
library(yaml)

# 1) Build the spec as an R list (YAML equivalent)
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
      "  (1.340264 * lambda * cos(t)) /",
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
        list(
          hconcat = list(
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

# 2) Finally, launch the app in your Viewer:
runMosaicApp(
  spec     = gaia_spec,
  specType = "yaml",
  data     = NULL,         # all data is loaded via DuckDB + remote Parquet
  title    = "Gaia Star Catalog"
)

# WASM
runMosaicApp(
  spec     = gaia_spec,
  specType = "yaml",
  data     = NULL,         # all data is loaded via DuckDB + remote Parquet
  title    = "Gaia Star Catalog",
  backend = "wasm"
)











#Dynamic Rendering (on fly version)


# ── 0.  packages ─────────────────────────────────────────────────────────
library(mosaicShiny)

# ── 1.  mock data  ───────────────────────────────────────────────────────
set.seed(42)
n  <- 10000
df <- data.frame(
  x         = runif(n, 0, 100),
  y         = runif(n, 0, 100),
  cell_type = sample(c("TypeA", "TypeB"), n, TRUE, c(0.6, 0.4))
)

# ── 2.  Mosaic spec (YAML as R list) ─────────────────────────────────────
spec <- list(
  meta = list(
    title = "Dynamic Density Raster",
    description = "Zoom in/out – bins stay 2 units wide so resolution sharpens."
  ),

  data = list(spatial = list()),          # df will be registered in DuckDB

  params = list(pixel = 2),               # pixel‑size Param (expose later!)

  plot = list(
    list(                                 # the only mark layer
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
  colorScheme = "viridis"                 # put palette **outside** the mark!
)

# ── 3.  launch ───────────────────────────────────────────────────────────
runMosaicApp(
  spec  = spec,
  data  = list(spatial = df),
  title = "Dynamic Raster Demo"
)

































