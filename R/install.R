#' Install an ADBC driver
#'
#' Equivalent to running \code{dbc install <driver>} on the command line.
#'
#' @param driver Character string naming the driver to install (e.g.
#'   \code{"snowflake"}).
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   message on failure.
#' @export
install <- function(driver) {
  stopifnot(is.character(driver), length(driver) == 1L)
  invisible(.Call(C_dbc_install, driver))
}
