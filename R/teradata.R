setClass("TeradataDriver",     contains = "AdbiDriver")
setClass("TeradataConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Teradata via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Teradata driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{TeradataDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::teradata(),
#'   host     = "myserver.teradata.com",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
teradata <- function() {
  new("TeradataDriver", driver = load_driver("teradata"))
}

#' @param drv A \code{TeradataDriver} object from [teradata()].
#' @param host Server hostname.
#' @param port Server port. Defaults to \code{1025}.
#' @param database Database name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname teradata
#' @export
setMethod("dbConnect", "TeradataDriver", function(drv,
  host     = NULL,
  port     = 1025L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("teradata", host, port, database, uid, pwd)
  }
  promote_connection("TeradataConnection", callNextMethod(drv, uri = uri, ...))
})
