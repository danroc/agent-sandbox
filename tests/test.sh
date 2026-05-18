#!/usr/bin/env bash
# Test driver for the `agent` launcher.
#
# Each test runs in an isolated temp HOME with PATH-shimmed docker + git
# stubs. The stubs record what the launcher would have run; tests assert
# on the recorded log instead of actually invoking docker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENT="$REPO_ROOT/agent"

PASS=0
FAIL=0
FAILED_NAMES=()

setup() {
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-test.XXXXXXXX")"
    HOME="$WORK_DIR/home"
    SANDBOX_ROOT="$HOME/.agent-sandbox"
    SANDBOX_HOME="$SANDBOX_ROOT/home"
    mkdir -p "$SANDBOX_HOME"
    # Provide a Dockerfile so `agent update` has something to "build" from.
    cp "$REPO_ROOT/Dockerfile" "$SANDBOX_ROOT/Dockerfile"

    STUB_BIN="$WORK_DIR/bin"
    mkdir -p "$STUB_BIN"
    cp "$SCRIPT_DIR/stubs/docker" "$STUB_BIN/docker"
    cp "$SCRIPT_DIR/stubs/git" "$STUB_BIN/git"

    AGENT_TEST_DOCKER_LOG="$WORK_DIR/docker.log"
    AGENT_TEST_DOCKERFILE_LOG="$WORK_DIR/dockerfile.log"
    : > "$AGENT_TEST_DOCKER_LOG"
    : > "$AGENT_TEST_DOCKERFILE_LOG"

    export HOME SANDBOX_ROOT SANDBOX_HOME
    export AGENT_TEST_DOCKER_LOG AGENT_TEST_DOCKERFILE_LOG
    export PATH="$STUB_BIN:$PATH"
}

teardown() {
    rm -rf "$WORK_DIR"
}

run_test() {
    local name="$1"
    local fn="$2"
    setup
    if (cd "$WORK_DIR" && "$fn"); then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $name"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
    fi
    teardown
}

assert_log_contains() {
    local needle="$1"
    if ! grep -qF -- "$needle" "$AGENT_TEST_DOCKER_LOG"; then
        echo "  expected docker log to contain: $needle" >&2
        echo "  actual log:" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKER_LOG" >&2
        return 1
    fi
}

assert_log_not_contains() {
    local needle="$1"
    if grep -qF -- "$needle" "$AGENT_TEST_DOCKER_LOG"; then
        echo "  expected docker log NOT to contain: $needle" >&2
        return 1
    fi
}

assert_dockerfile_contains() {
    local needle="$1"
    if ! grep -qF -- "$needle" "$AGENT_TEST_DOCKERFILE_LOG"; then
        echo "  expected dockerfile log to contain: $needle" >&2
        echo "  actual dockerfile log:" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKERFILE_LOG" >&2
        return 1
    fi
}

# --- Tests are appended here by later tasks ---

test_volume_flag_appends_to_docker_run() {
    "$AGENT" -v /host/path:/container/path bash -c 'true' || return 1
    assert_log_contains "--volume /host/path:/container/path"
}

test_volume_flag_repeatable() {
    "$AGENT" -v /a:/b -v /c:/d bash -c 'true' || return 1
    assert_log_contains "--volume /a:/b"
    assert_log_contains "--volume /c:/d"
}

test_volume_flag_equals_syntax() {
    "$AGENT" --volume=/a:/b bash -c 'true' || return 1
    assert_log_contains "--volume /a:/b"
}

test_volume_flag_requires_argument() {
    if "$AGENT" -v 2>/dev/null; then
        echo "  expected non-zero exit when -v has no argument" >&2
        return 1
    fi
}

run_test "volume flag appends to docker run"   test_volume_flag_appends_to_docker_run
run_test "volume flag is repeatable"           test_volume_flag_repeatable
run_test "volume flag supports = syntax"       test_volume_flag_equals_syntax
run_test "volume flag requires an argument"    test_volume_flag_requires_argument

test_no_config_means_no_extra_mounts() {
    "$AGENT" bash -c 'true' || return 1
    # The two baseline mounts must still appear...
    assert_log_contains "--volume $PWD:/workspace"
    assert_log_contains "--volume $SANDBOX_HOME:/home/agent"
    # ...but nothing else.
    if grep -oF -- "--volume" "$AGENT_TEST_DOCKER_LOG" | wc -l | grep -q "^ *2$"; then
        return 0
    fi
    echo "  expected exactly 2 --volume occurrences in docker log" >&2
    sed 's/^/    /' "$AGENT_TEST_DOCKER_LOG" >&2
    return 1
}

test_config_mounts_added_to_docker_run() {
    cat >"$SANDBOX_ROOT/config.sh" <<EOF
MOUNTS=(
    "/host/notes:/home/agent/notes:ro"
    "/host/aws:/home/agent/.aws"
)
EOF
    "$AGENT" bash -c 'true' || return 1
    assert_log_contains "--volume /host/notes:/home/agent/notes:ro"
    assert_log_contains "--volume /host/aws:/home/agent/.aws"
}

test_config_home_expansion() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
MOUNTS=("$HOME/notes:/home/agent/notes")
EOF
    "$AGENT" bash -c 'true' || return 1
    assert_log_contains "--volume $HOME/notes:/home/agent/notes"
}

test_cli_volume_comes_after_config_volume() {
    cat >"$SANDBOX_ROOT/config.sh" <<EOF
MOUNTS=("/host/cfg:/cfg")
EOF
    "$AGENT" -v /host/cli:/cli bash -c 'true' || return 1
    # Read the recorded docker run line and check ordering.
    line="$(cat "$AGENT_TEST_DOCKER_LOG")"
    cfg_pos="${line%%--volume /host/cfg:/cfg*}"
    cli_pos="${line%%--volume /host/cli:/cli*}"
    if [[ ${#cfg_pos} -lt ${#cli_pos} ]]; then
        return 0
    fi
    echo "  expected config mount to appear before CLI mount in: $line" >&2
    return 1
}

run_test "no config file means no extra mounts"          test_no_config_means_no_extra_mounts
run_test "config mounts are added to docker run"         test_config_mounts_added_to_docker_run
run_test "config mounts expand \$HOME"                   test_config_home_expansion
run_test "CLI -v appears after config mounts"            test_cli_volume_comes_after_config_volume

test_update_with_no_packages_tags_base_as_latest() {
    "$AGENT" update || return 1
    assert_log_contains "build --pull --no-cache -t local/agent-sandbox:base" || return 1
    assert_log_contains "tag local/agent-sandbox:base local/agent-sandbox:latest" || return 1
    # No overlay Dockerfile should have been built.
    if grep -qF "build -f" "$AGENT_TEST_DOCKER_LOG"; then
        echo "  expected no overlay build when packages are empty" >&2
        return 1
    fi
}

run_test "update with no packages re-tags :base as :latest"  test_update_with_no_packages_tags_base_as_latest

test_update_with_apt_packages_writes_overlay() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
APT_PACKAGES=(tmux htop)
EOF
    "$AGENT" update || return 1
    assert_log_contains "build --pull --no-cache -t local/agent-sandbox:base"
    assert_dockerfile_contains "FROM local/agent-sandbox:base"
    assert_dockerfile_contains "apt-get install -y --no-install-recommends"
    assert_dockerfile_contains "tmux htop"
    # When there is an overlay, no `docker tag` shortcut should be used.
    if grep -qF "tag local/agent-sandbox:base local/agent-sandbox:latest" "$AGENT_TEST_DOCKER_LOG"; then
        echo "  expected overlay build, not re-tag, when APT_PACKAGES is non-empty" >&2
        return 1
    fi
}

run_test "update with apt packages writes overlay Dockerfile"  test_update_with_apt_packages_writes_overlay

test_update_with_npm_packages_writes_overlay() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
NPM_PACKAGES=(yarn pnpm)
EOF
    "$AGENT" update || return 1
    assert_dockerfile_contains "FROM local/agent-sandbox:base"
    assert_dockerfile_contains "npm install -g yarn pnpm"
}

test_update_with_both_apt_and_npm_writes_both() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
APT_PACKAGES=(tmux)
NPM_PACKAGES=(yarn)
EOF
    "$AGENT" update || return 1
    assert_dockerfile_contains "apt-get install -y --no-install-recommends"
    assert_dockerfile_contains "tmux"
    assert_dockerfile_contains "npm install -g yarn"
    # Overlay must emit two distinct RUN lines, not one merged line. Count
    # RUN lines after the first `---` (which separates base from overlay).
    local overlay_run_count
    overlay_run_count="$(awk 'after && /^RUN /{c++} /^---$/{after=1} END{print c+0}' "$AGENT_TEST_DOCKERFILE_LOG")"
    if [[ "$overlay_run_count" -ne 2 ]]; then
        echo "  expected 2 RUN lines in overlay Dockerfile, got $overlay_run_count" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKERFILE_LOG" >&2
        return 1
    fi
}

run_test "update with npm packages writes overlay Dockerfile"          test_update_with_npm_packages_writes_overlay
run_test "update with both apt and npm packages writes both RUN lines" test_update_with_both_apt_and_npm_writes_both

if [[ ${#@} -gt 0 ]]; then
    "$@"
fi

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
