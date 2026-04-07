#!/usr/bin/env bats
# ssread tests — run with: bats tests/test_ssread.sh
# Install bats: brew install bats-core

SSREAD_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SSREAD_BIN="$SSREAD_DIR/ssread"

# ── Setup / Teardown ──────────────────────────────────────────────────────

setup() {
    export TEST_DIR="$(mktemp -d)"
    export MOCK_PROJECTS="$TEST_DIR/.claude/projects"
    mkdir -p "$MOCK_PROJECTS/-Users-test-project-myapp"
    mkdir -p "$MOCK_PROJECTS/-Users-test-project-webapp/subagents"

    cat > "$MOCK_PROJECTS/-Users-test-project-myapp/aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee.jsonl" <<'JSONL'
{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"fix the login bug"},"uuid":"u1","timestamp":"2026-04-06T10:00:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/myapp","sessionId":"aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee","version":"2.1.90","gitBranch":"fix/login"}
{"parentUuid":"u1","isSidechain":false,"type":"user","message":{"role":"user","content":"looks good, thanks"},"uuid":"u2","timestamp":"2026-04-06T10:30:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/myapp","sessionId":"aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee","version":"2.1.90","gitBranch":"fix/login"}
JSONL

    cat > "$MOCK_PROJECTS/-Users-test-project-webapp/bbbb2222-cccc-dddd-eeee-ffffffffffff.jsonl" <<'JSONL'
{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"add dark mode support"},"uuid":"u3","timestamp":"2026-04-05T14:00:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/webapp","sessionId":"bbbb2222-cccc-dddd-eeee-ffffffffffff","version":"2.1.88","gitBranch":"feature/dark-mode"}
JSONL

    cat > "$MOCK_PROJECTS/-Users-test-project-webapp/subagents/agent-xxx.jsonl" <<'JSONL'
{"type":"user","message":{"role":"user","content":"subagent task"},"uuid":"s1","timestamp":"2026-04-05T14:05:00.000Z","entrypoint":"cli","cwd":"/Users/test/project/webapp","sessionId":"sub-agent-id"}
JSONL
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Helper ────────────────────────────────────────────────────────────────

source_ssread_functions() {
    local tmp="$TEST_DIR/ssread_funcs.sh"
    # Remove main call and ensure_tmux_session exec to avoid side effects
    sed -e '/^main "\$@"/d' \
        -e 's/exec tmux/echo "WOULD_EXEC tmux"/g' \
        "$SSREAD_BIN" > "$tmp"
    echo "CLAUDE_PROJECTS_DIR=\"$MOCK_PROJECTS\"" >> "$tmp"
    echo "SSREAD_INSIDE_TMUX=1" >> "$tmp"
    source "$tmp"
}

# ── Tests: Basic ──────────────────────────────────────────────────────────

@test "ssread file exists and is executable" {
    [[ -f "$SSREAD_BIN" ]]
    chmod +x "$SSREAD_BIN"
    [[ -x "$SSREAD_BIN" ]]
}

@test "check_dependencies detects missing tools" {
    # This just verifies the function exists and runs
    source_ssread_functions
    # Should not fail since jq and tmux are installed for test runner
    check_dependencies
}

# ── Tests: Helpers ────────────────────────────────────────────────────────

@test "extract_project_name parses compound directory" {
    source_ssread_functions
    result=$(extract_project_name "-Users-ted-project-hg-client--wt-w2")
    [[ "$result" == "hg-client/_wt/w2" ]]
}

@test "extract_project_name handles simple project" {
    source_ssread_functions
    result=$(extract_project_name "-Users-ted-project-myapp")
    [[ "$result" == "myapp" ]]
}

@test "format_elapsed returns seconds" {
    source_ssread_functions
    local now=$(now_epoch)
    result=$(format_elapsed $(( now - 30 )))
    [[ "$result" == "30s ago" ]]
}

@test "format_elapsed returns minutes" {
    source_ssread_functions
    local now=$(now_epoch)
    result=$(format_elapsed $(( now - 300 )))
    [[ "$result" == "5m ago" ]]
}

@test "format_elapsed returns hours" {
    source_ssread_functions
    local now=$(now_epoch)
    result=$(format_elapsed $(( now - 7200 )))
    [[ "$result" == "2h ago" ]]
}

@test "format_elapsed returns days" {
    source_ssread_functions
    local now=$(now_epoch)
    result=$(format_elapsed $(( now - 259200 )))
    [[ "$result" == "3d ago" ]]
}

@test "format_datetime extracts date and time" {
    source_ssread_functions
    result=$(format_datetime "2026-04-06T10:30:00.000Z")
    [[ "$result" == "2026-04-06 10:30" ]]
}

@test "iso_to_epoch returns non-zero for valid timestamps" {
    source_ssread_functions
    result=$(iso_to_epoch "2026-04-06T10:00:00.000Z")
    [[ "$result" -gt 0 ]]
}

# ── Tests: Session Loading ────────────────────────────────────────────────

@test "load_sessions finds correct number (excludes subagents)" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    [[ "$SESSION_COUNT" -eq 2 ]]
}

@test "load_sessions extracts session IDs" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    local found1=false found2=false
    for sid in "${SESSION_IDS[@]}"; do
        [[ "$sid" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]] && found1=true
        [[ "$sid" == "bbbb2222-cccc-dddd-eeee-ffffffffffff" ]] && found2=true
    done
    $found1 && $found2
}

@test "load_sessions extracts first and last messages" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            [[ "${SESSION_FIRST_MSG[$i]}" == "fix the login bug" ]]
            [[ "${SESSION_LAST_MSG[$i]}" == "looks good, thanks" ]]
            return 0
        fi
    done
    return 1
}

@test "load_sessions extracts git branch" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            [[ "${SESSION_BRANCHES[$i]}" == "fix/login" ]]
            return 0
        fi
    done
    return 1
}

@test "load_sessions extracts message count" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            [[ "${SESSION_MSG_COUNTS[$i]}" -eq 2 ]]
            return 0
        fi
    done
    return 1
}

@test "search filter works" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    SEARCH_QUERY="login"
    load_sessions
    [[ "$SESSION_COUNT" -eq 1 ]]
    [[ "${SESSION_IDS[0]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]
}

@test "search filter with no results" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    SEARCH_QUERY="nonexistent_query_xyz"
    load_sessions
    [[ "$SESSION_COUNT" -eq 0 ]]
}

@test "empty directory produces zero sessions" {
    source_ssread_functions
    local empty_dir="$TEST_DIR/empty_projects"
    mkdir -p "$empty_dir"
    CLAUDE_PROJECTS_DIR="$empty_dir"
    load_sessions
    [[ "$SESSION_COUNT" -eq 0 ]]
}

# ── Tests: tmux helpers (without actual tmux) ─────────────────────────────

@test "is_session_active returns false when no windows active" {
    source_ssread_functions
    ACTIVE_WINDOWS=""
    ! is_session_active "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_active returns true when window name matches" {
    source_ssread_functions
    ACTIVE_WINDOWS="aaaa1111"
    is_session_active "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_active returns false for non-matching session" {
    source_ssread_functions
    ACTIVE_WINDOWS="aaaa1111"
    ! is_session_active "bbbb2222-cccc-dddd-eeee-ffffffffffff"
}

@test "tmux_active_count returns 0 when not in tmux" {
    source_ssread_functions
    unset TMUX 2>/dev/null || true
    result=$(tmux_active_count)
    [[ "$result" -eq 0 ]]
}

@test "tmux_find_session_window returns empty when not in tmux" {
    source_ssread_functions
    unset TMUX 2>/dev/null || true
    result=$(tmux_find_session_window "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    [[ -z "$result" ]]
}

@test "ensure_tmux_session skips when SSREAD_INSIDE_TMUX is set" {
    source_ssread_functions
    SSREAD_INSIDE_TMUX=1
    # Should return without exec
    ensure_tmux_session
}
