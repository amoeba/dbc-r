setClass("RedshiftDriver",     contains = "AdbiDriver")
setClass("RedshiftConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Amazon Redshift via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Redshift driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' Redshift uses the PostgreSQL wire protocol, so connection URIs follow the
#' same \code{postgresql://} scheme.
#'
#' @return A \code{RedshiftDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::redshift(),
#'   host     = "my-cluster.abc123.us-east-1.redshift.amazonaws.com",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
redshift <- function() {
  new("RedshiftDriver", driver = load_driver("redshift"))
}

#' @param drv A \code{RedshiftDriver} object from [redshift()].
#' @param host Cluster endpoint hostname.
#' @param port Server port. Defaults to \code{5439}.
#' @param database Database name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname redshift
#' @export
setMethod("dbConnect", "RedshiftDriver", function(drv,
  host     = NULL,
  port     = 5439L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("postgresql", host, port, database, uid, pwd)
  }
  promote_connection("RedshiftConnection", callNextMethod(drv, uri = uri, ...))
})
