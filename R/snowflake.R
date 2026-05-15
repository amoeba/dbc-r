setClass("SnowflakeDriver",     contains = "AdbiDriver")
setClass("SnowflakeConnection", contains = "AdbiConnection")

#' DBI-compatible driver for Snowflake via ADBC
#'
#' Returns a DBI driver object backed by the ADBC Snowflake driver installed
#' by dbc. Pass the result to [DBI::dbConnect()] to open a connection.
#'
#' Credentials are resolved in the following order:
#' \enumerate{
#'   \item Explicitly supplied \code{uid}/\code{pwd} or \code{token}.
#'   \item Posit Connect viewer token (via \pkg{connectcreds}, if available).
#'   \item Token file at \code{/snowflake/session/token} (Snowpark Container
#'     Services).
#'   \item \code{SNOWFLAKE_TOKEN} environment variable.
#' }
#'
#' @return A \code{SnowflakeDriver} object for use with [DBI::dbConnect()].
#' @export
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(dbc::snowflake(),
#'   account   = "myorg-myaccount",
#'   warehouse = "COMPUTE_WH",
#'   database  = "MY_DB"
#' )
#' DBI::dbDisconnect(con)
#' }
snowflake <- function() {
  new("SnowflakeDriver", driver = load_driver("snowflake"))
}

#' @param drv A \code{SnowflakeDriver} object from [snowflake()].
#' @param account Snowflake account identifier (e.g. \code{"myorg-myaccount"}).
#'   Defaults to \code{SNOWFLAKE_ACCOUNT} environment variable.
#' @param warehouse Virtual warehouse name.
#' @param database Database name.
#' @param schema Schema name.
#' @param uid User name.
#' @param pwd Password.
#' @param token OAuth or JWT token string. When supplied, \code{authenticator}
#'   is automatically set to \code{"oauth"}.
#' @param authenticator Authentication method: \code{"snowflake"} (default
#'   username/password), \code{"oauth"}, or \code{"externalbrowser"}.
#' @param role Snowflake role to use after connecting.
#' @param ... Additional options passed directly to the ADBC driver.
#' @rdname snowflake
#' @export
setMethod("dbConnect", "SnowflakeDriver", function(drv,
  account       = NULL,
  warehouse     = NULL,
  database      = NULL,
  schema        = NULL,
  uid           = NULL,
  pwd           = NULL,
  token         = NULL,
  authenticator = NULL,
  role          = NULL,
  ...
) {
  account <- account %||% or_null(Sys.getenv("SNOWFLAKE_ACCOUNT"))

  # Ambient credential detection (fills token/authenticator when not supplied)
  creds <- snowflake_credentials(uid = uid, pwd = pwd, token = token,
                                  authenticator = authenticator,
                                  account = account)
  token         <- creds$token
  authenticator <- creds$authenticator

  # If a token is available and authenticator is still unset, use oauth
  if (!is.null(token) && is.null(authenticator)) {
    authenticator <- "oauth"
  }

  opts <- adbc_opts(
    "adbc.snowflake.sql.account"                  = account,
    "adbc.snowflake.sql.db"                       = database,
    "adbc.snowflake.sql.warehouse"                = warehouse,
    "adbc.snowflake.sql.schema"                   = schema,
    "username"                                    = uid,
    "password"                                    = pwd,
    "adbc.snowflake.sql.client_option.token"      = token,
    "adbc.snowflake.sql.auth_type"                = authenticator,
    "adbc.snowflake.sql.role"                     = role
  )
  promote_connection("SnowflakeConnection", adbi_connect(drv, opts, list(...)))
})

# Internal: detect ambient Snowflake credentials when uid/pwd/token not given.
# Returns a list with token and authenticator (either may be NULL).
snowflake_credentials <- function(uid, pwd, token, authenticator, account) {
  # Nothing to do when explicit credentials are provided
  if (!is.null(uid) || !is.null(pwd) || !is.null(token)) {
    return(list(token = token, authenticator = authenticator))
  }

  # 1. Posit Connect viewer token
  if (requireNamespace("connectcreds", quietly = TRUE) &&
      connectcreds::has_viewer_token()) {
    account_url <- if (!is.null(account)) {
      paste0("https://", account, ".snowflakecomputing.com")
    } else {
      NULL
    }
    viewer_token <- tryCatch(
      connectcreds::connect_viewer_token(audience = account_url),
      error = function(e) NULL
    )
    if (!is.null(viewer_token)) {
      return(list(token = viewer_token, authenticator = "oauth"))
    }
  }

  # 2. Snowpark Container Services token file
  token_file <- "/snowflake/session/token"
  if (file.exists(token_file)) {
    tok <- tryCatch(trimws(readLines(token_file, warn = FALSE)[[1L]]),
                    error = function(e) NULL)
    if (!is.null(tok) && nzchar(tok)) {
      return(list(token = tok, authenticator = "oauth"))
    }
  }

  # 3. SNOWFLAKE_TOKEN environment variable
  env_token <- Sys.getenv("SNOWFLAKE_TOKEN")
  if (nzchar(env_token)) {
    return(list(token = env_token, authenticator = "oauth"))
  }

  list(token = NULL, authenticator = authenticator)
}
