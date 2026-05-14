#' Search for available ADBC drivers
#'
#' Queries the dbc registry for drivers whose name contains \code{pattern}.
#' An empty string (the default) returns all available drivers.
#'
#' @param pattern Character string to filter driver names. Default \code{""}
#'   returns all drivers.
#' @return A character vector of driver names.
#' @export
search <- function(pattern = "") {
  stopifnot(is.character(pattern), length(pattern) == 1L)
  .Call(C_dbc_search, pattern)
}
