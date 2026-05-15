setClass("OracleDriver",     contains = "AdbiDriver")
setClass("OracleConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Oracle via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Oracle driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return An \code{OracleDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::oracle(),
#'   host     = "localhost",
#'   port     = 1521L,
#'   database = "ORCL",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
oracle <- function() {
  new("OracleDriver", driver = load_driver("oracle"))
}

#' @param drv An \code{OracleDriver} object from [oracle()].
#' @param host Server hostname.
#' @param port Server port. Defaults to \code{1521}.
#' @param database Service name or SID.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full Oracle connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname oracle
#' @export
setMethod("dbConnect", "OracleDriver", function(drv,
  host     = NULL,
  port     = 1521L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("oracle", host, port, database, uid, pwd)
  }
  promote_connection("OracleConnection", callNextMethod(drv, uri = uri, ...))
})
