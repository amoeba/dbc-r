# dbc


## Installation

```r
# install.packages("remotes")
remotes::install_github("amoeba/dbc-r")
```

## Usage

```r
library(dbc)
library(DBI)
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
