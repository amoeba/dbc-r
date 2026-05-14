package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"

	"github.com/columnar-tech/dbc"
	"github.com/columnar-tech/dbc/config"
)

// dbc_uninstall removes the named driver from the user config.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_uninstall
func dbc_uninstall(driverName *C.char) *C.char {
	name := C.GoString(driverName)

	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("failed to create dbc client: %s", err))
	}

	cfg := config.Get()[config.ConfigUser]
	if err := client.Uninstall(cfg, name); err != nil {
		return C.CString(fmt.Sprintf("%s", err))
	}

	return nilCString()
}
