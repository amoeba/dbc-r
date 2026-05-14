package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"sort"
	"strings"

	"github.com/columnar-tech/dbc/config"
)

// dbc_list_drivers returns installed drivers as a tab-delimited table
// (id, name, version, level, path), one row per line.
// Returns "ERROR:<msg>" on failure. The caller must free() the result.
//
//export dbc_list_drivers
func dbc_list_drivers() *C.char {
	cfgs := config.Get()

	type row struct {
		level config.ConfigLevel
		id    string
		name  string
		ver   string
		path  string
	}

	var rows []row
	for _, lvl := range []config.ConfigLevel{config.ConfigSystem, config.ConfigUser, config.ConfigEnv} {
		cfg, ok := cfgs[lvl]
		if !ok {
			continue
		}
		if cfg.Err != nil {
			return C.CString(fmt.Sprintf("ERROR:failed to list drivers at %s level: %s", lvl, cfg.Err))
		}
		for _, d := range cfg.Drivers {
			ver := ""
			if d.Version != nil {
				ver = d.Version.String()
			}
			rows = append(rows, row{lvl, d.ID, d.Name, ver, d.FilePath})
		}
	}

	sort.Slice(rows, func(i, j int) bool {
		if rows[i].level != rows[j].level {
			return rows[i].level > rows[j].level
		}
		return rows[i].id < rows[j].id
	})

	lines := make([]string, len(rows))
	for i, r := range rows {
		lines[i] = strings.Join([]string{r.id, r.name, r.ver, r.level.String(), r.path}, "\t")
	}

	return C.CString(strings.Join(lines, "\n"))
}
