library(DBI)

skip_if_not_installed("adbi")
skip_if_not_installed("adbcdrivermanager")

# Helper: try constructing a driver; return the driver or NULL if not installed.
try_driver <- function(name) {
  withCallingHandlers(
    tryCatch(dbc::driver(name), error = function(e) NULL),
    message = function(m) invokeRestart("muffleMessage")
  )
}

test_that("driver() returns a DbcDriver with the correct name slot", {
  drv <- try_driver("sqlite")
  if (is.null(drv)) skip("sqlite driver not available")
  expect_s4_class(drv, "DbcDriver")
  expect_true(is(drv, "AdbiDriver"))
  expect_equal(drv@name, "sqlite")
})

test_that("driver() works for multiple driver names", {
  names <- c("sqlite", "duckdb", "postgresql", "snowflake")
  for (nm in names) {
    drv <- try_driver(nm)
    if (is.null(drv)) next
    expect_s4_class(drv, "DbcDriver")
    expect_equal(drv@name, nm)
  }
})

test_that("dbConnect(driver('sqlite')) works", {
  drv <- try_driver("sqlite")
  if (is.null(drv)) skip("sqlite driver not available")
  con <- dbConnect(drv, uri = ":memory:")
  on.exit(dbDisconnect(con))
  expect_true(is(con, "AdbiConnection"))
  expect_true(dbIsValid(con))
})

test_that("dbConnect(driver('duckdb')) works", {
  drv <- try_driver("duckdb")
  if (is.null(drv)) skip("duckdb driver not available")
  con <- dbConnect(drv, uri = ":memory:")
  on.exit(dbDisconnect(con))
  expect_true(is(con, "AdbiConnection"))
})
