# dbc

An R package that provides a single entry point for using any [ADBC](https://arrow.apache.org/adbc/) database driver from R. Drivers are installed on-demand from the [dbc](https://github.com/adbc-drivers/dbc) registry and exposed as standard DBI driver objects.

## Installation

```r
# install.packages("remotes")
remotes::install_github("adbc-drivers/dbc-r")
```

## Usage

### Connect to a database

```r
library(DBI)

# SQLite
con <- dbConnect(dbc::driver("sqlite"), uri = ":memory:")

# PostgreSQL
con <- dbConnect(dbc::driver("postgresql"),
  uri = "postgresql://user:pass@localhost:5432/mydb"
)

# Snowflake
con <- dbConnect(dbc::driver("snowflake"),
  "adbc.snowflake.sql.account" = "myorg-myaccount",
  "adbc.snowflake.sql.warehouse" = "COMPUTE_WH"
)

# DuckDB
con <- dbConnect(dbc::driver("duckdb"), uri = ":memory:")
```

Drivers are auto-installed on first use. To disable:

```r
options(dbc.autoinstall = FALSE)
```

### Query

```r
con <- dbConnect(dbc::driver("sqlite"), uri = ":memory:")

dbWriteTable(con, "swiss", datasets::swiss)
dbGetQuery(con, "SELECT * FROM swiss WHERE Agriculture < 40")

dbDisconnect(con)
```

### Use with dbplyr

```r
library(dplyr)

con <- dbConnect(dbc::driver("sqlite"), uri = ":memory:")
dbWriteTable(con, "swiss", datasets::swiss)

tbl(con, "swiss") |>
  filter(Agriculture < 40) |>
  select(Agriculture, Education, Fertility) |>
  arrange(desc(Fertility)) |>
  collect()

dbDisconnect(con)
```

### Search and manage drivers

```r
# Find available drivers
dbc::dbc_search("")
#> [1] "bigquery"    "clickhouse"  "databricks"  "duckdb"      "flightsql"
#> [6] "mssql"       "mysql"       "oracle"      "postgresql"  "redshift"
#> ...

# Manually install/uninstall
dbc::dbc_install("snowflake")
dbc::dbc_uninstall("snowflake")

# List installed drivers
dbc::dbc_list_drivers()
```

### IDE support

Connections are automatically registered with the RStudio or Positron Connections pane when available — providing an object browser, disconnect button, and table previews.
