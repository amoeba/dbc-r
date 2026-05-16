#' Initialize a new dbc driver list
#'
#' Creates a new \code{dbc.toml} driver list file. Equivalent to running
#' \code{dbc init} on the command line.
#'
#' @param path Path for the driver list file. Defaults to \code{"./dbc.toml"}.
#'   If the path has no file extension, \code{dbc.toml} is appended.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   on failure.
#' @export
dbc_init <- function(path = "./dbc.toml") {
  stopifnot(is.character(path), length(path) == 1L)
  invisible(.Call(C_dbc_init, path))
}
