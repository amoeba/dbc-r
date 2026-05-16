package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/pelletier/go-toml/v2"
)

// dbc_remove removes a driver from a driver list file.
// driverName is the driver to remove; pathStr is the path to the driver list.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_remove
func dbc_remove(driverName *C.char, pathStr *C.char) *C.char {
	name := strings.TrimSpace(C.GoString(driverName))
	p := C.GoString(pathStr)

	absPath, err := filepath.Abs(p)
	if err != nil {
		return C.CString(fmt.Sprintf("invalid path: %s", err))
	}
	if filepath.Ext(absPath) == "" {
		absPath = filepath.Join(absPath, "dbc.toml")
	}

	f, err := os.Open(absPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return C.CString(fmt.Sprintf("error opening driver list: %s doesn't exist. Did you run dbc init?", p))
		}
		return C.CString(fmt.Sprintf("error opening driver list at %s: %s", p, err))
	}

	var list driversList
	if err := toml.NewDecoder(f).Decode(&list); err != nil {
		f.Close()
		return C.CString(fmt.Sprintf("error decoding driver list: %s", err))
	}
	f.Close()

	if list.Drivers == nil {
		return C.CString(fmt.Sprintf("no drivers found in %s", absPath))
	}

	_, ok := list.Drivers[name]
	if !ok {
		return C.CString(fmt.Sprintf("driver '%s' not found in %s", name, absPath))
	}

	delete(list.Drivers, name)

	wf, err := os.Create(absPath)
	if err != nil {
		return C.CString(fmt.Sprintf("error creating file %s: %s", absPath, err))
	}
	defer wf.Close()

	if err := toml.NewEncoder(wf).Encode(list); err != nil {
		return C.CString(fmt.Sprintf("error encoding driver list: %s", err))
	}

	return nilCString()
}
