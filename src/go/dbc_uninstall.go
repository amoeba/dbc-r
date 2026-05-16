package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"strings"

	"github.com/columnar-tech/dbc/config"
)

// dbc_uninstall removes the named driver from the specified config level.
// levelStr is the config level ("user" or "system"); empty defaults to user.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_uninstall
func dbc_uninstall(driverName *C.char, levelStr *C.char) *C.char {
	name := C.GoString(driverName)
	level := C.GoString(levelStr)

	// Determine config level
	var cfgLevel config.ConfigLevel
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "system":
		cfgLevel = config.ConfigSystem
	case "user", "":
		cfgLevel = config.ConfigUser
	default:
		return C.CString(fmt.Sprintf("unknown config level %q, valid values are: user, system", level))
	}

	cfg := getConfigForLevel(cfgLevel)

	di, err := config.GetDriver(cfg, name)
	if err != nil {
		return C.CString(fmt.Sprintf("failed to find driver %q: %s", name, err))
	}

	if err := config.UninstallDriver(cfg, di); err != nil {
		return C.CString(fmt.Sprintf("failed to uninstall driver %q: %s", name, err))
	}

	return nilCString()
}
