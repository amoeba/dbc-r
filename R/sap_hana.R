setClass("SapHanaDriver",     contains = "AdbiDriver")
setClass("SapHanaConnection", contains = "AdbiConnection")

#' DBI-compatible driver for SAP HANA via ADBC
#'
#' Returns a DBI driver object backed by the ADBC SAP HANA driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' @return A \code{SapHanaDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::sap_hana(),
#'   host = "myserver.hanacloud.ondemand.com",
#'   port = 443L,
#'   uid  = "myuser",
#'   pwd  = "mypassword"
#' )
#' DBI::dbDisconnect(con)
#' }
sap_hana <- function() {
  new("SapHanaDriver", driver = load_driver("sap-hana"))
}

#' @param drv A \code{SapHanaDriver} object from [sap_hana()].
#' @param host Server hostname.
#' @param port Server port. Defaults to \code{443}.
#' @param database Schema/database name.
#' @param uid User name.
#' @param pwd Password.
#' @param uri Full connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname sap_hana
#' @export
setMethod("dbConnect", "SapHanaDriver", function(drv,
  host     = NULL,
  port     = 443L,
  database = NULL,
  uid      = NULL,
  pwd      = NULL,
  uri      = NULL,
  ...
) {
  if (is.null(uri)) {
    uri <- build_uri("hana", host, port, database, uid, pwd)
  }
  promote_connection("SapHanaConnection", callNextMethod(drv, uri = uri, ...))
})
