setClass("ClickhouseDriver",     contains = "AdbiDriver")
setClass("ClickhouseConnection", contains = "AdbiConnection")

#' DBI-compatible driver for ClickHouse via ADBC
#'
#' Returns a DBI driver object backed by the ADBC ClickHouse driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{ClickhouseDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::clickhouse(),
#'   host     = "localhost",
#'   database = "default",
#'   uid      = "default",
#'   pwd      = ""
#' )
#' DBI::dbDisconnect(con)
#' }
clickhouse <- function() {
  new("ClickhouseDriver", driver = load_driver("clickhouse"))
}

#' @param drv A \code{ClickhouseDriver} object from [clickhouse()].
#' @param host Server hostname. Defaults to \code{"localhost"}.
#' @param port Server port. Defaults to \code{9000} (native protocol).
#' @param database Database name. Defaults to \code{"default"}.
#' @param uid User name. Defaults to \code{"default"}.
#' @param pwd Password.
#' @param uri Full ClickHouse connection URI. When supplied, overrides all
#'   other individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname clickhouse
#' @export
setMethod("dbConnect", "ClickhouseDriver", function(drv,
  host     = "localhost",
  port     = 9000L,
  database = "default",
  uid      = "default",
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("clickhouse", host, port, database, uid, pwd)
  }
  promote_connection("ClickhouseConnection", callNextMethod(drv, uri = uri, ...))
})
