module example.com/my-extension/infra/core-v0.0.6

go 1.27.2

require (
	github.com/margince/margince/backend v0.0.0
	github.com/margince/margince/composition v0.0.0
	github.com/margince/margince/extensions/de v0.0.0
	github.com/margince/margince/extensions/openchannel v0.0.0
	github.com/margince/margince/extensions/vn v0.0.0
	github.com/taitran-gradion/my-extension v0.0.0
)

// The extension under test: this repository's root, as you edit it.
replace github.com/taitran-gradion/my-extension => ../..

// What the matching core composed for this instance.
replace github.com/margince/margince/composition => ./.margince/core/build/composition/backend

// The core version this instance tests against. instance.mk reads the
// backend's version here; keep all four the same.
replace (
	github.com/margince/margince/backend => github.com/taitran-gradion/margince/backend v0.0.6-poc.1
	github.com/margince/margince/extensions/de => github.com/taitran-gradion/margince/extensions/de v0.0.6-poc.1
	github.com/margince/margince/extensions/openchannel => github.com/taitran-gradion/margince/extensions/openchannel v0.0.6-poc.1
	github.com/margince/margince/extensions/vn => github.com/taitran-gradion/margince/extensions/vn v0.0.6-poc.1
)
