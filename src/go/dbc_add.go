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

	"github.com/Masterminds/semver/v3"
	"github.com/columnar-tech/dbc"
	"github.com/columnar-tech/dbc/config"
	"github.com/pelletier/go-toml/v2"
)

type driversList struct {
	Drivers map[string]driverSpec `toml:"drivers"`
}

type driverSpec struct {
	Prerelease string              `toml:"prerelease,omitempty"`
	Version    *semver.Constraints `toml:"version"`
}

// dbc_add adds one or more drivers to a driver list file.
// drivers is a newline-delimited list of driver names (optionally with version constraints).
// pathStr is the path to the driver list file.
// pre controls whether pre-release versions are allowed.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_add
func dbc_add(drivers *C.char, pathStr *C.char, pre C.int) *C.char {
	driverList := strings.Split(C.GoString(drivers), "\n")
	p := C.GoString(pathStr)
	allowPre := pre != 0

	absPath, err := filepath.Abs(p)
	if err != nil {
		return C.CString(fmt.Sprintf("invalid path: %s", err))
	}
	if filepath.Ext(absPath) == "" {
		absPath = filepath.Join(absPath, "dbc.toml")
	}

	// Parse driver specs
	type driverInput struct {
		Name string
		Vers *semver.Constraints
	}
	var specs []driverInput
	for _, d := range driverList {
		d = strings.TrimSpace(d)
		if d == "" {
			continue
		}
		name, vers, err := parseDriverConstraintLocal(d)
		if err != nil {
			return C.CString(fmt.Sprintf("invalid driver constraint '%s': %s", d, err))
		}
		specs = append(specs, driverInput{Name: name, Vers: vers})
	}

	if len(specs) == 0 {
		return C.CString("no drivers specified")
	}

	// Search registry to validate drivers exist
	client, err := dbc.NewClient()
	if err != nil {
		return C.CString(fmt.Sprintf("failed to create dbc client: %s", err))
	}

	allDrivers, _ := client.Search(context.Background(), "")

	// Open and decode existing driver list
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
		list.Drivers = make(map[string]driverSpec)
	}

	// Validate and add each driver
	for _, spec := range specs {
		// Find driver in registry
		var found bool
		for _, d := range allDrivers {
			if d.Path == spec.Name {
				found = true
				// Validate version constraint if provided
				if spec.Vers != nil {
					spec.Vers.IncludePrerelease = allowPre
					_, err = d.GetWithConstraint(spec.Vers, config.PlatformTuple())
					if err != nil {
						return C.CString(fmt.Sprintf("error getting driver: %s", err))
					}
				} else if !allowPre && !d.HasNonPrerelease() {
					return C.CString(fmt.Sprintf("driver `%s` not found (but prerelease versions filtered out); try allowing pre-release", spec.Name))
				}
				break
			}
		}
		if !found {
			return C.CString(fmt.Sprintf("driver `%s` not found in driver registry index", spec.Name))
		}

		ds := driverSpec{Version: spec.Vers}
		if allowPre {
			ds.Prerelease = "allow"
		}
		list.Drivers[spec.Name] = ds
	}

	// Write updated driver list
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

func parseDriverConstraintLocal(driver string) (string, *semver.Constraints, error) {
	driver = strings.TrimSpace(driver)
	splitIdx := strings.IndexAny(driver, " ~^<>=!")
	if splitIdx == -1 {
		return driver, nil, nil
	}

	driverName := driver[:splitIdx]
	constraints, err := semver.NewConstraint(strings.TrimSpace(driver[splitIdx:]))
	if err != nil {
		return "", nil, fmt.Errorf("invalid version constraint: %w", err)
	}

	return driverName, constraints, nil
}
