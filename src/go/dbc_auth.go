package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"github.com/columnar-tech/dbc/auth"
)

// dbc_auth_login authenticates with a driver registry using an API key.
// registryURL is the registry URL (empty for default).
// apiKey is the API key to authenticate with.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_auth_login
func dbc_auth_login(registryURL *C.char, apiKey *C.char, clientID *C.char) *C.char {
	regURL := C.GoString(registryURL)
	key := C.GoString(apiKey)
	cid := C.GoString(clientID)

	if regURL == "" {
		regURL = auth.DefaultOauthURI()
	}

	if !strings.HasPrefix(regURL, "https://") {
		regURL = "https://" + regURL
	}

	u, err := url.Parse(regURL)
	if err != nil {
		return C.CString(fmt.Sprintf("invalid registry URL: %s", err))
	}

	if key == "" {
		return C.CString("api_key is required for non-interactive login")
	}

	// API key login
	loginURL, _ := u.Parse("/login")
	cred := auth.Credential{
		Type:        auth.TypeApiKey,
		RegistryURL: auth.Uri(*u),
		AuthURI:     auth.Uri(*loginURL),
		ApiKey:      key,
	}

	if err := cred.Refresh(context.TODO()); err != nil {
		return C.CString(fmt.Sprintf("failed to obtain access token using provided API key: %s", err))
	}

	if err := auth.AddCredential(cred, true); err != nil {
		return C.CString(fmt.Sprintf("failed to save credentials: %s", err))
	}

	// Try to fetch license for Columnar private registry
	if auth.IsColumnarPrivateRegistry(u) {
		_ = auth.FetchColumnarLicense(context.TODO(), &cred)
	}

	_ = cid             // client_id is only needed for OAuth device flow
	_ = http.MethodPost // import reference

	return nilCString()
}

// dbc_auth_logout removes credentials for a driver registry.
// registryURL is the registry URL (empty for default).
// purge controls whether all credentials are purged.
// Returns NULL on success or a heap-allocated error string the caller must free().
//
//export dbc_auth_logout
func dbc_auth_logout(registryURL *C.char, purge C.int) *C.char {
	regURL := C.GoString(registryURL)
	doPurge := purge != 0

	if regURL == "" {
		regURL = auth.DefaultOauthURI()
	}

	if !strings.HasPrefix(regURL, "https://") {
		regURL = "https://" + regURL
	}

	u, err := url.Parse(regURL)
	if err != nil {
		return C.CString(fmt.Sprintf("invalid registry URL: %s", err))
	}

	if doPurge {
		if err := auth.PurgeCredentials(); err != nil {
			return C.CString(fmt.Sprintf("failed to purge credentials: %s", err))
		}
	} else {
		if err := auth.RemoveCredential(auth.Uri(*u)); err != nil {
			return C.CString(fmt.Sprintf("failed to log out: %s", err))
		}
	}

	return nilCString()
}
