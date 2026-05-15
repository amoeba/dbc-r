setClass("SqliteDriver",     contains = "AdbiDriver")
setClass("SqliteConnection", contains = "AdbiConnection")

#' DBI-compatible driver for SQLite via ADBC
#'
#' Returns a DBI driver object backed by the ADBC SQLite driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection. The
#' \code{uri} argument (path to a database file, or \code{":memory:"}) is
#' passed to [DBI::dbConnect()], not here.
#'
#' @return A \code{SqliteDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::sqlite(), uri = ":memory:")
#' DBI::dbDisconnect(con)
#' }
sqlite <- function() {
  new("SqliteDriver", driver = load_driver("sqlite"))
}

#' @param drv A \code{SqliteDriver} object from [sqlite()].
#' @param uri Path to a SQLite database file, or \code{":memory:"} for an
#'   in-memory database. Defaults to \code{":memory:"}.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname sqlite
#' @export
setMethod("dbConnect", "SqliteDriver", function(drv, uri = ":memory:", ...) {
  promote_connection("SqliteConnection", callNextMethod(drv, uri = uri, ...))
})
