package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"fmt"

	"github.com/columnar-tech/dbc"
)

// Fallback URLs for drivers without a docs_url in the index
var fallbackDriverDocsUrl = map[string]string{
	"bigquery":   "https://docs.adbc-drivers.org/drivers/bigquery",
	"duckdb":     "https://duckdb.org/docs/stable/clients/adbc",
	"flightsql":  "https://arrow.apache.org/adbc/current/driver/flight_sql.html",
	"mssql":      "https://docs.adbc-drivers.org/drivers/mssql",
	"mysql":      "https://docs.adbc-drivers.org/drivers/mysql",
	"postgresql": "https://arrow.apache.org/adbc/current/driver/postgresql.html",
	"redshift":   "https://docs.adbc-drivers.org/drivers/redshift",
	"snowflake":  "https://arrow.apache.org/adbc/current/driver/snowflake.html",
	"sqlite":     "https://arrow.apache.org/adbc/current/driver/sqlite.html",
	"trino":      "https://docs.adbc-drivers.org/drivers/trino",
}

// dbc_docs returns the documentation URL for a driver.
// If driverName is empty, returns the main dbc docs URL.
// Returns the URL string on success, or "ERROR:<msg>" on failure.
// The caller must free() the returned string.
//
//export dbc_docs
func dbc_docs(driverName *C.char) *C.char {
	name := C.GoString(driverName)

	if name == "" {
		return C.CString("https://docs.columnar.tech/dbc/")
	}

	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("ERROR:failed to create dbc client: %s", err))
	}

	drivers, err := client.Search(context.Background(), name)
	if err != nil && len(drivers) == 0 {
		return C.CString(fmt.Sprintf("ERROR:%s", err))
	}

	var found *dbc.Driver
	for i := range drivers {
		if drivers[i].Path == name {
			found = &drivers[i]
			break
		}
	}
	if found == nil {
		return C.CString(fmt.Sprintf("ERROR:driver `%s` not found in driver registry index", name))
	}

	// Check for docs URL on the driver
	if found.DocsURL != "" {
		return C.CString(found.DocsURL)
	}

	// Check fallback URLs
	if url, ok := fallbackDriverDocsUrl[found.Path]; ok && url != "" {
		return C.CString(url)
	}

	return C.CString(fmt.Sprintf("ERROR:no documentation available for driver `%s`", name))
}
