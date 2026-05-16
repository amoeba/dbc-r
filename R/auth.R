#' Manage driver registry credentials
#'
#' @name dbc_auth
#' @description
#' Functions for authenticating with private driver registries.
NULL

#' Log in to a driver registry
#'
#' Authenticates with a driver registry using an API key.
#' Equivalent to running \code{dbc auth login --api-key <key>} on the
#' command line.
#'
#' @param api_key Character string. The API key to authenticate with.
#'   Required for non-interactive login from R.
#' @param registry_url Character string. URL of the driver registry to
#'   authenticate with. Defaults to the Columnar private registry.
#' @param client_id Character string. OAuth Client ID. Only needed for
#'   custom registries.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   on failure.
#' @export
dbc_auth_login <- function(api_key, registry_url = NULL, client_id = NULL) {
  stopifnot(is.character(api_key), length(api_key) == 1L, nzchar(api_key))
  if (!is.null(registry_url)) {
    stopifnot(is.character(registry_url), length(registry_url) == 1L)
  }
  if (!is.null(client_id)) {
    stopifnot(is.character(client_id), length(client_id) == 1L)
  }
  invisible(.Call(C_dbc_auth_login, registry_url, api_key, client_id))
}

#' Log out from a driver registry
#'
#' Removes credentials for a driver registry. Equivalent to running
#' \code{dbc auth logout} on the command line.
#'
#' @param registry_url Character string. URL of the driver registry to
#'   log out from. Defaults to the Columnar private registry.
#' @param purge Logical. If \code{TRUE}, remove all local auth credentials
#'   for dbc. Default \code{FALSE}.
#' @return Invisibly returns \code{NULL} on success; stops with an error
#'   on failure.
#' @export
dbc_auth_logout <- function(registry_url = NULL, purge = FALSE) {
  if (!is.null(registry_url)) {
    stopifnot(is.character(registry_url), length(registry_url) == 1L)
  }
  stopifnot(is.logical(purge), length(purge) == 1L)
  invisible(.Call(C_dbc_auth_logout, registry_url, purge))
}
