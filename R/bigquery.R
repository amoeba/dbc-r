setClass("BigqueryDriver",     contains = "AdbiDriver")
setClass("BigqueryConnection", contains = "AdbiConnection")

#' DBI-compatible driver for BigQuery via ADBC
#'
#' Returns a DBI driver object backed by the ADBC BigQuery driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' Authentication uses Application Default Credentials (ADC) by default.
#' Set \code{GOOGLE_APPLICATION_CREDENTIALS} to a service account key file,
#' or run \code{gcloud auth application-default login} to authenticate
#' interactively.
#'
#' @return A \code{BigqueryDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::bigquery(),
#'   project_id = "my-gcp-project",
#'   dataset    = "my_dataset"
#' )
#' DBI::dbDisconnect(con)
#' }
bigquery <- function() {
  new("BigqueryDriver", driver = load_driver("bigquery"))
}

#' @param drv A \code{BigqueryDriver} object from [bigquery()].
#' @param project_id GCP project ID. Defaults to \code{BIGQUERY_PROJECT}
#'   (then \code{GCLOUD_PROJECT} / \code{GOOGLE_CLOUD_PROJECT}) environment
#'   variables.
#' @param dataset Default dataset name.
#' @param auth_type Authentication type passed to the ADBC driver (e.g.
#'   \code{"service_account"}, \code{"user"}, \code{"workload_identity"}).
#'   When \code{NULL} the driver uses Application Default Credentials.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname bigquery
#' @export
setMethod("dbConnect", "BigqueryDriver", function(drv,
  project_id = NULL,
  dataset    = NULL,
  auth_type  = NULL,
  ...
) {
  project_id <- project_id %||%
    or_null(Sys.getenv("BIGQUERY_PROJECT")) %||%
    or_null(Sys.getenv("GCLOUD_PROJECT")) %||%
    or_null(Sys.getenv("GOOGLE_CLOUD_PROJECT"))

  opts <- adbc_opts(
    "adbc.bigquery.sql.project_id" = project_id,
    "adbc.bigquery.sql.dataset_id" = dataset,
    "adbc.bigquery.sql.auth_type"  = auth_type
  )
  promote_connection("BigqueryConnection", adbi_connect(drv, opts, list(...)))
})
