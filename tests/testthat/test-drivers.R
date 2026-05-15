library(DBI)

skip_if_not_installed("adbi")
skip_if_not_installed("adbcdrivermanager")

# --- S4 class hierarchy ---

# Helper: try constructing a driver; return the driver or NULL if not installed.
try_driver <- function(fn) {
  withCallingHandlers(
    tryCatch(fn(), error = function(e) NULL),
    message = function(m) invokeRestart("muffleMessage")
  )
}

test_that("driver constructors return the correct S4 driver class", {
  cases <- list(
    list(dbc::sqlite,      "SqliteDriver"),
    list(dbc::duckdb,      "DuckdbDriver"),
    list(dbc::snowflake,   "SnowflakeDriver"),
    list(dbc::databricks,  "DatabricksDriver"),
    list(dbc::bigquery,    "BigqueryDriver"),
    list(dbc::postgresql,  "PostgresqlDriver"),
    list(dbc::redshift,    "RedshiftDriver"),
    list(dbc::mysql,       "MysqlDriver"),
    list(dbc::mssql,       "MssqlDriver"),
    list(dbc::clickhouse,  "ClickhouseDriver"),
    list(dbc::trino,       "TrinoDriver"),
    list(dbc::flightsql,   "FlightsqlDriver"),
    list(dbc::oracle,      "OracleDriver"),
    list(dbc::sap_hana,    "SapHanaDriver"),
    list(dbc::singlestore, "SinglestoreDriver"),
    list(dbc::teradata,    "TeradataDriver"),
    list(dbc::exasol,      "ExasolDriver")
  )
  for (case in cases) {
    drv <- try_driver(case[[1]])
    if (is.null(drv)) {
      skip(paste(case[[2]], "driver not available"))
    }
    expect_s4_class(drv, case[[2]])
    expect_true(is(drv, "AdbiDriver"),
                label = paste(case[[2]], "extends AdbiDriver"))
  }
})

# --- dbConnect returns per-driver connection class ---

test_that("dbConnect(sqlite()) returns SqliteConnection", {
  con <- dbConnect(dbc::sqlite(), uri = ":memory:")
  on.exit(dbDisconnect(con))
  expect_s4_class(con, "SqliteConnection")
  expect_true(is(con, "AdbiConnection"))
})

test_that("dbConnect(duckdb()) returns DuckdbConnection", {
  skip_if_not(dbc:::load_driver("duckdb") |> inherits("adbc_driver") ||
                tryCatch({ dbc:::load_driver("duckdb"); TRUE }, error = function(e) FALSE),
              "duckdb driver not installed")
  con <- dbConnect(dbc::duckdb(), uri = ":memory:")
  on.exit(dbDisconnect(con))
  expect_s4_class(con, "DuckdbConnection")
  expect_true(is(con, "AdbiConnection"))
})

# --- build_uri helper ---

test_that("build_uri constructs URIs correctly", {
  expect_equal(
    dbc:::build_uri("postgresql", "localhost", 5432, "mydb", "user", "pass"),
    "postgresql://user:pass@localhost:5432/mydb"
  )
  expect_equal(
    dbc:::build_uri("postgresql", "localhost", 5432, "mydb", "user", NULL),
    "postgresql://user@localhost:5432/mydb"
  )
  expect_equal(
    dbc:::build_uri("postgresql", "localhost", 5432, "mydb", NULL, NULL),
    "postgresql://localhost:5432/mydb"
  )
  expect_equal(
    dbc:::build_uri("postgresql", "localhost", 5432, NULL, NULL, NULL),
    "postgresql://localhost:5432"
  )
  expect_null(dbc:::build_uri("postgresql", NULL, 5432))
})

# --- sqlite dbConnect parameter mapping ---

test_that("sqlite() dbConnect passes uri to ADBC", {
  con <- dbConnect(dbc::sqlite(), uri = ":memory:")
  on.exit(dbDisconnect(con))
  expect_true(dbIsValid(con))
  # Verify it's usable
  dbExecute(con, "CREATE TABLE t (x INTEGER)")
  dbExecute(con, "INSERT INTO t VALUES (42)")
  expect_equal(dbGetQuery(con, "SELECT x FROM t")$x, 42L)
})

test_that("sqlite() dbConnect defaults uri to :memory:", {
  con <- dbConnect(dbc::sqlite())
  on.exit(dbDisconnect(con))
  expect_true(dbIsValid(con))
})
