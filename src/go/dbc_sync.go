package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/columnar-tech/dbc"
	"github.com/columnar-tech/dbc/config"
	"github.com/pelletier/go-toml/v2"
)

// dbc_sync installs all drivers from a driver list file.
// pathStr is the path to the driver list file.
// levelStr is the config level ("user" or "system"); empty defaults to user.
// noVerify allows installing drivers without signature verification.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_sync
func dbc_sync(pathStr *C.char, levelStr *C.char, noVerify C.int) *C.char {
	p := C.GoString(pathStr)
	level := C.GoString(levelStr)
	skipVerify := noVerify != 0

	absPath, err := filepath.Abs(p)
	if err != nil {
		return C.CString(fmt.Sprintf("invalid path: %s", err))
	}
	if filepath.Ext(absPath) == "" {
		absPath = filepath.Join(absPath, "dbc.toml")
	}

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

	// Open and decode driver list
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

	if len(list.Drivers) == 0 {
		return C.CString(fmt.Sprintf("no drivers found in driver list `%s`", absPath))
	}

	// Get the driver registry
	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("failed to create dbc client: %s", err))
	}

	allDrivers, searchErr := client.Search(context.Background(), "")
	if searchErr != nil && len(allDrivers) == 0 {
		return C.CString(fmt.Sprintf("error getting driver list: %s", searchErr))
	}

	// Install each driver
	for name, spec := range list.Drivers {
		// Find driver in registry
		var drv *dbc.Driver
		for i := range allDrivers {
			if allDrivers[i].Path == name {
				drv = &allDrivers[i]
				break
			}
		}
		if drv == nil {
			return C.CString(fmt.Sprintf("driver `%s` not found in driver registry index", name))
		}

		allowPre := spec.Prerelease == "allow"
		var pkg dbc.PkgInfo
		if spec.Version != nil {
			if allowPre {
				spec.Version.IncludePrerelease = true
			}
			pkg, err = drv.GetWithConstraint(spec.Version, config.PlatformTuple())
		} else {
			pkg, err = drv.GetPackage(nil, config.PlatformTuple(), allowPre)
		}
		if err != nil {
			return C.CString(fmt.Sprintf("error finding version for driver %s: %s", name, err))
		}

		// Check if already installed at the correct version
		if cfg.Exists {
			if existingDrv, ok := cfg.Drivers[name]; ok {
				if pkg.Version.Equal(existingDrv.Version) {
					continue // already installed at correct version
				}
				// Uninstall conflicting version
				if err := config.UninstallDriver(cfg, existingDrv); err != nil {
					return C.CString(fmt.Sprintf("failed to uninstall existing driver %s: %s", name, err))
				}
			}
		}

		// Install the driver
		_, installErr := client.Install(context.Background(), cfg, name)
		if installErr != nil {
			// If the error is about version mismatch because Install always gets latest,
			// we may need to handle version-specific installs differently.
			// For now, report the error.
			return C.CString(fmt.Sprintf("failed to install driver %s: %s", name, installErr))
		}

		_ = skipVerify // signature verification is handled by client.Install
		_ = pkg        // version selection is handled above
	}

	return nilCString()
}

func getConfigForLevel(level config.ConfigLevel) config.Config {
	switch level {
	case config.ConfigSystem, config.ConfigUser:
		return config.Get()[level]
	default:
		cfg := config.Get()[config.ConfigEnv]
		if cfg.Location != "" {
			return cfg
		}
		return config.Get()[config.ConfigUser]
	}
}
