#' Get registry information about an ADBC driver
#'
#' Equivalent to running \code{dbc info <driver>} on the command line.
#'
#' @param driver Character string naming the driver (e.g. \code{"sqlite"}).
#' @return A named list with elements \code{path}, \code{title},
#'   \code{version}, \code{license}, \code{description}, and \code{platforms}
#'   (a character vector of supported platform tuples).
#' @export
dbc_info <- function(driver) {
  stopifnot(is.character(driver), length(driver) == 1L)
  .Call(C_dbc_info, driver)
}
