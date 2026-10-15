# my-extension

A Margince extension unit. It ships:

- one agent tool, `my_extension_ping`, at `GET /v1/ext/my-extension/ping`;
- a demo screen at `#/ext/my-extension` (`frontend/`), in English, German and Vietnamese;
- a workspace-scoped credential, `api_token`, which lists the unit under Settings → Integrations
  with a link to its screen.

`Version` in `myextension.go`, `version` in `api/crm.yaml` and `UNIT_VERSION` in
`frontend/screen.tsx` move together with the release tag.

## Develop against several core versions

`infra/` holds one thin Margince instance per core version this extension supports:

| Instance | Core | App |
|---|---|---|
| `infra/core-v0.0.6` | `v0.0.6-poc.1` | http://localhost:8191 |
| `infra/core-v0.0.7` | `v0.0.7-poc.2` | http://localhost:8192 |

Each instance loads the extension from this repository's root (`replace … => ../..` in its
`go.mod` and `extensions.mod`), so every edit here is what runs: Vite reloads the screen, and
the Go side needs `make up` again. Each fetches its own core at the version its `go.mod` names,
into its own ignored `.margince/`. `infra/` is made of nested Go modules, so none of it ships in
this extension's module zip.

Needs Go, pnpm and Docker, and the local Postgres, Redis and object store that `make dev` in
Margince core starts.

```bash
make test        # Go tests, against every core version
make typecheck   # the composed app with this screen, against every core version
make check       # both, before a release
make up V=core-v0.0.6   # run one instance (default: the newest)
make stop        # stop every instance
make work        # go.work for your editor, core from the newest instance
```

To support another core version, copy an `infra/core-*` folder, change the version in its
`go.mod` (all four `replace` lines), and give its `Makefile` its own ports, database and Redis
number.

## Install into a Margince build

Require it in the installation's `extensions.mod`:

```text
require github.com/taitran-gradion/my-extension <version>
```
