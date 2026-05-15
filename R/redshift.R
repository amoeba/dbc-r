setClass("RedshiftDriver",     contains = "AdbiDriver")
setClass("RedshiftConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Amazon Redshift via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Redshift driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' Redshift uses the PostgreSQL wire protocol, so connection URIs follow the
#' same \code{postgresql://} scheme.
#'
#' When \code{iam = TRUE} (or when no \code{uid}/\code{pwd} are supplied and
#' AWS credentials are detected), temporary database credentials are obtained
#' via the AWS Redshift API. This requires the \pkg{paws.common} package to
#' locate credentials and \pkg{paws.database} to exchange them for a temporary
#' username and password. \code{cluster_id} must be provided for IAM auth.
#'
#' @return A \code{RedshiftDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' # Standard user/password
#' con <- DBI::dbConnect(dbc::redshift(),
#'   host     = "my-cluster.abc123.us-east-1.redshift.amazonaws.com",
#'   database = "mydb",
#'   uid      = "myuser",
#'   pwd      = "mypassword"
#' )
#'
#' # IAM authentication (requires paws.common + paws.database)
#' con <- DBI::dbConnect(dbc::redshift(),
#'   host       = "my-cluster.abc123.us-east-1.redshift.amazonaws.com",
#'   database   = "mydb",
#'   iam        = TRUE,
#'   cluster_id = "my-cluster",
#'   region     = "us-east-1"
#' )
#' DBI::dbDisconnect(con)
#' }
redshift <- function() {
  new("RedshiftDriver", driver = load_driver("redshift"))
}

#' @param drv A \code{RedshiftDriver} object from [redshift()].
#' @param host Cluster endpoint hostname.
#' @param port Server port. Defaults to \code{5439}.
#' @param database Database name.
#' @param uid User name.
#' @param pwd Password.
#' @param iam Use IAM authentication to obtain temporary database credentials.
#'   Defaults to \code{FALSE}. When \code{TRUE}, requires \pkg{paws.common},
#'   \pkg{paws.database}, and \code{cluster_id}.
#' @param cluster_id Redshift cluster identifier. Required when \code{iam = TRUE}.
#' @param region AWS region (e.g. \code{"us-east-1"}). Inferred from the AWS
#'   credential chain when omitted.
#' @param uri Full connection URI. When supplied, overrides all other
#'   individual parameters.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname redshift
#' @export
setMethod("dbConnect", "RedshiftDriver", function(drv,
  host       = NULL,
  port       = 5439L,
  database   = NULL,
  uid        = NULL,
  pwd        = NULL,
  iam        = FALSE,
  cluster_id = NULL,
  region     = NULL,
  uri        = NULL,
  ...
) {
  creds <- redshift_credentials(iam = iam, uid = uid, pwd = pwd,
                                database = database, cluster_id = cluster_id,
                                region = region)
  uid <- creds$uid
  pwd <- creds$pwd

  if (is.null(uri)) {
    uri <- build_uri("postgresql", host, port, database, uid, pwd)
  }
  promote_connection("RedshiftConnection", callNextMethod(drv, uri = uri, ...))
})

# Internal: resolve Redshift credentials.
# Returns list(uid, pwd) — either the originals or IAM-derived temp creds.
redshift_credentials <- function(iam, uid, pwd, database, cluster_id, region) {
  # Explicit uid + pwd — nothing to do
  if (!is.null(uid) && !is.null(pwd)) {
    return(list(uid = uid, pwd = pwd))
  }

  if (!requireNamespace("paws.common", quietly = TRUE)) {
    return(list(uid = uid, pwd = pwd))
  }

  aws_creds <- tryCatch(paws.common::locate_credentials(),
                        error = function(e) NULL)
  if (is.null(aws_creds) || !nzchar(aws_creds$access_key_id %||% "")) {
    return(list(uid = uid, pwd = pwd))
  }

  # AWS credentials found — proceed with IAM temp credential exchange
  if (!requireNamespace("paws.database", quietly = TRUE)) {
    if (iam) {
      warning("paws.database is required for Redshift IAM authentication; ",
              "falling back to uid/pwd")
    }
    return(list(uid = uid, pwd = pwd))
  }

  if (is.null(cluster_id)) {
    if (iam) stop("cluster_id is required for Redshift IAM authentication")
    return(list(uid = uid, pwd = pwd))
  }

  svc <- paws.database::redshift(config = list(
    credentials = list(creds = list(
      access_key_id     = aws_creds$access_key_id,
      secret_access_key = aws_creds$secret_access_key,
      session_token     = aws_creds$session_token %||% ""
    )),
    region = region %||% or_null(aws_creds$region %||% "")
  ))

  resp <- tryCatch(
    svc$get_cluster_credentials(
      DbUser            = uid %||% Sys.info()[["user"]],
      DbName            = database,
      ClusterIdentifier = cluster_id,
      AutoCreate        = FALSE
    ),
    error = function(e) {
      if (iam) stop(e)
      NULL
    }
  )

  if (is.null(resp)) return(list(uid = uid, pwd = pwd))
  list(uid = resp$DbUser, pwd = resp$DbPassword)
}
