# NOTICE

This repository packages and redistributes upstream software published by
[JFrog](https://github.com/jfrog). The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

Each package's logo is reproduced for catalog identification only, under
nominative fair use. The marks remain the property of their respective owners
and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `jfrog-cli` | `ghcr.io/ocx-contrib/jfrog/jfrog-cli` | `Apache-2.0` |

---

## `jfrog-cli`

Upstream: <https://github.com/jfrog/jfrog-cli>
Binaries: <https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf/>
Published to `ghcr.io/ocx-contrib/jfrog/jfrog-cli`.

| Component | SPDX | Holder |
|---|---|---|
| JFrog CLI (`jf`) | **Apache-2.0** | JFrog Ltd. |

Permissive; redistribution of the compiled binary is granted provided the
license text and any attribution notices are retained. Upstream ships raw
binaries with no bundled `LICENSE` file, so the terms are those of
<https://github.com/jfrog/jfrog-cli/blob/master/LICENSE>. Upstream publishes no
`NOTICE` file, so there is none to reproduce under Apache-2.0 §4(d). The
published binaries statically link third-party Go modules under permissive
licenses, enumerated in upstream's `go.mod`.

JFrog, Artifactory and Xray are trademarks of JFrog Ltd., used here for catalog
identification under nominative fair use.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
