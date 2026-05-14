#' DBI-compatible driver for SQLite via ADBC
#'
#' Returns a DBI driver object backed by the ADBC SQLite driver installed by
#' dbc. Pass the result to [DBI::dbConnect()] to open a connection. The
#' \code{uri} argument (path to a database file, or \code{":memory:"}) is
#' passed to [DBI::dbConnect()], not here.
#'
#' @return An S4 object of class \code{AdbiDriver} (from the \pkg{adbi}
#'   package) that can be passed to [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::sqlite(), uri = ":memory:")
#' DBI::dbDisconnect(con)
#' }
sqlite <- function() {
  if (!requireNamespace("adbi", quietly = TRUE)) {
    stop("Package 'adbi' is required. Install it with install.packages('adbi').")
  }
  if (!requireNamespace("adbcdrivermanager", quietly = TRUE)) {
    stop("Package 'adbcdrivermanager' is required. Install it with install.packages('adbcdrivermanager').")
  }

  adbi::adbi(load_driver("sqlite"))
}
