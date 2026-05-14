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

### Search available drivers

```r
dbc::dbc_search()
#> [1] "sqlite"     "snowflake"  "postgresql" ...
```
