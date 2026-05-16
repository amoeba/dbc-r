#' Uninstall an ADBC driver
#'
#' Equivalent to running \code{dbc uninstall <driver>} on the command line.
#'
#' @param driver Character string naming the driver to uninstall.
#' @param level Config level to uninstall from: \code{"user"} (default) or
#'   \code{"system"}.
#' @return Invisibly returns \code{NULL} on success; stops with an error on
#'   failure.
#' @export
dbc_uninstall <- function(driver, level = NULL) {
  stopifnot(is.character(driver), length(driver) == 1L)
  if (!is.null(level)) {
    stopifnot(is.character(level), length(level) == 1L)
    level <- match.arg(level, c("user", "system"))
  }
  invisible(.Call(C_dbc_uninstall, driver, level))
}
