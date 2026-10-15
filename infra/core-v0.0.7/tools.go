//go:build tools

// Keeps core's three role binaries in this module's build list.
package tools

import (
	_ "github.com/margince/margince/backend/cmd/api"
	_ "github.com/margince/margince/backend/cmd/migrate"
	_ "github.com/margince/margince/backend/cmd/worker"
)
