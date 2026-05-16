package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

const initialDriverList = `# dbc driver list

[drivers]
`

// dbc_init creates a new dbc.toml driver list file at the given path.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_init
func dbc_init(pathStr *C.char) *C.char {
	p := C.GoString(pathStr)

	absPath, err := filepath.Abs(p)
	if err != nil {
		return C.CString(fmt.Sprintf("invalid path: %s", err))
	}

	if filepath.Ext(absPath) == "" {
		absPath = filepath.Join(absPath, "dbc.toml")
	}

	_, err = os.Stat(absPath)
	if !errors.Is(err, fs.ErrNotExist) {
		return C.CString(fmt.Sprintf("file %s already exists", absPath))
	}

	if err = os.MkdirAll(filepath.Dir(absPath), 0o777); err != nil {
		return C.CString(fmt.Sprintf("error creating directory for %s: %s", absPath, err))
	}

	if err := os.WriteFile(absPath, []byte(initialDriverList), 0o666); err != nil {
		return C.CString(fmt.Sprintf("error creating file %s: %s", absPath, err))
	}

	return nilCString()
}
