#' Sync installed drivers with a driver list
#'
#' Installs all drivers specified in a \code{dbc.toml} driver list file.
#' Equivalent to running \code{dbc sync} on the command line.
#'
#' @param path Path to the driver list file. Defaults to \code{"./dbc.toml"}.
#' @param level Config level to install to: \code{"user"} (default) or
#'   \code{"system"}.
#' @param no_verify Logical. If \code{TRUE}, allow installation of drivers
#'   without a signature file. Default \code{FALSE}.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   on failure.
#' @export
dbc_sync <- function(path = "./dbc.toml", level = NULL, no_verify = FALSE) {
  stopifnot(is.character(path), length(path) == 1L)
  if (!is.null(level)) {
    stopifnot(is.character(level), length(level) == 1L)
    level <- match.arg(level, c("user", "system"))
  }
  stopifnot(is.logical(no_verify), length(no_verify) == 1L)
  invisible(.Call(C_dbc_sync, path, level, no_verify))
}
