#' Install an ADBC driver
#'
#' Equivalent to running \code{dbc install <driver>} on the command line.
#' Displays a download progress bar powered by the \pkg{cli} package.
#'
#' @param driver Character string naming the driver to install (e.g.
#'   \code{"snowflake"}). May include a version constraint (e.g.
#'   \code{"mysql=0.1.0"} or \code{"mysql>=1,<2"}).
#' @param level Config level to install to: \code{"user"} (default) or
#'   \code{"system"}.
#' @param no_verify Logical. If \code{TRUE}, allow installation of drivers
#'   without a signature file. Default \code{FALSE}.
#' @param pre Logical. If \code{TRUE}, allow installation of pre-release
#'   versions. Default \code{FALSE}.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   message on failure.
#' @export
dbc_install <- function(driver, level = NULL, no_verify = FALSE, pre = FALSE) {
  stopifnot(is.character(driver), length(driver) == 1L)
  if (!is.null(level)) {
    stopifnot(is.character(level), length(level) == 1L)
    level <- match.arg(level, c("user", "system"))
  }
  stopifnot(is.logical(no_verify), length(no_verify) == 1L)
  stopifnot(is.logical(pre), length(pre) == 1L)
  invisible(.Call(C_dbc_install, driver, level, no_verify, pre))
}
