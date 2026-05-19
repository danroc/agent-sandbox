#!/usr/bin/env bash
# Test driver for the `agent` launcher.
#
# Each test runs in an isolated temp HOME with PATH-shimmed docker + git stubs. The
# stubs record what the launcher would have run; tests assert on the recorded log
# instead of actually invoking docker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
COMMAND="$REPO_ROOT/agent"

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
    local fn="$1"
    local name="${fn#test_}"
    name="${name//_/ }"
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
        echo "  actual log:" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKER_LOG" >&2
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

assert_volume_count() {
    local expected="$1"
    local actual
    actual="$(grep -oF -- "--volume" "$AGENT_TEST_DOCKER_LOG" | wc -l | tr -d ' ')"
    if [[ "$actual" -ne "$expected" ]]; then
        echo "  expected $expected --volume flags, got $actual" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKER_LOG" >&2
        return 1
    fi
}

assert_log_order() {
    local first="$1" second="$2"
    local line before_first before_second
    line="$(cat "$AGENT_TEST_DOCKER_LOG")"
    before_first="${line%%"$first"*}"
    before_second="${line%%"$second"*}"
    if [[ ${#before_first} -ge ${#before_second} ]]; then
        echo "  expected '$first' to appear before '$second'" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKER_LOG" >&2
        return 1
    fi
}

assert_overlay_run_count() {
    local expected="$1"
    local actual
    actual="$(awk 'after && /^RUN /{c++} /^---$/{after=1} END{print c+0}' "$AGENT_TEST_DOCKERFILE_LOG")"
    if [[ "$actual" -ne "$expected" ]]; then
        echo "  expected $expected RUN lines in overlay Dockerfile, got $actual" >&2
        sed 's/^/    /' "$AGENT_TEST_DOCKERFILE_LOG" >&2
        return 1
    fi
}

# --- Tests ---

test_volume_flag_appends_to_docker_run() {
    "$COMMAND" -v /host/path:/container/path bash -c 'true' || return 1
    assert_log_contains "--volume /host/path:/container/path"
}

test_volume_flag_repeatable() {
    "$COMMAND" -v /a:/b -v /c:/d bash -c 'true' || return 1
    assert_log_contains "--volume /a:/b"
    assert_log_contains "--volume /c:/d"
}

test_volume_flag_equals_syntax() {
    "$COMMAND" --volume=/a:/b bash -c 'true' || return 1
    assert_log_contains "--volume /a:/b"
}

test_volume_flag_requires_argument() {
    if "$COMMAND" -v 2>/dev/null; then
        echo "  expected non-zero exit when -v has no argument" >&2
        return 1
    fi
}

test_no_config_means_no_extra_mounts() {
    "$COMMAND" bash -c 'true' || return 1
    assert_log_contains "--volume $PWD:/workspace"
    assert_log_contains "--volume $SANDBOX_HOME:/home/agent"
    assert_volume_count 2
}

test_config_mounts_added_to_docker_run() {
    cat >"$SANDBOX_ROOT/config.sh" <<EOF
MOUNTS=(
    "/host/notes:/home/agent/notes:ro"
    "/host/aws:/home/agent/.aws"
)
EOF
    "$COMMAND" bash -c 'true' || return 1
    assert_log_contains "--volume /host/notes:/home/agent/notes:ro"
    assert_log_contains "--volume /host/aws:/home/agent/.aws"
}

test_config_home_expansion() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
MOUNTS=("$HOME/notes:/home/agent/notes")
EOF
    "$COMMAND" bash -c 'true' || return 1
    assert_log_contains "--volume $HOME/notes:/home/agent/notes"
}

test_cli_volume_comes_after_config_volume() {
    cat >"$SANDBOX_ROOT/config.sh" <<EOF
MOUNTS=("/host/cfg:/cfg")
EOF
    "$COMMAND" -v /host/cli:/cli bash -c 'true' || return 1
    assert_log_order "--volume /host/cfg:/cfg" "--volume /host/cli:/cli"
}

test_update_with_no_packages_tags_base_as_latest() {
    "$COMMAND" update || return 1
    assert_log_contains "build --pull --no-cache -t local/agent-sandbox:base"
    assert_log_contains "tag local/agent-sandbox:base local/agent-sandbox:latest"
    assert_log_not_contains "build -f"
}

test_update_with_apt_packages_writes_overlay() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
APT_PACKAGES=(tmux htop)
EOF
    "$COMMAND" update || return 1
    assert_log_contains "build --pull --no-cache -t local/agent-sandbox:base"
    assert_dockerfile_contains "FROM local/agent-sandbox:base"
    assert_dockerfile_contains "apt-get install -y --no-install-recommends"
    assert_dockerfile_contains "tmux htop"
    assert_log_not_contains "tag local/agent-sandbox:base local/agent-sandbox:latest"
}

test_update_with_npm_packages_writes_overlay() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
NPM_PACKAGES=(yarn pnpm)
EOF
    "$COMMAND" update || return 1
    assert_dockerfile_contains "FROM local/agent-sandbox:base"
    assert_dockerfile_contains "npm install -g yarn pnpm"
}

test_update_with_both_apt_and_npm_writes_both() {
    cat >"$SANDBOX_ROOT/config.sh" <<'EOF'
APT_PACKAGES=(tmux)
NPM_PACKAGES=(yarn)
EOF
    "$COMMAND" update || return 1
    assert_dockerfile_contains "apt-get install -y --no-install-recommends"
    assert_dockerfile_contains "tmux"
    assert_dockerfile_contains "npm install -g yarn"
    assert_overlay_run_count 2
}

while IFS= read -r fn; do
    run_test "$fn"
done < <(declare -F | awk '{print $3}' | grep '^test_')

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
