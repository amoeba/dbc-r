setClass("DatabricksDriver",     contains = "AdbiDriver")
setClass("DatabricksConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Databricks via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Databricks/Spark driver
#' installed by dbc. Pass the result to [DBI::dbConnect()] to open a
#' connection.
#'
#' Credentials are resolved in the following order:
#' \enumerate{
#'   \item Explicitly supplied \code{token}.
#'   \item Posit Connect viewer OAuth token (via \pkg{connectcreds}, if
#'     available).
#'   \item Posit Connect service-principal OAuth token (via \pkg{connectcreds},
#'     if available).
#'   \item \code{DATABRICKS_TOKEN} environment variable (personal access
#'     token).
#'   \item \code{DATABRICKS_CLIENT_ID} + \code{DATABRICKS_CLIENT_SECRET}
#'     environment variables (OAuth machine-to-machine).
#'   \item Databricks CLI (\code{databricks auth token}) — desktop sessions
#'     only.
#' }
#'
#' @return A \code{DatabricksDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::databricks(),
#'   workspace = "https://myworkspace.azuredatabricks.net",
#'   http_path = "/sql/1.0/warehouses/abc123"
#' )
#' DBI::dbDisconnect(con)
#' }
databricks <- function() {
  new("DatabricksDriver", driver = load_driver("databricks"))
}

#' @param drv A \code{DatabricksDriver} object from [databricks()].
#' @param workspace Databricks workspace URL (e.g.
#'   \code{"https://myworkspace.azuredatabricks.net"}). Defaults to
#'   \code{DATABRICKS_HOST} environment variable.
#' @param http_path HTTP path to the SQL warehouse or cluster. Defaults to
#'   \code{DATABRICKS_HTTP_PATH} environment variable.
#' @param token Personal access token or OAuth token. When omitted, ambient
#'   credential detection is attempted.
#' @param catalog Unity Catalog name.
#' @param schema Schema name.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname databricks
#' @export
setMethod("dbConnect", "DatabricksDriver", function(drv,
  workspace = NULL,
  http_path = NULL,
  token     = NULL,
  catalog   = NULL,
  schema    = NULL,
  ...
) {
  workspace <- workspace %||% or_null(Sys.getenv("DATABRICKS_HOST"))
  http_path <- http_path %||% or_null(Sys.getenv("DATABRICKS_HTTP_PATH"))

  # Ambient credential detection
  token <- token %||% databricks_credentials(workspace)

  opts <- adbc_opts(
    "databricks.server_hostname" = workspace,
    "databricks.http_path"       = http_path,
    "databricks.access_token"    = token,
    "databricks.catalog"         = catalog,
    "databricks.schema"          = schema
  )
  promote_connection("DatabricksConnection", adbi_connect(drv, opts, list(...)))
})

# Internal: detect ambient Databricks credentials when token not supplied.
# Returns a token string or NULL.
databricks_credentials <- function(workspace) {
  # 1. Posit Connect viewer OAuth
  if (requireNamespace("connectcreds", quietly = TRUE)) {
    if (connectcreds::has_viewer_token()) {
      tok <- tryCatch(
        connectcreds::connect_viewer_token(audience = workspace),
        error = function(e) NULL
      )
      if (!is.null(tok) && nzchar(tok)) return(tok)
    }
    # 2. Posit Connect service-principal OAuth
    if (isTRUE(tryCatch(connectcreds::has_service_account_token(),
                        error = function(e) FALSE))) {
      tok <- tryCatch(
        connectcreds::connect_service_account_token(audience = workspace),
        error = function(e) NULL
      )
      if (!is.null(tok) && nzchar(tok)) return(tok)
    }
  }

  # 3. Personal access token from env var
  env_token <- Sys.getenv("DATABRICKS_TOKEN")
  if (nzchar(env_token)) return(env_token)

  # 4. OAuth M2M from env vars
  client_id     <- Sys.getenv("DATABRICKS_CLIENT_ID")
  client_secret <- Sys.getenv("DATABRICKS_CLIENT_SECRET")
  if (nzchar(client_id) && nzchar(client_secret)) {
    tok <- tryCatch(
      databricks_m2m_token(workspace, client_id, client_secret),
      error = function(e) NULL
    )
    if (!is.null(tok)) return(tok)
  }

  # 5. Databricks CLI — desktop sessions only
  is_server <- nzchar(Sys.getenv("RSTUDIO_PROGRAM_MODE")) &&
    Sys.getenv("RSTUDIO_PROGRAM_MODE") != "desktop"
  if (!is_server && !is.null(workspace)) {
    tok <- tryCatch({
      out <- system2("databricks", c("auth", "token", "--host", workspace),
                     stdout = TRUE, stderr = FALSE)
      trimws(out[[1L]])
    }, error = function(e) NULL)
    if (!is.null(tok) && nzchar(tok)) return(tok)
  }

  NULL
}

# Internal: fetch an OAuth M2M token from Databricks.
databricks_m2m_token <- function(workspace, client_id, client_secret) {
  if (!requireNamespace("httr2", quietly = TRUE)) return(NULL)
  host <- sub("^https?://", "", workspace)
  resp <- httr2::request(paste0("https://", host, "/oidc/v1/token")) |>
    httr2::req_auth_basic(client_id, client_secret) |>
    httr2::req_body_form(grant_type = "client_credentials",
                         scope = "all-apis") |>
    httr2::req_perform()
  httr2::resp_body_json(resp)$access_token
}
