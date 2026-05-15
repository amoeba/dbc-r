setClass("MssqlDriver",     contains = "AdbiDriver")
setClass("MssqlConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Microsoft SQL Server via ADBC
#'
#' Returns a DBI driver object backed by the ADBC SQL Server driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{MssqlDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::mssql(),
#'   server   = "myserver.database.windows.net",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
mssql <- function() {
  new("MssqlDriver", driver = load_driver("mssql"))
}

#' @param drv A \code{MssqlDriver} object from [mssql()].
#' @param server Server hostname or address.
#' @param port Server port. Defaults to \code{1433}.
#' @param database Database name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname mssql
#' @export
setMethod("dbConnect", "MssqlDriver", function(drv,
  server   = NULL,
  port     = 1433L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("mssql", server, port, database, uid, pwd)
  }
  promote_connection("MssqlConnection", callNextMethod(drv, uri = uri, ...))
})
