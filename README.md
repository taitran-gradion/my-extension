# my-extension

A Margince extension unit. It ships:

- one agent tool, `my_extension_ping`, at `GET /v1/ext/my-extension/ping`;
- a demo screen at `#/ext/my-extension` (`frontend/`), in English, German and Vietnamese;
- a workspace-scoped credential, `api_token`, which lists the unit under Settings → Integrations
  with a link to its screen.

`Version` in `myextension.go`, `version` in `api/crm.yaml` and `UNIT_VERSION` in
`frontend/screen.tsx` move together with the release tag.

## Develop

Needs Go, pnpm, Docker and rsync, the same as Margince core.

```bash
make install   # once: fetch core at margince.version, install its tools
make dev       # core with this unit composed in; prints the app port
make test      # this unit's tests
make check     # every core gate against this unit, before a release
make stop      # stop the dev stack
```

Core is fetched into `.margince/core` (ignored) at the tag in `margince.version`. Each target
copies this folder into `.margince/core/extensions/my-extension/`, so edit files here and never
in the copy. `make dev` must run again after a Go change; the frontend reloads on its own.

## Install into a Margince build

Copy this folder, without `.margince/`, to `extensions/my-extension/` in the Margince tree and
run `make composition`. The folder being there turns the unit on.
