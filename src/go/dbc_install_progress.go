package main

/*
#include <stdlib.h>
#include <stdint.h>

// Progress callback type: called with (written_bytes, total_bytes).
// total_bytes may be -1 if unknown.
typedef void (*dbc_progress_fn)(int64_t written, int64_t total);

// Helper to invoke the callback from Go (cgo can't call function pointers directly).
static void invoke_progress_cb(dbc_progress_fn cb, int64_t written, int64_t total) {
    if (cb) cb(written, total);
}
*/
import "C"

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/columnar-tech/dbc"
	"github.com/columnar-tech/dbc/config"
)

// dbc_install_progress installs a driver with progress reporting via a C callback.
// The callback is invoked periodically with (bytes_written, total_bytes).
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_install_progress
func dbc_install_progress(driverName *C.char, levelStr *C.char, noVerify C.int, pre C.int, cb C.dbc_progress_fn) *C.char {
	name := C.GoString(driverName)
	level := C.GoString(levelStr)
	skipVerify := noVerify != 0
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

	// Resolve version/package
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

	// Download with progress using the DownloadPackage method which provides
	// Content-Length and progress reporting
	downloaded, err := pkg.DownloadPackage(func(written, total int64) {
		C.invoke_progress_cb(cb, C.int64_t(written), C.int64_t(total))
	})
	if err != nil {
		return C.CString(fmt.Sprintf("failed to download driver: %s", err))
	}
	defer os.RemoveAll(filepath.Dir(downloaded.Name()))

	// Install the driver (extract tarball, create manifest)
	manifest, err := config.InstallDriver(cfg, driverNameParsed, downloaded)
	if err != nil {
		return C.CString(fmt.Sprintf("failed to install driver %s: %s", driverNameParsed, err))
	}

	// Verify signature unless disabled
	if !skipVerify && manifest.Files.Driver != "" {
		driverPath := manifest.DriverInfo.Driver.Shared.Get(config.PlatformTuple())
		sigDir := filepath.Dir(driverPath)
		sigFile := manifest.Files.Signature
		if sigFile == "" {
			sigFile = manifest.Files.Driver + ".sig"
		}

		lib, err := os.Open(filepath.Join(sigDir, manifest.Files.Driver))
		if err != nil {
			os.RemoveAll(filepath.Dir(driverPath))
			return C.CString(fmt.Sprintf("signature verification failed: could not open driver file: %s", err))
		}
		defer lib.Close()

		sig, err := os.Open(filepath.Join(sigDir, sigFile))
		if err != nil {
			os.RemoveAll(filepath.Dir(driverPath))
			return C.CString(fmt.Sprintf("signature file '%s' for driver is missing", sigFile))
		}
		defer sig.Close()

		if err := dbc.SignedByColumnar(lib, sig); err != nil {
			os.RemoveAll(filepath.Dir(driverPath))
			return C.CString(fmt.Sprintf("signature verification failed: %s", err))
		}
	}

	// Create the manifest file
	if err := config.CreateManifest(cfg, manifest.DriverInfo); err != nil {
		return C.CString(fmt.Sprintf("failed to create manifest for driver %s: %s", driverNameParsed, err))
	}

	return nilCString()
}
