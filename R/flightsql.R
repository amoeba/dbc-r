setClass("FlightsqlDriver",     contains = "AdbiDriver")
setClass("FlightsqlConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Arrow Flight SQL via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Flight SQL driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{FlightsqlDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::flightsql(),
#'   uri   = "grpc://localhost:32010",
#'   token = "mytoken"
#' )
#' DBI::dbDisconnect(con)
#' }
flightsql <- function() {
  new("FlightsqlDriver", driver = load_driver("flightsql"))
}

#' @param drv A \code{FlightsqlDriver} object from [flightsql()].
#' @param uri Server URI (e.g. \code{"grpc://localhost:32010"} or
#'   \code{"grpc+tls://host:443"}).
#' @param token Bearer token for authentication. Translated to the
#'   \code{adbc.flight.sql.authorization_header} ADBC option as
#'   \code{"Bearer <token>"}.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname flightsql
#' @export
setMethod("dbConnect", "FlightsqlDriver", function(drv,
  uri   = NULL,
  token = NULL,
  ...
) {
  auth_header <- if (!is.null(token)) paste0("Bearer ", token) else NULL
  opts <- adbc_opts(
    uri                                        = uri,
    "adbc.flight.sql.authorization_header"    = auth_header
  )
  promote_connection("FlightsqlConnection", adbi_connect(drv, opts, list(...)))
})
