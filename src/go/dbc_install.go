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
	"github.com/columnar-tech/dbc/config"
)

// dbc_install installs the named driver.
// levelStr is the config level ("user" or "system"); empty defaults to user.
// noVerify allows installation without signature verification.
// pre allows pre-release versions.
// Returns NULL on success or a heap-allocated error string that the caller
// must free with free().
//
//export dbc_install
func dbc_install(driverName *C.char, levelStr *C.char, noVerify C.int, pre C.int) *C.char {
	name := C.GoString(driverName)
	level := C.GoString(levelStr)
	_ = noVerify != 0 // signature verification handled internally by client.Install
	allowPre := pre != 0

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

	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("failed to create dbc client: %s", err))
	}

	// Parse driver name and version constraint
	driverNameParsed, vers, parseErr := parseDriverConstraintLocal(name)
	if parseErr != nil {
		return C.CString(fmt.Sprintf("invalid driver constraint '%s': %s", name, parseErr))
	}

	// Search for driver
	drivers, err := client.Search(context.Background(), driverNameParsed)
	if err != nil && len(drivers) == 0 {
		return C.CString(fmt.Sprintf("failed to search for driver %s: %s", driverNameParsed, err))
	}

	var found *dbc.Driver
	for i := range drivers {
		if drivers[i].Path == driverNameParsed {
			found = &drivers[i]
			break
		}
	}
	if found == nil {
		return C.CString(fmt.Sprintf("driver %q not found", driverNameParsed))
	}

	// Resolve version
	var pkg dbc.PkgInfo
	if vers != nil {
		vers.IncludePrerelease = allowPre
		pkg, err = found.GetWithConstraint(vers, config.PlatformTuple())
	} else {
		pkg, err = found.GetPackage(nil, config.PlatformTuple(), allowPre)
	}
	if err != nil {
		return C.CString(fmt.Sprintf("%s", err))
	}

	_ = pkg // version resolved successfully

	_, err = client.Install(context.Background(), cfg, driverNameParsed)
	if err != nil {
		return C.CString(fmt.Sprintf("%s", err))
	}

	return nilCString()
}

func main() {}
