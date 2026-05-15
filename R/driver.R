# Return y if x is NULL, else x.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Return NULL if s is an empty string (i.e. Sys.getenv() found nothing).
or_null <- function(s) if (nzchar(s)) s else NULL

# Build a standard connection URI from parts. Returns NULL if host is absent.
# Used by per-driver dbConnect() methods when the caller omits the uri param.
build_uri <- function(scheme, host, port, database = NULL,
                      uid = NULL, pwd = NULL) {
  if (is.null(host) || !nzchar(host)) return(NULL)
  auth <- ""
  if (!is.null(uid) && nzchar(uid)) {
    auth <- if (!is.null(pwd) && nzchar(pwd)) {
      paste0(uid, ":", pwd, "@")
    } else {
      paste0(uid, "@")
    }
  }
  db <- if (!is.null(database) && nzchar(database)) paste0("/", database) else ""
  paste0(scheme, "://", auth, host, ":", port, db)
}

# Drop NULL entries from a named list of ADBC options.
adbc_opts <- function(...) Filter(Negate(is.null), list(...))

# Call adbi's dbConnect(AdbiDriver, ...) directly, bypassing our per-driver
# S4 dispatch. Used when we need to assemble opts via do.call rather than
# passing them as literal arguments (where callNextMethod would be fragile).
adbi_connect <- function(drv, opts, dots) {
  base_drv <- new("AdbiDriver", driver = drv@driver)
  do.call(DBI::dbConnect, c(list(base_drv), opts, dots))
}

# Promote an AdbiConnection to a per-driver subclass by copying all slots.
promote_connection <- function(class, con) {
  new(class,
      database               = con@database,
      connection             = con@connection,
      metadata               = con@metadata,
      bigint                 = con@bigint,
      rows_affected_callback = con@rows_affected_callback)
}

# Internal helper used by all driver constructor functions (sqlite, snowflake,
# etc.). Tries to load the named ADBC driver; if the load fails and
# getOption("dbc.autoinstall") is TRUE (the default), installs the driver
# first and retries.
load_driver <- function(name) {
  result <- tryCatch(
    adbcdrivermanager::adbc_driver(name),
    error = function(e) e
  )

  if (!inherits(result, "error")) {
    return(result)
  }

  if (!isTRUE(getOption("dbc.autoinstall", default = TRUE))) {
    stop(result)
  }

  message("Driver '", name, "' not found, installing via dbc...")
  dbc_install(name)
  adbcdrivermanager::adbc_driver(name)
}
