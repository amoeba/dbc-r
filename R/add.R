#' Add a driver to the driver list
#'
#' Adds one or more drivers to a \code{dbc.toml} driver list file.
#' Equivalent to running \code{dbc add <driver>} on the command line.
#'
#' @param driver Character vector of driver names to add. May include
#'   version constraints (e.g. \code{"mysql=0.1.0"} or
#'   \code{"mysql>=1,<2"}).
#' @param path Path to the driver list file. Defaults to \code{"./dbc.toml"}.
#' @param pre Logical. If \code{TRUE}, allow pre-release versions
#'   implicitly. Default \code{FALSE}.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   on failure.
#' @export
dbc_add <- function(driver, path = "./dbc.toml", pre = FALSE) {
  stopifnot(is.character(driver), length(driver) >= 1L)
  stopifnot(is.character(path), length(path) == 1L)
  stopifnot(is.logical(pre), length(pre) == 1L)
  invisible(.Call(C_dbc_add, driver, path, pre))
}
