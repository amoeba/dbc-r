setClass("TrinoDriver",     contains = "AdbiDriver")
setClass("TrinoConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Trino via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Trino driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{TrinoDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::trino(),
#'   host    = "trino.example.com",
#'   catalog = "hive",
#'   schema  = "default",
#'   uid     = "myuser"
#' )
#' DBI::dbDisconnect(con)
#' }
trino <- function() {
  new("TrinoDriver", driver = load_driver("trino"))
}

#' @param drv A \code{TrinoDriver} object from [trino()].
#' @param host Server hostname.
#' @param port Server port. Defaults to \code{8080}.
#' @param catalog Catalog name.
#' @param schema Schema name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full Trino connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname trino
#' @export
setMethod("dbConnect", "TrinoDriver", function(drv,
  host    = NULL,
  port    = 8080L,
  catalog = NULL,
  schema  = NULL,
  uid     = NULL,
  pwd     = NULL,
  uri     = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("http", host, port, catalog, uid, pwd)
  }
  opts <- adbc_opts(
    uri                    = uri,
    "adbc.trino.schema"   = schema
  )
  promote_connection("TrinoConnection", adbi_connect(drv, opts, list(...)))
})
