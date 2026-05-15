#' List installed ADBC drivers
#'
#' Equivalent to running \code{dbc list} on the command line.
#'
#' @return A data frame with columns \code{id}, \code{name}, \code{version},
#'   \code{level} (\code{"user"}, \code{"system"}, or \code{"env"}), and
#'   \code{path}.
#' @export
dbc_list <- function() {
  .Call(C_dbc_list)
}
