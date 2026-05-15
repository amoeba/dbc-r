setClass("PostgresqlDriver",     contains = "AdbiDriver")
setClass("PostgresqlConnection", contains = "AdbiConnection")

#' DBI-compatible driver for PostgreSQL via ADBC
#'
#' Returns a DBI driver object backed by the ADBC PostgreSQL driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{PostgresqlDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::postgresql(),
#'   host     = "localhost",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
postgresql <- function() {
  new("PostgresqlDriver", driver = load_driver("postgresql"))
}

#' @param drv A \code{PostgresqlDriver} object from [postgresql()].
#' @param host Server hostname. Defaults to \code{Sys.getenv("PGHOST")},
#'   then \code{"localhost"}.
#' @param port Server port. Defaults to \code{5432}.
#' @param database Database name. Defaults to \code{Sys.getenv("PGDATABASE")}.
#' @param uid User name. Defaults to \code{Sys.getenv("PGUSER")}.
#' @param pwd Password. Defaults to \code{Sys.getenv("PGPASSWORD")}.
#' @param uri Full libpq connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname postgresql
#' @export
setMethod("dbConnect", "PostgresqlDriver", function(drv,
  host     = NULL,
  port     = 5432L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    host     <- host     %||% Sys.getenv("PGHOST",     "localhost")
    database <- database %||% or_null(Sys.getenv("PGDATABASE"))
    uid      <- uid      %||% or_null(Sys.getenv("PGUSER"))
    pwd      <- pwd      %||% or_null(Sys.getenv("PGPASSWORD"))
    uri <- build_uri("postgresql", host, port, database, uid, pwd)
  }
  promote_connection("PostgresqlConnection", callNextMethod(drv, uri = uri, ...))
})
