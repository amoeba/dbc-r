library(DBI)

skip_if_not_installed("adbi")
skip_if_not_installed("adbcdrivermanager")

test_that("sqlite driver supports basic queries", {
  con <- dbConnect(dbc::driver("sqlite"), uri = ":memory:")
  on.exit(dbDisconnect(con))

  dbWriteTable(con, "swiss", datasets::swiss)

  result <- dbGetQuery(con, "SELECT * FROM swiss WHERE Agriculture < 40")
  expect_s3_class(result, "data.frame")
  expect_true(all(result$Agriculture < 40))
  expect_true(nrow(result) > 0)
})
