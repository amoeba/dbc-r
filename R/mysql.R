setClass("MysqlDriver",     contains = "AdbiDriver")
setClass("MysqlConnection", contains = "AdbiConnection")

#' DBI-compatible driver for MySQL via ADBC
#'
#' Returns a DBI driver object backed by the ADBC MySQL driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{MysqlDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::mysql(),
#'   host     = "localhost",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
mysql <- function() {
  new("MysqlDriver", driver = load_driver("mysql"))
}

#' @param drv A \code{MysqlDriver} object from [mysql()].
#' @param host Server hostname. Defaults to \code{"localhost"}.
#' @param port Server port. Defaults to \code{3306}.
#' @param database Database name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full MySQL connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname mysql
#' @export
setMethod("dbConnect", "MysqlDriver", function(drv,
  host     = "localhost",
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
  promote_connection("MysqlConnection", callNextMethod(drv, uri = uri, ...))
})
