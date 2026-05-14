library(DBI)

skip_if_not_installed("adbi")
skip_if_not_installed("adbcdrivermanager")

test_that("sqlite() returns a DBI driver and supports basic queries", {
  con <- dbConnect(dbc::sqlite(), uri = ":memory:")
  on.exit(dbDisconnect(con))

  dbWriteTable(con, "swiss", datasets::swiss)

  result <- dbGetQuery(con, "SELECT * FROM swiss WHERE Agriculture < 40")
  expect_s3_class(result, "data.frame")
  expect_true(all(result$Agriculture < 40))
  expect_true(nrow(result) > 0)
})

test_that("sqlite() supports prepared statements with dbBind", {
  con <- dbConnect(dbc::sqlite(), uri = ":memory:")
  on.exit(dbDisconnect(con))

  dbWriteTable(con, "swiss", datasets::swiss)

  res <- dbSendQuery(con, "SELECT * FROM swiss WHERE Agriculture < ?")
  on.exit(dbClearResult(res), add = TRUE)

  dbBind(res, list(30))
  rows_30 <- dbFetch(res)
  expect_true(all(rows_30$Agriculture < 30))

  dbBind(res, list(20))
  rows_20 <- dbFetch(res)
  expect_true(all(rows_20$Agriculture < 20))

  expect_true(nrow(rows_30) >= nrow(rows_20))
})
