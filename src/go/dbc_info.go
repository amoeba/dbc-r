package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"fmt"
	"strings"

	"github.com/columnar-tech/dbc"
)

// dbc_info returns tab-delimited info for a single driver:
//   path\ttitle\tversion\tlicense\tdescription\tplatforms
// where platforms is a comma-separated list.
// Returns "ERROR:<msg>" on failure. The caller must free() the result.
//
//export dbc_info
func dbc_info(driverName *C.char) *C.char {
	name := C.GoString(driverName)

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
		return C.CString(fmt.Sprintf("ERROR:driver %q not found", name))
	}

	vi, ok := found.MaxVersion()
	version := ""
	var platforms []string
	if ok {
		version = vi.Version.String()
		for _, p := range vi.Packages {
			platforms = append(platforms, p.Platform)
		}
	}

	fields := []string{
		found.Path,
		found.Title,
		version,
		found.License,
		found.Desc,
		strings.Join(platforms, ","),
	}
	return C.CString(strings.Join(fields, "\t"))
}
