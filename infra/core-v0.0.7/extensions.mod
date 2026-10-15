module margince.local/installation

go 1.27.2

require github.com/taitran-gradion/my-extension v0.0.0

// The extension under test, composed in place from this repository's root.
replace github.com/taitran-gradion/my-extension => ../..
