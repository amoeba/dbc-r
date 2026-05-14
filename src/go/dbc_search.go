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
// pattern (empty string returns all drivers). On error the return value
// starts with "ERROR:". The caller must free() the returned string.
//
//export dbc_search
func dbc_search(pattern *C.char) *C.char {
	pat := C.GoString(pattern)

	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("ERROR:failed to create dbc client: %s", err))
	}

	drivers, err := client.Search(context.Background(), pat)
	if err != nil && len(drivers) == 0 {
		return C.CString(fmt.Sprintf("ERROR:%s", err))
	}

	paths := make([]string, len(drivers))
	for i, d := range drivers {
		paths[i] = d.Path
	}
	return C.CString(strings.Join(paths, "\n"))
}
