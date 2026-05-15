setClass("ExasolDriver",     contains = "AdbiDriver")
setClass("ExasolConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Exasol via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Exasol driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return An \code{ExasolDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::exasol(),
#'   host = "myserver.exasol.com",
#'   uid  = "myuser",
#'   pwd  = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
exasol <- function() {
  new("ExasolDriver", driver = load_driver("exasol"))
}

#' @param drv An \code{ExasolDriver} object from [exasol()].
#' @param host Server hostname.
#' @param port Server port. Defaults to \code{8563}.
#' @param database Schema name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full Exasol connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname exasol
#' @export
setMethod("dbConnect", "ExasolDriver", function(drv,
  host     = NULL,
  port     = 8563L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("exasol", host, port, database, uid, pwd)
  }
  promote_connection("ExasolConnection", callNextMethod(drv, uri = uri, ...))
})
