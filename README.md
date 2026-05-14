# dbc

An R package that wraps the [dbc](https://github.com/columnar-tech/dbc) Go client to install ADBC drivers and return DBI-compatible driver objects.

## Installation

```r
# install.packages("remotes")
remotes::install_github("columnar-tech/dbc-r")
```

## Usage

### Install a driver

```r
dbc::dbc_install("sqlite")
dbc::dbc_install("snowflake")
```

Driver functions like `dbc::sqlite()` auto-install on first use by default. To disable:

```r
options(dbc.autoinstall = FALSE)
```

### Connect with DBI

```r
library(DBI)

con <- dbConnect(dbc::sqlite(), uri = ":memory:")

# Write a table
dbWriteTable(con, "swiss", datasets::swiss)

# Query it
dbGetQuery(con, "SELECT * FROM swiss WHERE Agriculture < 40")

# Prepared statements
res <- dbSendQuery(con, "SELECT * FROM swiss WHERE Agriculture < ?")

dbBind(res, list(30))
dbFetch(res)

dbBind(res, list(20))
dbFetch(res)

# Cleanup
dbClearResult(res)
dbDisconnect(con)
```

### Use with dbplyr

```r
library(DBI)
library(dplyr)

con <- dbConnect(dbc::sqlite(), uri = ":memory:")

dbWriteTable(con, "swiss", datasets::swiss)

swiss_tbl <- tbl(con, "swiss")

# Queries are translated to SQL and executed lazily
swiss_tbl |>
  filter(Agriculture < 40) |>
  select(Agriculture, Education, Fertility) |>
  arrange(desc(Fertility))

# Collect results into a local data frame
swiss_tbl |>
  group_by(Catholic > 50) |>
  summarise(mean_fertility = mean(Fertility, na.rm = TRUE)) |>
  collect()

dbDisconnect(con)
```

### Search available drivers

```r
dbc::dbc_search()
#> [1] "bigquery"    "clickhouse"  "databricks"  "duckdb"      "exasol"
#> [6] "flightsql"   "mssql"       "mysql"       "postgresql"  "redshift"
#> ...
```
