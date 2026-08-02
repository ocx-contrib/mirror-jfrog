# jfrog-cli/tests/smoke.star — stable across upstream JFrog CLI releases.
# Asserts behavior/contract (exit codes, version digits, env-var honoring, a
# computed round-trip), never upstream-controlled prose. See testing-practices.md.
JF = "jf.exe" if ocx.target_platform.os == ocx.os.Windows else "jf"

# `jf` is a client for a remote JFrog Platform, so everything below is chosen to
# run WITHOUT one:
#   - JFROG_CLI_HOME_DIR points the CLI's state at scratch, so nothing touches
#     the runner's real ~/.jfrog and the run is hermetic.
#   - JFROG_CLI_AVOID_NEW_VERSION_WARNING suppresses upstream's "a newer version
#     is available" banner, which is otherwise an outbound HTTP call on every
#     invocation of every mirrored version.
HOME_DIR = ocx.scratch_root + "/jfrog-home"
ENV = {
    "JFROG_CLI_HOME_DIR": HOME_DIR,
    "JFROG_CLI_AVOID_NEW_VERSION_WARNING": "TRUE",
}

# Tier 1 + 2: liveness on the composed PATH + version SHAPE.
# `jf --version` prints e.g. "jf version 2.117.0" — match the digits only; the
# leading word has already changed once (jfrog → jf) and would break a literal.
r_version = ocx.run(JF, "--version", env=ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# Tier 3 + 4: offline computed round-trip through the CLI's own config store,
# which also proves JFROG_CLI_HOME_DIR is honored.
#
# `config add` normally contacts the server to encrypt the password —
# `--enc-password=false` is what keeps it local. WITHOUT that flag this exits 1
# on a GET to <url>/api/security/encryptedPassword (verified against the real
# binary), so it is load-bearing, not decoration. The host is deliberately
# `.invalid` (RFC 6761 — guaranteed never to resolve): if a future release
# regressed and started dialing out, this reds instead of silently passing.
SERVER_ID = "ocx-smoke"
SERVER_URL = "https://ocx-smoke.invalid/artifactory/"

r_add = ocx.run(
    JF, "config", "add", SERVER_ID,
    "--url=" + SERVER_URL,
    "--user=ocx", "--password=ocx",
    "--interactive=false", "--enc-password=false",
    env=ENV,
)
expect.ok(r_add)

# Read back what we wrote. Both tokens are values THIS script supplied, so the
# assertion is on the round-trip, not on upstream's field labels.
r_show = ocx.run(JF, "config", "show", env=ENV)
expect.ok(r_show)
expect.contains(r_show.stdout, SERVER_ID)
expect.contains(r_show.stdout, SERVER_URL)

# ... and the delete half of the round-trip: gone means gone.
r_remove = ocx.run(JF, "config", "remove", SERVER_ID, "--quiet", env=ENV)
expect.ok(r_remove)

r_after = ocx.run(JF, "config", "show", env=ENV)
expect.ok(r_after)
expect.false(SERVER_ID in r_after.stdout)

# The env var was honored: the CLI materialized its state under scratch, where
# JFROG_CLI_HOME_DIR pointed — not in the runner's home. Assert the directory,
# not a filename (those carry a schema-version suffix and churn).
expect.true(ocx.exists("jfrog-home"))
