package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"fmt"
	"unsafe"

	"github.com/columnar-tech/dbc"
	"github.com/columnar-tech/dbc/config"
)

// dbc_install installs the named driver at the user config level.
// Returns NULL on success or a heap-allocated error string that the caller
// must free with free().
//
//export dbc_install
func dbc_install(driverName *C.char) *C.char {
	name := C.GoString(driverName)

	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("failed to create dbc client: %s", err))
	}

	cfg := config.Get()[config.ConfigUser]

	_, err = client.Install(context.Background(), cfg, name)
	if err != nil {
		return C.CString(fmt.Sprintf("%s", err))
	}

	return (*C.char)(unsafe.Pointer(nil))
}

func main() {}
