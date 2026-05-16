#' Search for available ADBC drivers
#'
#' Queries the dbc registry for drivers whose name contains \code{pattern}.
#' An empty string (the default) returns all available drivers.
#'
#' @param pattern Character string to filter driver names. Default \code{""}
#'   returns all drivers.
#' @param pre Logical. If \code{TRUE}, include pre-release drivers and
#'   versions (hidden by default). Default \code{FALSE}.
#' @return A character vector of driver names.
#' @export
dbc_search <- function(pattern = "", pre = FALSE) {
  stopifnot(is.character(pattern), length(pattern) == 1L)
  stopifnot(is.logical(pre), length(pre) == 1L)
  .Call(C_dbc_search, pattern, pre)
}
