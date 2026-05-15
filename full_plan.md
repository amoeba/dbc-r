# dbc-r: Full Implementation Plan — odbc-like Driver Features

_Written 2026-05-14. Assumes the package is in its current state: 17 flat driver functions
generated in `R/drivers-generated.R`, one hand-written `R/sqlite.R`, and an internal
`load_driver()` helper. The goal is to match the best features of odbc while keeping
the ADBC/adbi wire underneath._

---

## Background: What odbc does that we don't

Studying `r-dbi/odbc` reveals six independent feature areas:

| # | Feature | What odbc does | Status |
|---|---------|---------------|--------|
| 1 | Per-driver S4 **driver classes** | `SnowflakeOdbcDriver extends OdbcDriver`, own `dbConnect()` method | done |
| 2 | Named, documented **dbConnect parameters** | `snowflake(account=, warehouse=, ...)` maps to ADBC option strings | done |
| 3 | **Ambient credential detection** | Reads env vars, token files, Posit Connect, CLI tools — per driver | done |
| 4 | Per-driver S4 **connection classes** | `Snowflake extends OdbcConnection` — extra methods dispatch here | done |
| 5 | **Input validation** | Clear R-level errors for missing required params before any ADBC call | not done |
| 6 | **keyring support** | `pwd` resolved from system keychain via `keyring` package | not done |
| 7 | **RStudio Connections pane** | `connectionObserver` events so connections appear in IDE | not done |
| ~~8~~ | ~~Data type overrides~~ | ~~out of scope~~ | — |

Our analogue: swap `OdbcDriver` → `AdbiDriver`, `OdbcConnection` → `AdbiConnection`.

---

## Architecture decisions

### S4 subclassing in adbi

adbi exposes two classes we can subclass:

```r
setClass("SnowflakeDriver",    contains = "AdbiDriver")
setClass("SnowflakeConnection", contains = "AdbiConnection")
```

adbi's `dbConnect(AdbiDriver, ...)` calls `AdbiConnection(drv, ...)`, which forwards
`...` straight to `adbcdrivermanager::adbc_database_init(drv@driver, ...)`.
This means our overriding `dbConnect(SnowflakeDriver, ...)` can translate friendly
R parameter names into the right ADBC option strings before calling `callNextMethod()`.

### ADBC option string reference

| Driver     | Key R params            | ADBC option strings                                         |
|------------|-------------------------|-------------------------------------------------------------|
| sqlite     | `uri`                   | `uri`                                                       |
| postgresql | `uri` or individual parts | `uri` (postgres libpq connection string)                  |
| snowflake  | `account`, `warehouse`, `database`, `schema`, `uid`, `pwd` | `adbc.snowflake.sql.account`, `adbc.snowflake.sql.db`, `adbc.snowflake.sql.warehouse`, `adbc.snowflake.sql.schema`, `username`, `password` |
| databricks | `workspace`, `http_path`, `token` | `adbc.spark.host`, `adbc.spark.http_path`, `adbc.spark.token` or `adbc.databricks.*` |
| bigquery   | `project_id`            | `adbc.bigquery.project_id`, `adbc.bigquery.auth_type`       |
| flightsql  | `host`, `token`         | `adbc.flight.sql.authorization_header`, `uri`               |
| mssql      | `server`, `database`, `uid`, `pwd` | `uri` (ADO connection string or DSN)               |
| mysql      | `host`, `database`, `uid`, `pwd` | `uri` (MySQL URI)                                      |

_These will need confirmation against the actual ADBC driver packages; see Phase 0._

### File layout (target state)

```
R/
  driver.R                 # load_driver() internal helper (unchanged)
  install.R                # dbc_install() (unchanged)
  search.R                 # dbc_search() (unchanged)
  uninstall.R              # dbc_uninstall() (unchanged)
  list_drivers.R           # dbc_list() (unchanged)
  info.R                   # dbc_info() (unchanged)
  update_drivers.R         # dev/CI tool (update to generate new skeleton)

  sqlite.R               # hand-written, richest example
  snowflake.R            # hand-written (high-value, complex auth)
  databricks.R           # hand-written (complex auth)
  bigquery.R             # hand-written (OAuth)
  postgresql.R           # hand-written (moderately complex)
  redshift.R             # hand-written (AWS IAM)
  mssql.R                # hand-written
  mysql.R                # hand-written
  trino.R                # hand-written
  duckdb.R               # hand-written
  flightsql.R            # hand-written
  clickhouse.R           # hand-written
  oracle.R               # hand-written
  sap_hana.R             # hand-written
  singlestore.R          # hand-written
  teradata.R             # hand-written
  exasol.R               # hand-written
  drivers-generated.R    # fallback for any driver not hand-written
```

---

## Feature 1: Per-driver S4 driver classes

**What to build:** One `setClass()` per hand-written driver, extending `AdbiDriver`.

```r
# R/snowflake.R

#' @export
setClass("SnowflakeDriver", contains = "AdbiDriver")

#' DBI-compatible driver for Snowflake via ADBC
#' @export
snowflake <- function() {
  new("SnowflakeDriver", driver = load_driver("snowflake"))
}
```

**Why:** Enables S4 method dispatch so `dbConnect(dbc::snowflake(), ...)` can call
our Snowflake-specific method rather than adbi's generic one.

**Files changed:** One new `R/<name>.R` per driver.

**NAMESPACE changes:** Export each driver function; add `exportClasses()` or rely on
`@exportClass` roxygen tag.

---

## Feature 2: Named, documented dbConnect() parameters

**What to build:** A `setMethod("dbConnect", "<Driver>", ...)` for each hand-written
driver, with named parameters that map to ADBC option strings.

### Pattern

```r
setMethod("dbConnect", "SnowflakeDriver", function(drv,
  account   = Sys.getenv("SNOWFLAKE_ACCOUNT"),
  warehouse = NULL,
  database  = NULL,
  schema    = NULL,
  uid       = NULL,
  pwd       = NULL,
  ...,
  bigint    = "integer64"
) {
  opts <- list(
    "adbc.snowflake.sql.account"   = account,
    "adbc.snowflake.sql.db"        = database,
    "adbc.snowflake.sql.warehouse" = warehouse,
    "adbc.snowflake.sql.schema"    = schema,
    "username"                     = uid,
    "password"                     = pwd
  )
  opts <- Filter(Negate(is.null), opts)

  # ambient credential injection (see Feature 3)
  opts <- snowflake_credentials(opts, ...)

  do.call(callNextMethod, c(list(drv), opts, list(...), list(bigint = bigint)))
})
```

### Per-driver parameter lists

#### sqlite
```r
dbConnect(SqliteDriver, uri = ":memory:", ...)
```
- `uri` → `uri` (file path or `:memory:`)

#### postgresql
```r
dbConnect(PostgresqlDriver,
  host = NULL, port = 5432L, database = NULL,
  uid = NULL, pwd = NULL, uri = NULL, ...)
```
- If `uri` provided, pass as-is; else build `postgresql://uid:pwd@host:port/database`
- `uri` → `uri`

#### snowflake
```r
dbConnect(SnowflakeDriver,
  account   = Sys.getenv("SNOWFLAKE_ACCOUNT"),
  warehouse = NULL, database = NULL, schema = NULL,
  uid = NULL, pwd = NULL,
  authenticator = NULL,   # "snowflake" | "externalbrowser" | "oauth"
  token = NULL,           # OAuth/JWT token string
  role = NULL,
  ...)
```
- `account` → `adbc.snowflake.sql.account`
- `database` → `adbc.snowflake.sql.db`
- `warehouse` → `adbc.snowflake.sql.warehouse`
- `schema` → `adbc.snowflake.sql.schema`
- `uid` → `username`
- `pwd` → `password`
- `token` → `adbc.snowflake.sql.client_option.token`
- `authenticator` → `adbc.snowflake.sql.auth_type`
- `role` → `adbc.snowflake.sql.role`

#### databricks
```r
dbConnect(DatabricksDriver,
  workspace  = Sys.getenv("DATABRICKS_HOST"),
  http_path  = Sys.getenv("DATABRICKS_HTTP_PATH"),
  token      = NULL,
  catalog    = NULL,
  schema     = NULL,
  ...)
```
- `workspace` → `adbc.spark.host`
- `http_path` → `adbc.spark.http_path`
- `token` → `adbc.spark.token`
- `catalog` → `adbc.spark.catalog`
- `schema` → `adbc.spark.schema`

#### bigquery
```r
dbConnect(BigqueryDriver,
  project_id = Sys.getenv("BIGQUERY_PROJECT"),
  dataset    = NULL,
  auth_type  = NULL,     # "service_account" | "workload_identity" | "user" | ...
  ...)
```
- `project_id` → `adbc.bigquery.project_id`
- `auth_type` → `adbc.bigquery.auth_type`

#### redshift
```r
dbConnect(RedshiftDriver,
  host = NULL, port = 5439L, database = NULL,
  uid = NULL, pwd = NULL,
  iam = FALSE,
  ...)
```
- IAM path: detect AWS credentials, build IAM connection

#### mssql
```r
dbConnect(MssqlDriver,
  server = NULL, database = NULL,
  uid = NULL, pwd = NULL,
  port = 1433L, encrypt = TRUE,
  ...)
```

#### mysql
```r
dbConnect(MysqlDriver,
  host = "localhost", port = 3306L, database = NULL,
  uid = NULL, pwd = NULL,
  ...)
```

#### trino
```r
dbConnect(TrinoDriver,
  host = NULL, port = 8080L,
  catalog = NULL, schema = NULL,
  uid = NULL, pwd = NULL,
  ...)
```

#### duckdb
```r
dbConnect(DuckdbDriver,
  uri = ":memory:",   # or file path
  read_only = FALSE,
  ...)
```

#### flightsql
```r
dbConnect(FlightsqlDriver,
  uri   = NULL,
  token = NULL,   # Bearer token → "adbc.flight.sql.authorization_header" = "Bearer <token>"
  ...)
```

---

## Feature 3: Ambient credential detection

**Status: implemented for Snowflake, Databricks, Redshift, BigQuery, PostgreSQL.**

A private `<driver>_credentials()` function called inside each `dbConnect()` method
fills in auth params only when the user has not explicitly provided them.

### Detection order (highest priority first)

#### Snowflake (`snowflake_credentials()`) — **done**
1. If `uid`, `pwd`, or `token` provided → return as-is, no detection
2. **Posit Connect viewer token** — `connectcreds::has_viewer_token()` →
   `connectcreds::connect_viewer_token(audience = "https://<account>.snowflakecomputing.com")`
   → set `token`, `authenticator = "auth_oauth"`
3. **Snowpark Container Services token file** — `/snowflake/session/token` exists →
   read file → set `token`, `authenticator = "auth_oauth"`
4. **`SNOWFLAKE_TOKEN` env var** → set `token`, `authenticator = "auth_oauth"`
5. **`SNOWFLAKE_ACCOUNT` env var** → fills in `account` if not supplied (in `dbConnect`, not in helper)
6. **Snowflake CLI** — **not yet implemented**; would call
   `snowflakeauth::get_token(account)` if package is available

Note: authenticator value is `"auth_oauth"` (not `"oauth"`).

#### Databricks (`databricks_credentials()`) — **done**
1. If `token` provided → return as-is
2. **Posit Connect viewer OAuth** — `connectcreds::has_viewer_token()` →
   `connectcreds::connect_viewer_token(audience = workspace)`
3. **Posit Connect service-principal OAuth** — `connectcreds::has_service_account_token()` →
   `connectcreds::connect_service_account_token(audience = workspace)`
4. **`DATABRICKS_TOKEN` env var** → personal access token
5. **OAuth M2M** — `DATABRICKS_CLIENT_ID` + `DATABRICKS_CLIENT_SECRET` env vars →
   POST to `https://<workspace>/oidc/v1/token` via `httr2` (optional dep); returns
   bearer token
6. **Databricks CLI** — `system2("databricks", c("auth", "token", "--host", workspace))`
   — only in desktop sessions (`RSTUDIO_PROGRAM_MODE` unset or `"desktop"`)
- `workspace` defaults to `DATABRICKS_HOST`, `http_path` to `DATABRICKS_HTTP_PATH`

#### BigQuery — **done** (no separate helper; handled in `dbConnect`)
- `project_id` defaults to `BIGQUERY_PROJECT`, then `GCLOUD_PROJECT`, then
  `GOOGLE_CLOUD_PROJECT` env vars
- Auth delegated entirely to ADBC BigQuery driver's Application Default Credentials
  chain (gcloud, `GOOGLE_APPLICATION_CREDENTIALS`, GCE metadata server)

#### Redshift (`redshift_credentials()`) — **done**
1. If `uid` + `pwd` provided → return as-is
2. If `paws.common` not available → return as-is
3. `paws.common::locate_credentials()` → if no AWS creds found → return as-is
4. If `paws.database` not available:
   - if `iam = TRUE` → `warning()` and fall back to uid/pwd
   - if `iam = FALSE` → silently fall back
5. If `cluster_id` not supplied:
   - if `iam = TRUE` → `stop()` (required)
   - if `iam = FALSE` → silently fall back
6. `paws.database::redshift()$get_cluster_credentials(DbUser, DbName, ClusterIdentifier)`
   → returns temporary `DbUser` + `DbPassword`

#### PostgreSQL — **done** (handled in `dbConnect`, no helper)
- `host` defaults to `PGHOST`, then `"localhost"`
- `database` defaults to `PGDATABASE`
- `uid` defaults to `PGUSER`
- `pwd` defaults to `PGPASSWORD`

#### All other drivers (MySQL, MSSQL, Trino, DuckDB, etc.)
No ambient detection. Users supply credentials explicitly or via `uri`.

### Posit Connect integration

`connectcreds` is an optional dependency (`requireNamespace("connectcreds", quietly = TRUE)`).
All detection steps that use it are no-ops when the package is absent.

---

## Feature 4: Per-driver connection classes

**Status: implemented for all 17 drivers.**

Each driver file declares a connection subclass and the `dbConnect()` method calls
`promote_connection()` (internal helper in `driver.R`) to copy all slots from the
`AdbiConnection` returned by adbi into the per-driver subclass:

```r
# driver.R
promote_connection <- function(class, con) {
  new(class,
      database               = con@database,
      connection             = con@connection,
      metadata               = con@metadata,
      bigint                 = con@bigint,
      rows_affected_callback = con@rows_affected_callback)
}
```

For drivers that build their own opts list, `adbi_connect()` (also in `driver.R`)
bypasses per-driver S4 dispatch to call adbi's generic `dbConnect(AdbiDriver, ...)`
directly:

```r
adbi_connect <- function(drv, opts, dots) {
  base_drv <- new("AdbiDriver", driver = drv@driver)
  do.call(DBI::dbConnect, c(list(base_drv), opts, dots))
}
```

**Future use cases enabled by per-driver connection classes:**
- `sqlCreateTable(SnowflakeConnection, ...)` with Snowflake DDL quirks
- `dbWriteTable(SnowflakeConnection, ...)` with `COPY INTO` support
- `dbDataType(SnowflakeConnection, ...)` overrides for driver-specific types

---

## Feature 5: Input validation

**Status: not yet implemented.**

Without validation, missing required params produce cryptic ADBC C-level errors.
odbc gives clear R-level messages before any connection attempt.

### What to add per driver

#### Snowflake
```r
if (is.null(account)) stop("Snowflake 'account' is required. ",
  "Set the SNOWFLAKE_ACCOUNT environment variable or pass account= explicitly.")
```

#### Databricks
```r
if (is.null(workspace)) stop("Databricks 'workspace' URL is required. ",
  "Set the DATABRICKS_HOST environment variable or pass workspace= explicitly.")
if (is.null(http_path)) stop("Databricks 'http_path' is required. ",
  "Set the DATABRICKS_HTTP_PATH environment variable or pass http_path= explicitly.")
if (is.null(token)) stop("No Databricks credentials found. Supply token=, set ",
  "DATABRICKS_TOKEN, or configure the Databricks CLI.")
```

#### BigQuery
```r
if (is.null(project_id)) stop("BigQuery 'project_id' is required. ",
  "Set BIGQUERY_PROJECT or pass project_id= explicitly.")
```

#### All URI-based drivers (PostgreSQL, MySQL, MSSQL, etc.)
```r
if (is.null(uri)) stop("<Driver> connection requires either 'uri' or a 'host'.")
```
Only needed when `build_uri()` would return NULL (host missing).

---

## Feature 6: keyring support

**Status: not yet implemented.**

odbc integrates with the `keyring` package so stored credentials can be retrieved
without putting passwords in scripts. Pattern for any driver with a `pwd` parameter:

```r
if (is.null(pwd) && requireNamespace("keyring", quietly = TRUE)) {
  pwd <- tryCatch(keyring::key_get(service = "dbc/<driver>", username = uid),
                  error = function(e) NULL)
}
```

Drivers that benefit: postgresql, mysql, mssql, redshift, oracle, teradata, sap_hana,
singlestore, exasol, clickhouse, trino.

---

## Feature 7: RStudio Connections pane

**Status: not yet implemented.**

odbc fires `connectionObserver` events so connections appear in the RStudio
Connections pane with server/database/schema/table browsing. adbi does not do this
automatically for subclassed connections.

### What to add

In each `dbConnect()` method, after `promote_connection()`:

```r
observer <- getOption("connectionObserver")
if (!is.null(observer)) {
  observer$connectionOpened(
    type        = "<Driver>",
    displayName = paste0(uid, "@", host, "/", database),
    host        = host %||% workspace %||% account,
    connectCode = paste0('DBI::dbConnect(dbc::<driver>(), ...)'),
    disconnect  = function() DBI::dbDisconnect(con),
    listObjectTypes = function() list(schema = list(contains = "table")),
    listObjects  = function(schema = NULL) {
      if (is.null(schema)) {
        data.frame(name = DBI::dbListObjects(con)$table, type = "schema",
                   stringsAsFactors = FALSE)
      } else {
        data.frame(name = DBI::dbListTables(con), type = "table",
                   stringsAsFactors = FALSE)
      }
    },
    listColumns  = function(schema = NULL, table = NULL, ...) {
      data.frame(name  = names(DBI::dbListFields(con, table)),
                 type  = "column",
                 stringsAsFactors = FALSE)
    },
    previewObject = function(rowLimit, schema = NULL, table = NULL, ...) {
      DBI::dbGetQuery(con, paste("SELECT * FROM", table, "LIMIT", rowLimit))
    }
  )
}
```

`dbDisconnect()` must also fire `observer$connectionClosed(type, host, displayName)`.

Implement this as a shared helper `register_connection_observer(con, type, display_name, host)`
and `deregister_connection_observer(con)` called from a `setMethod("dbDisconnect", "AdbiConnection", ...)` override in `driver.R`.

---

## `update_drivers.R` changes

The current `update_drivers()` generates flat functions into `drivers-generated.R`.

**New behavior:**
- Check which drivers already have a hand-written file in `R/`
- Skip those in `drivers-generated.R`
- For remaining (new/unknown) drivers, continue generating flat functions as today
- This means the generated file is the fallback; hand-written files take priority

```r
update_drivers <- function(pkg = ".") {
  drivers <- dbc_search("")
  hand_written <- sub("\\.R$", "", list.files(file.path(pkg, "R")))
  to_generate  <- setdiff(fn_name(drivers), hand_written)
  # ... generate only to_generate ...
}
```

---

## Priority / phases

### Phase 0 — Research (prerequisite)
- Confirm exact ADBC option strings for each driver by reading the actual ADBC driver
  packages (`adbcsnowflake`, `adbcdatabricks`, `adbcbigquery`, etc.) or their docs.
  The strings listed above in Feature 2 are best-effort from known ADBC specs and should
  be verified before coding.

### Phase 1 — S4 class skeleton + named params (Features 1, 2)
High value, low risk. Start here.

Deliverables:
- One `R/<name>.R` file per driver
- `setClass("<Name>Driver", contains = "AdbiDriver")` in each
- `setMethod("dbConnect", "<Name>Driver", ...)` with documented named params
- NAMESPACE updates for `exportMethods()` and `exportClasses()`
- Hand-written `sqlite.R` migrated to new pattern as the reference implementation
- Update `update_drivers.R` to skip hand-written drivers

### Phase 2 — Connection classes (Feature 4)
Enables per-driver DBI method dispatch for future extensions.

Deliverables:
- `setClass("<Name>Connection", contains = "AdbiConnection")` in each driver file
- `dbConnect()` methods promote returned connection to per-driver class

### Phase 3 — Ambient credentials (Feature 3) — **done**

Deliverables completed:
- `snowflake_credentials()` — Posit Connect, token file, `SNOWFLAKE_TOKEN`
- `databricks_credentials()` — Posit Connect, `DATABRICKS_TOKEN`, OAuth M2M via `httr2`,
  Databricks CLI
- `redshift_credentials()` — IAM via `paws.common` + `paws.database`
- BigQuery + PostgreSQL env-var defaults in `dbConnect()`
- `connectcreds` detected optionally via `requireNamespace`

Outstanding:
- Snowflake CLI path (via `snowflakeauth` package, if/when that package exists)

### Phase 4 — Input validation (Feature 5)
Clear R-level errors before any ADBC call is made.

Deliverables:
- `stop()` with actionable messages when required params are missing:
  Snowflake (`account`), Databricks (`workspace`, `http_path`, `token`),
  BigQuery (`project_id`), URI-based drivers when `build_uri()` would return NULL
- Use `rlang::abort()` with a class tag if `rlang` is available, plain `stop()` otherwise

### Phase 5 — keyring support (Feature 6)
Let users store passwords in the system keychain instead of scripts.

Deliverables:
- Optional `keyring::key_get()` fallback for `pwd` in all drivers that have a `pwd`
  parameter (postgresql, mysql, mssql, redshift, oracle, teradata, sap_hana,
  singlestore, exasol, clickhouse, trino)
- Service name convention: `"dbc/<driver>"` (e.g. `"dbc/postgresql"`)
- No hard dependency; skip silently if `keyring` not installed

### Phase 6 — RStudio Connections pane (Feature 7)
Makes connections browsable in the IDE.

Deliverables:
- `register_connection_observer(con, type, display_name, host)` helper in `driver.R`
- Called at the end of each `dbConnect()` method
- `setMethod("dbDisconnect", "AdbiConnection", ...)` override that fires
  `connectionClosed` and calls `callNextMethod()`

---

## What we are NOT doing (scope boundaries)

- **Connection string DSN support** — odbc-specific concept; not relevant to ADBC
- **ODBC connection attributes** (`azure_token`, etc.) — ADBC uses option strings instead
- **odbcConnectionColumns / odbcConnectionTables overrides** — these are odbc internals;
  adbi implements its own DBI table/column inspection
- **Custom `sqlCreateTable` methods** — future work, out of scope for this plan
- **Temp table handling (SQL Server)** — future work
- **Full `snowflakeauth` / `paws.common` integration** — we'll detect these packages
  optionally, but won't take hard dependencies
