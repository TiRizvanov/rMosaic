# Shiny render function for Mosaic

Use this in the server to render the Mosaic visualization to the output.

## Usage

``` r
renderMosaic(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- expr:

  An expression that generates a call to
  [`mosaic()`](https://tirizvanov.github.io/rMosaic/reference/mosaic.md).

- env:

  The environment in which to evaluate `expr`.

- quoted:

  Is `expr` a quoted expression (with
  [`quote()`](https://rdrr.io/r/base/substitute.html))? This is useful
  if you want to save an expression in a variable.

## Value

A Shiny render function for use in a server output assignment.
