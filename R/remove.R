#' Remove a driver from the driver list
#'
#' Removes a driver from a \code{dbc.toml} driver list file.
#' Equivalent to running \code{dbc remove <driver>} on the command line.
#'
#' @param driver Character string naming the driver to remove.
#' @param path Path to the driver list file. Defaults to \code{"./dbc.toml"}.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   on failure.
#' @export
dbc_remove <- function(driver, path = "./dbc.toml") {
  stopifnot(is.character(driver), length(driver) == 1L)
  stopifnot(is.character(path), length(path) == 1L)
  invisible(.Call(C_dbc_remove, driver, path))
}
