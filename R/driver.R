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
  install(name)
  adbcdrivermanager::adbc_driver(name)
}
