# Return y if x is NULL, else x.
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Create a DBI driver for any ADBC-supported database
#'
#' Returns a DBI driver object backed by the named ADBC driver. The driver
#' must be installed first via [dbc_install()].
#'
#' Pass the result to [DBI::dbConnect()] along with connection options
#' (typically \code{uri} or driver-specific key-value pairs).
#'
#' @param name Driver name (e.g. \code{"sqlite"}, \code{"snowflake"},
#'   \code{"postgresql"}, \code{"duckdb"}). Use [dbc_search()] to discover
#'   available drivers.
#' @return A \code{DbcDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' # SQLite
#' con <- DBI::dbConnect(dbc::driver("sqlite"), uri = ":memory:")
#'
#' # Snowflake
#' con <- DBI::dbConnect(dbc::driver("snowflake"),
#'   "adbc.snowflake.sql.account" = "myorg-myaccount"
#' )
#'
#' # PostgreSQL
#' con <- DBI::dbConnect(dbc::driver("postgresql"),
#'   uri = "postgresql://user:pass@localhost:5432/mydb"
#' )
#'
#' DBI::dbDisconnect(con)
#' }
driver <- function(name) {
  new("DbcDriver", driver = load_driver(name), name = name)
}

setClass("DbcDriver", contains = "AdbiDriver", slots = list(name = "character"))

#' @param drv A \code{DbcDriver} object from [driver()].
#' @param ... Connection options passed to the ADBC driver (e.g. \code{uri},
#'   or driver-specific options like
#'   \code{"adbc.snowflake.sql.account" = "..."}).
#' @rdname driver
#' @export
setMethod("dbConnect", "DbcDriver", function(drv, ...) {
  con <- callNextMethod()
  dots <- list(...)
  # Best-effort display name: use uri, or first named option value, or driver name
  label <- dots$uri %||% dots[[1]] %||% drv@name
  register_connection_observer(con,
    type         = drv@name,
    display_name = label,
    host         = dots$uri %||% label,
    connect_code = paste0('DBI::dbConnect(dbc::driver("', drv@name, '"), ...)'))
  con
})

# Internal: load a named ADBC driver.
load_driver <- function(name) {
  adbcdrivermanager::adbc_driver(name)
}

# ---------------------------------------------------------------------------
# Connection observer (RStudio / Positron Connections pane)
# ---------------------------------------------------------------------------

# Registry mapping connection keys to observer metadata.
.dbc_obs <- new.env(hash = TRUE, parent = emptyenv())
.dbc_obs$.next_id <- 1L

# Register a connection with the IDE Connections pane.
# Works identically in RStudio and Positron (both set the connectionObserver
# option with the same callback interface).
register_connection_observer <- function(con, type, display_name, host,
                                          connect_code) {
  observer <- getOption("connectionObserver")
  if (is.null(observer)) return(invisible(con))

  key <- as.character(.dbc_obs$.next_id)
  .dbc_obs$.next_id <- .dbc_obs$.next_id + 1L
  .dbc_obs[[key]] <- list(type = type, host = host %||% "",
                           display_name = display_name)
  attr(con, ".dbc_obs_key") <- key

  observer$connectionOpened(
    type             = type,
    displayName      = display_name,
    host             = host %||% "",
    connectCode      = connect_code,
    disconnect       = function() DBI::dbDisconnect(con),
    connectionObject = con,
    listObjectTypes  = function() {
      list(schema = list(contains = list(table = list(contains = "data"))))
    },
    listObjects      = function(schema = NULL, ...) {
      if (is.null(schema)) {
        schemas <- tryCatch(
          DBI::dbGetQuery(con,
            "SELECT schema_name FROM information_schema.schemata")[[1]],
          error = function(e) character(0))
        data.frame(name = schemas, type = "schema", stringsAsFactors = FALSE)
      } else {
        tbls <- tryCatch(DBI::dbListTables(con),
                         error = function(e) character(0))
        data.frame(name = tbls, type = "table", stringsAsFactors = FALSE)
      }
    },
    listColumns      = function(schema = NULL, table = NULL, ...) {
      tbl <- if (!is.null(schema)) DBI::Id(schema = schema, table = table) else table
      fields <- tryCatch(DBI::dbListFields(con, tbl),
                         error = function(e) character(0))
      data.frame(name = fields, type = "column", stringsAsFactors = FALSE)
    },
    previewObject    = function(rowLimit, schema = NULL, table = NULL, ...) {
      tryCatch(
        DBI::dbGetQuery(con, paste("SELECT * FROM", table, "LIMIT", rowLimit)),
        error = function(e) data.frame()
      )
    }
  )
  invisible(con)
}

setMethod("dbDisconnect", "AdbiConnection", function(conn, ...) {
  observer <- getOption("connectionObserver")
  if (!is.null(observer)) {
    key  <- attr(conn, ".dbc_obs_key")
    meta <- if (!is.null(key)) .dbc_obs[[key]] else NULL
    if (!is.null(meta)) {
      observer$connectionClosed(type        = meta$type,
                                 host        = meta$host,
                                 displayName = meta$display_name)
      rm(list = key, envir = .dbc_obs)
    }
  }
  getMethod("dbDisconnect", "AdbiConnection",
            where = asNamespace("adbi"))(conn, ...)
})
