setClass("SinglestoreDriver",     contains = "AdbiDriver")
setClass("SinglestoreConnection", contains = "AdbiConnection")

#' DBI-compatible driver for SingleStore via ADBC
#'
#' Returns a DBI driver object backed by the ADBC SingleStore driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{SinglestoreDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::singlestore(),
#'   host     = "myhost.singlestore.com",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
singlestore <- function() {
  new("SinglestoreDriver", driver = load_driver("singlestore"))
}

#' @param drv A \code{SinglestoreDriver} object from [singlestore()].
#' @param host Server hostname.
#' @param port Server port. Defaults to \code{3306}.
#' @param database Database name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname singlestore
#' @export
setMethod("dbConnect", "SinglestoreDriver", function(drv,
  host     = NULL,
  port     = 3306L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("mysql", host, port, database, uid, pwd)
  }
  promote_connection("SinglestoreConnection", callNextMethod(drv, uri = uri, ...))
})
