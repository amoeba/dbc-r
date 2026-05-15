## Tests for ambient credential detection helpers.
## All network/file-system side effects are avoided via mocked env vars,
## withr::with_envvar(), and mockery::stub().

# snowflake_credentials -------------------------------------------------------

test_that("snowflake_credentials: explicit uid/pwd returns immediately", {
  res <- dbc:::snowflake_credentials(uid = "u", pwd = "p", token = NULL,
                                     authenticator = NULL, account = NULL)
  expect_null(res$token)
  expect_null(res$authenticator)
})

test_that("snowflake_credentials: explicit token returned unchanged", {
  res <- dbc:::snowflake_credentials(uid = NULL, pwd = NULL, token = "mytoken",
                                     authenticator = "oauth", account = NULL)
  expect_equal(res$token, "mytoken")
  expect_equal(res$authenticator, "oauth")
})

test_that("snowflake_credentials: SNOWFLAKE_TOKEN env var", {
  withr::with_envvar(list(SNOWFLAKE_TOKEN = "envtoken"), {
    # Ensure connectcreds is treated as absent
    mockery::stub(dbc:::snowflake_credentials, "requireNamespace", FALSE)
    res <- dbc:::snowflake_credentials(uid = NULL, pwd = NULL, token = NULL,
                                       authenticator = NULL, account = "acct")
    expect_equal(res$token, "envtoken")
    expect_equal(res$authenticator, "auth_oauth")
  })
})

test_that("snowflake_credentials: no credentials returns NULLs", {
  withr::with_envvar(list(SNOWFLAKE_TOKEN = ""), {
    mockery::stub(dbc:::snowflake_credentials, "requireNamespace", FALSE)
    # Ensure token file doesn't exist on this machine
    mockery::stub(dbc:::snowflake_credentials, "file.exists", FALSE)
    res <- dbc:::snowflake_credentials(uid = NULL, pwd = NULL, token = NULL,
                                       authenticator = NULL, account = NULL)
    expect_null(res$token)
    expect_null(res$authenticator)
  })
})

# databricks_credentials ------------------------------------------------------

test_that("databricks_credentials: DATABRICKS_TOKEN env var", {
  skip_if_not_installed("mockery")
  withr::with_envvar(list(
    DATABRICKS_TOKEN         = "my-pat",
    DATABRICKS_CLIENT_ID     = "",
    DATABRICKS_CLIENT_SECRET = ""
  ), {
    mockery::stub(dbc:::databricks_credentials, "requireNamespace", FALSE)
    res <- dbc:::databricks_credentials("https://ws.azuredatabricks.net")
    expect_equal(res, "my-pat")
  })
})

test_that("databricks_credentials: no credentials returns NULL", {
  skip_if_not_installed("mockery")
  withr::with_envvar(list(
    DATABRICKS_TOKEN         = "",
    DATABRICKS_CLIENT_ID     = "",
    DATABRICKS_CLIENT_SECRET = "",
    RSTUDIO_PROGRAM_MODE     = "server"   # suppress CLI path
  ), {
    mockery::stub(dbc:::databricks_credentials, "requireNamespace", FALSE)
    res <- dbc:::databricks_credentials(NULL)
    expect_null(res)
  })
})

# redshift_credentials --------------------------------------------------------

test_that("redshift_credentials: explicit uid/pwd returned as-is", {
  res <- dbc:::redshift_credentials(iam = FALSE, uid = "u", pwd = "p",
                                    database = "db", cluster_id = NULL,
                                    region = NULL)
  expect_equal(res$uid, "u")
  expect_equal(res$pwd, "p")
})

test_that("redshift_credentials: no paws.common returns uid/pwd unchanged", {
  skip_if_not_installed("mockery")
  mockery::stub(dbc:::redshift_credentials, "requireNamespace", FALSE)
  res <- dbc:::redshift_credentials(iam = FALSE, uid = NULL, pwd = NULL,
                                    database = "db", cluster_id = "cl",
                                    region = "us-east-1")
  expect_null(res$uid)
  expect_null(res$pwd)
})

test_that("redshift_credentials: iam=TRUE without cluster_id errors", {
  skip_if_not_installed("mockery")
  # Simulate paws.common present but returning valid AWS creds
  mockery::stub(dbc:::redshift_credentials, "requireNamespace",
    function(pkg, ...) pkg == "paws.common")
  mockery::stub(dbc:::redshift_credentials, "paws.common::locate_credentials",
    list(access_key_id = "AKID", secret_access_key = "SAK", session_token = ""))
  expect_error(
    dbc:::redshift_credentials(iam = TRUE, uid = NULL, pwd = NULL,
                               database = "db", cluster_id = NULL,
                               region = "us-east-1"),
    "cluster_id"
  )
})

test_that("redshift_credentials: iam=FALSE with no AWS creds returns NULLs", {
  skip_if_not_installed("mockery")
  mockery::stub(dbc:::redshift_credentials, "requireNamespace",
    function(pkg, ...) pkg == "paws.common")
  mockery::stub(dbc:::redshift_credentials, "paws.common::locate_credentials",
    list(access_key_id = "", secret_access_key = ""))
  res <- dbc:::redshift_credentials(iam = FALSE, uid = NULL, pwd = NULL,
                                    database = "db", cluster_id = "cl",
                                    region = "us-east-1")
  expect_null(res$uid)
  expect_null(res$pwd)
})
