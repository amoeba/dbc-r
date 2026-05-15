setClass("DuckdbDriver",     contains = "AdbiDriver")
setClass("DuckdbConnection", contains = "AdbiConnection")

#' DBI-compatible driver for DuckDB via ADBC
#'
#' Returns a DBI driver object backed by the ADBC DuckDB driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{DuckdbDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::duckdb(), uri = ":memory:")
#' DBI::dbDisconnect(con)
#' }
duckdb <- function() {
  new("DuckdbDriver", driver = load_driver("duckdb"))
}

#' @param drv A \code{DuckdbDriver} object from [duckdb()].
#' @param uri Path to a DuckDB database file, or \code{":memory:"} for an
#'   in-memory database. Defaults to \code{":memory:"}.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname duckdb
#' @export
setMethod("dbConnect", "DuckdbDriver", function(drv, uri = ":memory:", ...) {
  promote_connection("DuckdbConnection", callNextMethod(drv, uri = uri, ...))
})
