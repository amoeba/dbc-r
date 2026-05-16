#' Get driver documentation URL
#'
#' Returns the documentation URL for a driver. Equivalent to running
#' \code{dbc docs --no-open <driver>} on the command line.
#'
#' @param driver Character string naming the driver. If \code{NULL} or
#'   \code{""}, returns the main dbc documentation URL.
#' @return A character string containing the documentation URL.
#' @export
dbc_docs <- function(driver = NULL) {
  if (is.null(driver)) driver <- ""
  stopifnot(is.character(driver), length(driver) == 1L)
  .Call(C_dbc_docs, driver)
}
