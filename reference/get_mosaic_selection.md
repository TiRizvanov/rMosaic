# Retrieve a stored Mosaic selection

After pressing "Import Selection" in a
[`runMosaicWithExport`](https://tirizvanov.github.io/rMosaic/reference/runMosaicWithExport.md)
app, the selected data are stored inside the package under the name
printed in the status bar (e.g. `"mosaic_sel_1"`). Use this function to
retrieve a selection by that name.

## Usage

``` r
get_mosaic_selection(name)
```

## Arguments

- name:

  Character scalar: the variable name returned by the import button
  (e.g. `"mosaic_sel_1"`).

## Value

The stored `data.frame`, or `NULL` with a warning if the name is not
found.

## See also

[`list_mosaic_selections`](https://tirizvanov.github.io/rMosaic/reference/list_mosaic_selections.md)
