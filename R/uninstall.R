#' Uninstall an ADBC driver
#'
#' Equivalent to running \code{dbc uninstall <driver>} on the command line.
#'
#' @param driver Character string naming the driver to uninstall.
#' @return Invisibly returns \code{NULL} on success; stops with an error on
#'   failure.
#' @export
dbc_uninstall <- function(driver) {
  stopifnot(is.character(driver), length(driver) == 1L)
  invisible(.Call(C_dbc_uninstall, driver))
}
