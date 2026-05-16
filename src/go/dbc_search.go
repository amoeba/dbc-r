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

// dbc_search returns a newline-delimited list of driver paths matching
// pattern (empty string returns all drivers).
// pre controls whether pre-release drivers are included.
// On error the return value starts with "ERROR:".
// The caller must free() the returned string.
//
//export dbc_search
func dbc_search(pattern *C.char, pre C.int) *C.char {
	pat := C.GoString(pattern)
	includePre := pre != 0

	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("ERROR:failed to create dbc client: %s", err))
	}

	drivers, err := client.Search(context.Background(), pat)
	if err != nil && len(drivers) == 0 {
		return C.CString(fmt.Sprintf("ERROR:%s", err))
	}

	// Filter out drivers that only have pre-release versions unless includePre is set
	var filtered []dbc.Driver
	for _, d := range drivers {
		if includePre || d.HasNonPrerelease() || len(d.PkgInfo) == 0 {
			filtered = append(filtered, d)
		}
	}

	paths := make([]string, len(filtered))
	for i, d := range filtered {
		paths[i] = d.Path
	}
	return C.CString(strings.Join(paths, "\n"))
}
