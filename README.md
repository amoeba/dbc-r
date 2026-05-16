# dbc

R bindings to the [dbc](https://columnar.tech/dbc) CLI.
Installs and makes [ADBC](https://arrow.apache.org/adbc) drivers available via [DBI](https://github.com/r-dbi/dbi)/[adbi](https://github.com/r-dbi/adbi) to packages like [dbplyr](https://dbplyr.tidyverse.org).

## Installation

```r
# install.packages("remotes")
remotes::install_github("amoeba/dbc-r")
```

## Usage

```r
library(dbc)
library(dplyr)

# Install the duckdb ADBC driver
dbc::dbc_install("duckdb")

# Pass it to dbConnect
con <- dbConnect(dbc::driver("duckdb"), uri = ":memory:")

dbWriteTable(con, "swiss", datasets::swiss)

tbl(con, "swiss") |>
  filter(Agriculture < 40) |>
  select(Agriculture, Education, Fertility) |>
  arrange(desc(Fertility)) |>
  collect()

dbDisconnect(con)
```

### Connect to any database

```r
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
con <- dbConnect(dbc::driver("duckdb"), uri = "my_data.duckdb")
```

### Search and manage drivers

dbc is normally a CLI and this R packages bindgs dbc's CLI subcommands to R so you can control dbc with R code:

```r
# Find available drivers
dbc::dbc_search()
#> [1] "bigquery"    "clickhouse"  "databricks"  "duckdb"      "flightsql"
#> [6] "mssql"       "mysql"       "oracle"      "postgresql"  "redshift"
#> ...

# Install/uninstall drivers
dbc::dbc_install("snowflake")
dbc::dbc_uninstall("snowflake")

# List installed drivers
dbc::dbc_list()

# See ?dbc for more info
```

### IDE support

Connections are automatically registered with the RStudio or Positron Connections pane — providing an object browser, disconnect button, and table previews.
