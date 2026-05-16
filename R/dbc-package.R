#' dbc: Use Any ADBC Database Driver from R
#'
#' Provides a single entry point for using any ADBC database driver from R.
#' Drivers are installed from the dbc registry via [dbc_install()] and loaded
#' as standard DBI driver objects via [driver()].
#'
#' @section Connecting:
#' \describe{
#'   \item{[driver()]}{Create a DBI driver object for any installed ADBC driver}
#' }
#'
#' @section Driver management:
#' \describe{
#'   \item{[dbc_install()]}{Install a driver from the registry}
#'   \item{[dbc_uninstall()]}{Remove an installed driver}
#'   \item{[dbc_list()]}{List installed drivers}
#'   \item{[dbc_search()]}{Search the registry for available drivers}
#'   \item{[dbc_info()]}{Get registry metadata for a driver}
#'   \item{[dbc_docs()]}{Get documentation URL for a driver}
#' }
#'
#' @section Driver lists (project-level):
#' \describe{
#'   \item{[dbc_init()]}{Create a new dbc.toml driver list}
#'   \item{[dbc_add()]}{Add a driver to the driver list}
#'   \item{[dbc_remove()]}{Remove a driver from the driver list}
#'   \item{[dbc_sync()]}{Install all drivers in the driver list}
#' }
#'
#' @section Authentication:
#' \describe{
#'   \item{[dbc_auth_login()]}{Authenticate with a private registry}
#'   \item{[dbc_auth_logout()]}{Log out from a registry}
#' }
#'
#' @examples
#' \dontrun{
#' # Install and connect
#' dbc::dbc_install("sqlite")
#' con <- DBI::dbConnect(dbc::driver("sqlite"), uri = ":memory:")
#'
#' # Use with DBI
#' DBI::dbWriteTable(con, "mtcars", mtcars)
#' DBI::dbGetQuery(con, "SELECT * FROM mtcars WHERE cyl = 4")
#'
#' # Use with dplyr
#' dplyr::tbl(con, "mtcars") |>
#'   dplyr::filter(cyl == 4) |>
#'   dplyr::collect()
#'
#' DBI::dbDisconnect(con)
#' }
#'
#' @docType package
#' @name dbc-package
#' @aliases dbc
"_PACKAGE"
