# mirror-jfrog

OCX mirrors for [JFrog](https://github.com/jfrog) tooling. Each package publishes
to `ghcr.io/ocx-contrib/jfrog/<package>` with cascade tags after a smoke test per
`(version, platform)`, then announces the result into the OCX index as
`ocx.sh/jfrog/<package>`.

| Package | Upstream | Index name | Upstream SPDX |
|---|---|---|---|
| [`jfrog-cli/`](jfrog-cli/) | [jfrog-cli](https://github.com/jfrog/jfrog-cli) | `ocx.sh/jfrog/jfrog-cli` | `Apache-2.0` |

JFrog ships **no GitHub release assets** — the binaries live under an HTML
directory index on `releases.jfrog.io`, one folder per version, one folder per
platform, each holding a single raw `jf` / `jf.exe`. So
`jfrog-cli/scripts/generate.py` scrapes that index and emits a `url_index`. The
script uses [`ocx-mirror-sdk`](https://github.com/ocx-sh/ocx-mirror-sdk), pinned
to a published wheel via PEP 723 inline metadata.

The package is named for the product (**JFrog CLI**), not for the executable it
installs (`jf`) — the binary name is recorded in `jfrog-cli/metadata.json`'s
`binaries` claim.

> This repository previously published the same upstream to the flat coordinate
> `ocx.sh/jfrog-cli`. `jfrog/jfrog-cli` is the grouped successor.

## Layout

One directory per package. Everything a package owns — its spec, metadata,
catalog entry, logo, generator and smoke test — lives in its own directory, so
adding a package renames nothing and editing one never triggers another's CI.

```
mirror-base.yml         repo-wide policy (see below)
<package>/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
├── scripts/            url_index generator
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — a
repo-root `logo.*` sits in no workflow's `paths:` filter, so replacing it would
publish nothing until some unrelated edit happened to fire.

### `mirror-base.yml`

Repo-wide policy: `skip_prereleases`, `cascade`, `build_timestamp`, `bin_scan`,
`concurrency`, the platform/container matrix and `notify`. It is **not a spec** —
it has no `name`/`target`/`source` and is never loaded on its own. Each package
opens with `extends: ../mirror-base.yml`.

⚠️ `extends:` is a **shallow merge** of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim goes
back to being asserted rather than verified. Restate a block in full or not at
all.

## Platforms

`jfrog-cli` publishes **five** platform entries:

| Key | Upstream directory | Container legs |
|---|---|---|
| `linux/amd64` | `jfrog-cli-linux-amd64/jf` | `ubuntu:24.04`, `alpine:3.20`, `fedora:40` |
| `linux/arm64` | `jfrog-cli-linux-arm64/jf` | `ubuntu:24.04`, `alpine:3.20`, `fedora:40` |
| `darwin/amd64` | `jfrog-cli-mac-386/jf` | — |
| `darwin/arm64` | `jfrog-cli-mac-arm64/jf` | — |
| `windows/amd64` | `jfrog-cli-windows-amd64/jf.exe` | — |

`os.features` states what an artifact **requires of the host**, not how it was
built. JFrog CLI is a pure-Go build: measured on 2.117.0, both Linux binaries are
**fully static** — no `PT_INTERP`, no `DT_NEEDED` — and upstream publishes no
musl/glibc split to choose between, so both Linux keys are **bare**. Tagging them
`+libc.musl` would be a false requirement that hid them from every glibc host.
The `alpine:3.20` container leg is what turns that claim into evidence; the
measurement is recorded above the `assets:` block in `jfrog-cli/mirror.yml`.

> **Naming trap.** JFrog's macOS Intel build lives under `jfrog-cli-mac-386`.
> That is the 64-bit Intel (amd64) binary despite the name — a historical quirk,
> not a 32-bit build — so it maps to `darwin/amd64`.

There is no `windows/arm64`: each upstream version directory holds exactly one
Windows build, `jfrog-cli-windows-amd64/`. Upstream also ships
`linux-{386,arm,ppc64,ppc64le,s390x}`, none of which has a GitHub runner.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `<package>/mirror.yml`, `mirror-base.yml` | hand | yes — see below |
| `<package>/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `<package>/tests/smoke.star`, `<package>/scripts/*` | hand | — |
| `.github/workflows/*.yml` | **generated** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec jfrog-cli/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

Never hand-edit `.github/workflows/`. `verify-generated.yml` exits 65 on any
drift; if a generated workflow is wrong, the spec or the template is wrong.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

### Bumping the SDK pin

Edit the `[tool.uv.sources]` block at the top of `jfrog-cli/scripts/generate.py`
to point at a newer wheel:

```toml
ocx-mirror-sdk = { url = "https://github.com/ocx-sh/ocx-mirror-sdk/releases/download/vX.Y.Z/ocx_mirror_sdk-X.Y.Z-py3-none-any.whl" }
```

`uv` is the generator's runtime and is pinned in `ocx.toml` as the **namespaced**
`ocx.sh/astral-sh/uv:0`.

## The binaries claim

JFrog CLI ships as a raw binary, so the bundle's only PATH entry is a bare
`${installPath}` — the executable *is* the content root. `bin_scan` only looks
*below* an `${installPath}/<dir>` entry, so `auto`/`verify` is rejected at spec
load with exit 65. `mirror-base.yml` therefore sets `bin_scan: off` and
`jfrog-cli/metadata.json` hand-lists `binaries: ["jf"]` — the blessed shape for
this asset type.

## Smoke testing an Artifactory client offline

`jf` normally talks to a remote JFrog Platform, so `jfrog-cli/tests/smoke.star`
asserts only what runs without one: the `--version` digit shape, and a computed
round-trip through the CLI's own config store (`config add` → `config show` →
`config remove` → `config show`), with `JFROG_CLI_HOME_DIR` pointed at the test
scratch root so the run is hermetic and the env var's wiring is proven by the
side effect.

`--enc-password=false` on `config add` is **load-bearing**: without it the CLI
contacts the server to encrypt the password and exits 1. The configured host is
deliberately under `.invalid` (RFC 6761, guaranteed never to resolve), so a
future release that regressed into dialing out reds instead of silently passing.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
