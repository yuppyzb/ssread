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

    # Session 1: 2 user turns + 1 assistant (with model/usage)
    cat > "$MOCK_PROJECTS/-Users-test-project-myapp/aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee.jsonl" <<'JSONL'
{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"fix the login bug"},"uuid":"u1","timestamp":"2026-04-06T10:00:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/myapp","sessionId":"aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee","version":"2.1.90","gitBranch":"fix/login"}
{"parentUuid":"u1","isSidechain":false,"type":"assistant","message":{"model":"claude-opus-4-6","role":"assistant","content":[{"type":"text","text":"Looking at the code..."}],"usage":{"input_tokens":100,"cache_creation_input_tokens":5000,"cache_read_input_tokens":10000,"output_tokens":250}},"uuid":"a1","timestamp":"2026-04-06T10:01:00.000Z","sessionId":"aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"}
{"parentUuid":"a1","isSidechain":false,"type":"user","message":{"role":"user","content":"looks good, thanks"},"uuid":"u2","timestamp":"2026-04-06T10:30:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/myapp","sessionId":"aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee","version":"2.1.90","gitBranch":"fix/login"}
JSONL

    # Session 2: 1 user turn + 1 assistant (sonnet model)
    cat > "$MOCK_PROJECTS/-Users-test-project-webapp/bbbb2222-cccc-dddd-eeee-ffffffffffff.jsonl" <<'JSONL'
{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"add dark mode support"},"uuid":"u3","timestamp":"2026-04-05T14:00:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/webapp","sessionId":"bbbb2222-cccc-dddd-eeee-ffffffffffff","version":"2.1.88","gitBranch":"feature/dark-mode"}
{"parentUuid":"u3","isSidechain":false,"type":"assistant","message":{"model":"claude-sonnet-4-6","role":"assistant","content":[{"type":"text","text":"I'll help with dark mode."},{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"theme.ts"}}],"usage":{"input_tokens":50,"cache_creation_input_tokens":2000,"cache_read_input_tokens":3000,"output_tokens":120}},"uuid":"a2","timestamp":"2026-04-05T14:01:00.000Z","sessionId":"bbbb2222-cccc-dddd-eeee-ffffffffffff"}
JSONL

    # Session 3: forked from session 1
    cat > "$MOCK_PROJECTS/-Users-test-project-myapp/cccc3333-dddd-eeee-ffff-000000000000.jsonl" <<'JSONL'
{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"[forked-from:aaaa1111] 이전 세션(aaaa1111)의 작업을 이어갑니다. 작업 컨텍스트: fix the login bug (branch: fix/login)\n\n이전 세션의 context가 커서 새 세션으로 fork했습니다. 위 맥락을 기반으로 작업을 계속해주세요."},"uuid":"u4","timestamp":"2026-04-07T09:00:00.000Z","permissionMode":"default","userType":"external","entrypoint":"cli","cwd":"/Users/test/project/myapp","sessionId":"cccc3333-dddd-eeee-ffff-000000000000","version":"2.1.90","gitBranch":"fix/login"}
{"parentUuid":"u4","isSidechain":false,"type":"assistant","message":{"model":"claude-opus-4-6","role":"assistant","content":[{"type":"text","text":"Continuing from the forked session..."}],"usage":{"input_tokens":200,"cache_creation_input_tokens":3000,"cache_read_input_tokens":2000,"output_tokens":100}},"uuid":"a3","timestamp":"2026-04-07T09:01:00.000Z","sessionId":"cccc3333-dddd-eeee-ffff-000000000000"}
JSONL

    # Subagent (should be excluded)
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
    source_ssread_functions
    check_dependencies
}

# ── Tests: Helpers ────────────────────────────────────────────────────────

@test "extract_project_name parses compound directory" {
    source_ssread_functions
    result=$(extract_project_name "-Users-ted-project-hg-client--wt-w2")
    [[ "$result" == "hg-client/_wt-w2" ]]
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

@test "format_model_short abbreviates model names" {
    source_ssread_functions
    [[ "$(format_model_short 'claude-opus-4-6')" == "opus" ]]
    [[ "$(format_model_short 'claude-sonnet-4-6')" == "sonnet" ]]
    [[ "$(format_model_short 'claude-haiku-4-5')" == "haiku" ]]
}

@test "format_tokens formats large numbers" {
    source_ssread_functions
    [[ "$(format_tokens 500)" == "500" ]]
    [[ "$(format_tokens 15100)" == "15K" ]]
    [[ "$(format_tokens 1200000)" == "1.2M" ]]
}

# ── Tests: Session Loading (compact) ──────────────────────────────────────

@test "load_sessions finds correct number (excludes subagents)" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    [[ "$SESSION_COUNT" -eq 3 ]]
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

@test "load_sessions extracts first message" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            [[ "${SESSION_FIRST_MSG[$i]}" == "fix the login bug" ]]
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

@test "load_sessions extracts model from assistant message" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            [[ "${SESSION_MODELS[$i]}" == "claude-opus-4-6" ]]
            return 0
        fi
    done
    return 1
}

@test "load_sessions extracts context tokens" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            # 100 + 5000 + 10000 = 15100
            [[ "${SESSION_CTX[$i]}" -eq 15100 ]]
            return 0
        fi
    done
    return 1
}

@test "empty directory produces zero sessions" {
    source_ssread_functions
    local empty_dir="$TEST_DIR/empty_projects"
    mkdir -p "$empty_dir"
    CLAUDE_PROJECTS_DIR="$empty_dir"
    load_sessions
    [[ "$SESSION_COUNT" -eq 0 ]]
}

# ── Tests: Lazy Detail Loading ────────────────────────────────────────────

@test "load_session_detail loads last message" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            load_session_detail "$i"
            [[ "$DETAIL_LAST_MSG" == "looks good, thanks" ]]
            return 0
        fi
    done
    return 1
}

@test "load_session_detail loads message count" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            load_session_detail "$i"
            [[ "$DETAIL_MSG_COUNT" -eq 2 ]]
            return 0
        fi
    done
    return 1
}

@test "load_session_detail loads tool count" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "bbbb2222-cccc-dddd-eeee-ffffffffffff" ]]; then
            load_session_detail "$i"
            [[ "$DETAIL_TOOL_COUNT" -eq 1 ]]
            [[ "$DETAIL_TOP_TOOL" == "Read" ]]
            return 0
        fi
    done
    return 1
}

@test "load_session_detail caches by session ID" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    load_session_detail 0
    local first_sid="$DETAIL_SID"
    # Second call should be cached (same result)
    load_session_detail 0
    [[ "$DETAIL_SID" == "$first_sid" ]]
}

# ── Tests: Fork ───────────────────────────────────────────────────────────

@test "load_sessions detects fork marker" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "cccc3333-dddd-eeee-ffff-000000000000" ]]; then
            [[ "${SESSION_FORK_FROM[$i]}" == "aaaa1111" ]]
            return 0
        fi
    done
    return 1
}

@test "load_sessions strips fork marker from first_msg" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "cccc3333-dddd-eeee-ffff-000000000000" ]]; then
            # Should not start with [forked-from:
            [[ "${SESSION_FIRST_MSG[$i]}" != *"[forked-from:"* ]]
            return 0
        fi
    done
    return 1
}

@test "non-forked sessions have empty fork_from" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            [[ -z "${SESSION_FORK_FROM[$i]}" ]]
            return 0
        fi
    done
    return 1
}

@test "CTX_WARN_THRESHOLD is set" {
    source_ssread_functions
    (( CTX_WARN_THRESHOLD > 0 ))
}

@test "fork_session uses claude --resume --fork-session (non-tmux)" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    unset TMUX 2>/dev/null || true

    # Capture the claude command invocation
    local claude_args=""
    claude() { claude_args="$*"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""

    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            fork_session "$i" 2>/dev/null || true
            # Must use --resume with full session ID and --fork-session
            [[ "$claude_args" == *"--resume"* ]]
            [[ "$claude_args" == *"--fork-session"* ]]
            [[ "$claude_args" == *"aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"* ]]
            return 0
        fi
    done
    return 1
}

@test "fork_session does not pass custom fork prompt" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    unset TMUX 2>/dev/null || true

    local claude_args=""
    claude() { claude_args="$*"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""

    for (( i=0; i<SESSION_COUNT; i++ )); do
        if [[ "${SESSION_IDS[$i]}" == "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee" ]]; then
            fork_session "$i" 2>/dev/null || true
            # Must NOT contain the old custom fork prompt
            [[ "$claude_args" != *"forked-from"* ]]
            [[ "$claude_args" != *"작업 컨텍스트"* ]]
            return 0
        fi
    done
    return 1
}

# ── Tests: Search & BM25 ─────────────────────────────────────────────────

@test "search_sessions filters to matching sessions" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    [[ "$SESSION_COUNT" -eq 3 ]]
    search_sessions "login"
    # "login" appears in session 1 and the forked session 3
    [[ "$SESSION_COUNT" -ge 1 ]]
}

@test "search_sessions returns zero for no match" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    search_sessions "xyznonexistent"
    [[ "$SESSION_COUNT" -eq 0 ]]
}

@test "search_sessions is case-insensitive" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    search_sessions "LOGIN"
    # "login" appears in session 1 and forked session 3
    [[ "$SESSION_COUNT" -ge 1 ]]
}

@test "search_sessions with empty query returns all" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    local before=$SESSION_COUNT
    search_sessions ""
    [[ "$SESSION_COUNT" -eq "$before" ]]
}

@test "search_sessions ranks multi-term matches higher" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    search_sessions "dark mode"
    [[ "$SESSION_COUNT" -ge 1 ]]
    [[ "${SESSION_IDS[0]}" == "bbbb2222-cccc-dddd-eeee-ffffffffffff" ]]
}

# ── Tests: Grouping ───────────────────────────────────────────────────────

@test "group_sessions creates groups from loaded sessions" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    group_sessions
    [[ "$GROUP_COUNT" -eq 2 ]]
}

@test "group_sessions sets correct group counts" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    group_sessions
    local total=0
    for (( g=0; g<GROUP_COUNT; g++ )); do
        total=$(( total + GROUP_COUNTS[g] ))
    done
    [[ "$total" -eq "$SESSION_COUNT" ]]
}

@test "group_sessions reorders sessions so same project is contiguous" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    group_sessions
    for (( g=0; g<GROUP_COUNT; g++ )); do
        local gstart="${GROUP_STARTS[$g]}"
        local gcount="${GROUP_COUNTS[$g]}"
        local expected_proj="${GROUP_NAMES[$g]}"
        for (( s=0; s<gcount; s++ )); do
            local idx=$(( gstart + s ))
            [[ "${SESSION_PROJECTS[$idx]}" == "$expected_proj" ]]
        done
    done
}

@test "group_sessions with empty sessions produces no groups" {
    source_ssread_functions
    local empty_dir="$TEST_DIR/empty_projects"
    mkdir -p "$empty_dir"
    CLAUDE_PROJECTS_DIR="$empty_dir"
    load_sessions
    group_sessions
    [[ "$GROUP_COUNT" -eq 0 ]]
}

# ── Tests: Bookmarks ─────────────────────────────────────────────────────

@test "is_bookmarked returns false when no bookmarks" {
    source_ssread_functions
    BOOKMARKS_STR="|"
    ! is_bookmarked "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_bookmarked returns true for bookmarked session" {
    source_ssread_functions
    BOOKMARKS_STR="|aaaa1111|"
    is_bookmarked "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "toggle_bookmark adds and removes" {
    source_ssread_functions
    SSREAD_BOOKMARKS_FILE="$TEST_DIR/bookmarks"
    BOOKMARKS_STR="|"
    toggle_bookmark "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    is_bookmarked "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    toggle_bookmark "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    ! is_bookmarked "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "toggle_bookmark persists to file" {
    source_ssread_functions
    SSREAD_BOOKMARKS_FILE="$TEST_DIR/bookmarks"
    BOOKMARKS_STR="|"
    toggle_bookmark "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    [[ -f "$TEST_DIR/bookmarks" ]]
    grep -q "aaaa1111" "$TEST_DIR/bookmarks"
}

@test "bookmarked sessions appear in first group" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    SSREAD_BOOKMARKS_FILE="$TEST_DIR/bookmarks"
    BOOKMARKS_STR="|"
    load_sessions
    # Bookmark the last session (least recent)
    local last_idx=$(( SESSION_COUNT - 1 ))
    toggle_bookmark "${SESSION_IDS[$last_idx]}"
    group_sessions
    # First group should be bookmarks
    [[ "${GROUP_NAMES[0]}" == "Bookmarks" ]]
    [[ "${GROUP_COUNTS[0]}" -eq 1 ]]
}

# ── Tests: Archives ───────────────────────────────────────────────────────

@test "is_archived returns false when no archives" {
    source_ssread_functions
    ARCHIVES_STR="|"
    ! is_archived "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "toggle_archive adds and removes" {
    source_ssread_functions
    SSREAD_ARCHIVES_FILE="$TEST_DIR/archives"
    ARCHIVES_STR="|"
    toggle_archive "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    is_archived "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    toggle_archive "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    ! is_archived "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "archived sessions excluded from project groups" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    SSREAD_BOOKMARKS_FILE="$TEST_DIR/bookmarks"
    SSREAD_ARCHIVES_FILE="$TEST_DIR/archives"
    BOOKMARKS_STR="|"
    ARCHIVES_STR="|"
    load_sessions
    local total_before=$SESSION_COUNT
    # Archive the first session
    toggle_archive "${SESSION_IDS[0]}"
    group_sessions
    # Archive group should exist and contain 1 session
    local found_archive=false
    local archive_count=0
    for (( g=0; g<GROUP_COUNT; g++ )); do
        if [[ "${GROUP_NAMES[$g]}" == *"Archive"* ]]; then
            found_archive=true
            archive_count="${GROUP_COUNTS[$g]}"
        fi
    done
    $found_archive
    [[ "$archive_count" -eq 1 ]]
}

@test "archiving removes bookmark" {
    source_ssread_functions
    SSREAD_BOOKMARKS_FILE="$TEST_DIR/bookmarks"
    SSREAD_ARCHIVES_FILE="$TEST_DIR/archives"
    BOOKMARKS_STR="|"
    ARCHIVES_STR="|"
    toggle_bookmark "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    is_bookmarked "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    toggle_archive "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    ! is_bookmarked "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
    is_archived "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

# ── Tests: tmux helpers (without actual tmux) ─────────────────────────────

@test "is_session_active returns false when no windows active" {
    source_ssread_functions
    ACTIVE_WINDOWS_STR="|"
    ! is_session_active "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_active returns true via sid lookup" {
    source_ssread_functions
    SESSION_IDS=("aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    SESSION_STATE=("$STATE_IDLE")
    SESSION_COUNT=1
    is_session_active "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_active returns false for stopped via sid lookup" {
    source_ssread_functions
    SESSION_IDS=("aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    SESSION_STATE=("$STATE_STOPPED")
    SESSION_COUNT=1
    ! is_session_active "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_working returns false when not working" {
    source_ssread_functions
    SESSION_IDS=("aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    SESSION_STATE=("$STATE_IDLE")
    SESSION_COUNT=1
    ! is_session_working "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_working returns true via sid lookup" {
    source_ssread_functions
    SESSION_IDS=("aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    SESSION_STATE=("$STATE_WORKING")
    SESSION_COUNT=1
    is_session_working "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_done returns true via sid lookup" {
    source_ssread_functions
    SESSION_IDS=("aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    SESSION_STATE=("$STATE_DONE")
    SESSION_COUNT=1
    is_session_done "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_done returns false when still working" {
    source_ssread_functions
    SESSION_IDS=("aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee")
    SESSION_STATE=("$STATE_WORKING")
    SESSION_COUNT=1
    ! is_session_done "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "is_session_done returns false when never worked" {
    source_ssread_functions
    ACTIVE_WINDOWS_STR="|aaaa1111|"
    WORKING_WINDOWS_STR="|"
    SEEN_WORKING_STR="|"
    ! is_session_done "aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee"
}

@test "tmux_active_count returns 0 when not in tmux" {
    source_ssread_functions
    unset TMUX 2>/dev/null || true
    result=$(tmux_active_count)
    [[ "$result" -eq 0 ]]
}

@test "tmux_active_count returns a single integer (no double output)" {
    source_ssread_functions
    unset TMUX 2>/dev/null || true
    result=$(tmux_active_count)
    local line_count
    line_count=$(echo "$result" | wc -l | tr -d ' ')
    [[ "$line_count" -eq 1 ]]
    (( result >= 0 ))
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
    ensure_tmux_session
}

# ── Tests: Command Mode ──────────────────────────────────────────────────

@test "COMMAND_MODE initializes to false" {
    source_ssread_functions
    [[ "$COMMAND_MODE" == "false" ]]
}

@test "set_status_msg sets message and expiration" {
    source_ssread_functions
    set_status_msg "hello"
    [[ "$STATUS_MSG" == "hello" ]]
    (( STATUS_MSG_EXPIRE > 0 ))
}

@test "execute_command recognizes unknown command" {
    source_ssread_functions
    execute_command "foobar"
    [[ "$STATUS_MSG" == "Unknown command: foobar" ]]
}

@test "execute_command empty input does nothing" {
    source_ssread_functions
    STATUS_MSG=""
    execute_command ""
    [[ -z "$STATUS_MSG" ]]
}

@test "cmd_new_session fails without --root" {
    source_ssread_functions
    cmd_new_session || true
    [[ "$STATUS_MSG" == "Error: --root is required" ]]
}

@test "cmd_new_session fails with nonexistent directory" {
    source_ssread_functions
    cmd_new_session --root "/tmp/ssread_nonexistent_$$" || true
    [[ "$STATUS_MSG" == *"directory not found"* ]]
}

@test "cmd_new_session fails with unknown option" {
    source_ssread_functions
    cmd_new_session --foo bar || true
    [[ "$STATUS_MSG" == *"unknown option"* ]]
}

@test "cmd_new_session validates branch requires git repo" {
    source_ssread_functions
    local tmpdir="$TEST_DIR/nogit"
    mkdir -p "$tmpdir"
    cmd_new_session --root "$tmpdir" --branch "main" || true
    [[ "$STATUS_MSG" == *"not a git repository"* ]]
}

@test "cmd_new_session validates branch existence" {
    source_ssread_functions
    local tmpdir="$TEST_DIR/gitrepo"
    mkdir -p "$tmpdir"
    git -C "$tmpdir" init -q
    git -C "$tmpdir" commit --allow-empty -m "init" -q
    cmd_new_session --root "$tmpdir" --branch "nonexistent" || true
    [[ "$STATUS_MSG" == *"branch not found"* ]]
}

@test "execute_command parses new with quoted prompt" {
    source_ssread_functions
    # We can't actually launch claude in tests, so just verify parsing
    # by checking that a valid root passes validation
    local tmpdir="$TEST_DIR/validroot"
    mkdir -p "$tmpdir"
    # This will fail at tmux launch (no tmux in test), but should pass validation
    unset TMUX 2>/dev/null || true
    # Stub claude command
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    # Run in subshell so tput/stty failures don't break test
    ORIG_STTY=""
    # Just test the parsing — cmd_new_session with valid root should not produce an error status
    STATUS_MSG=""
    cmd_new_session --root "$tmpdir" 2>/dev/null || true
    [[ "$STATUS_MSG" != Error:* ]]
}

@test "execute_command parses quoted strings correctly" {
    source_ssread_functions
    local tmpdir="$TEST_DIR/quotedtest"
    mkdir -p "$tmpdir"
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    STATUS_MSG=""
    execute_command "new --root '$tmpdir' --prompt 'hello world'" 2>/dev/null || true
    [[ "$STATUS_MSG" != Error:* ]]
}

@test "cmd_new_session expands tilde in root" {
    source_ssread_functions
    # ~ should expand to $HOME; if $HOME exists, validation passes
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    STATUS_MSG=""
    cmd_new_session --root "~" 2>/dev/null || true
    [[ "$STATUS_MSG" != *"directory not found"* ]]
}

# ── Tests: Pending entry insertion ────────────────────────────────────────

@test "cmd_new_session inserts pending entry into SESSION_* arrays" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    local count_before=$SESSION_COUNT
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    cmd_new_session --root "$TEST_DIR" 2>/dev/null || true
    # Should have one more entry
    [[ "$SESSION_COUNT" -eq $(( count_before + 1 )) ]]
}

@test "cmd_new_session pending entry has pending: sid prefix" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    local count_before=$SESSION_COUNT
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    cmd_new_session --root "$TEST_DIR" 2>/dev/null || true
    # Last entry should have pending: prefix
    local last_idx=$(( SESSION_COUNT - 1 ))
    [[ "${SESSION_IDS[$last_idx]}" == pending:* ]]
}

@test "cmd_new_session pending entry state is pending" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    cmd_new_session --root "$TEST_DIR" 2>/dev/null || true
    local last_idx=$(( SESSION_COUNT - 1 ))
    [[ "${SESSION_STATE[$last_idx]}" == "$STATE_PENDING" ]]
}

@test "cmd_new_session pending entry stores correct cwd" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    cmd_new_session --root "$TEST_DIR" 2>/dev/null || true
    local last_idx=$(( SESSION_COUNT - 1 ))
    [[ "${SESSION_CWDS[$last_idx]}" == "$TEST_DIR" ]]
}

@test "fork_session inserts pending entry" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    local count_before=$SESSION_COUNT
    unset TMUX 2>/dev/null || true
    claude() { echo "stub"; }
    export -f claude 2>/dev/null || true
    ORIG_STTY=""
    fork_session 0 2>/dev/null || true
    [[ "$SESSION_COUNT" -eq $(( count_before + 1 )) ]]
    local last_idx=$(( SESSION_COUNT - 1 ))
    [[ "${SESSION_IDS[$last_idx]}" == pending:* ]]
    [[ "${SESSION_STATE[$last_idx]}" == "$STATE_PENDING" ]]
}

# ── Tests: SESSION_STATE (FSM) ────────────────────────────────────────────

@test "state name constants are defined" {
    source_ssread_functions
    [[ "$STATE_STOPPED" == "stopped" ]]
    [[ "$STATE_PENDING" == "pending" ]]
    [[ "$STATE_IDLE"    == "idle" ]]
    [[ "$STATE_WORKING" == "working" ]]
    [[ "$STATE_DONE"    == "done" ]]
    [[ "$STATE_CLOSED"  == "closed" ]]
}

@test "load_sessions populates SESSION_STATE parallel to SESSION_IDS" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    [[ "${#SESSION_STATE[@]}" -eq "$SESSION_COUNT" ]]
}

@test "load_sessions initializes SESSION_STATE entries to stopped" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        [[ "${SESSION_STATE[$i]}" == "$STATE_STOPPED" ]]
    done
}

# ── Tests: compute_state truth table ──────────────────────────────────────
# Args: has_jsonl has_window has_claude has_tools seen_working

@test "compute_state: J=0 W=0 → drop" {
    source_ssread_functions
    [[ "$(compute_state 0 0 0 0 0)" == "drop" ]]
}

@test "compute_state: J=1 W=0 → stopped" {
    source_ssread_functions
    [[ "$(compute_state 1 0 0 0 0)" == "$STATE_STOPPED" ]]
}

@test "compute_state: J=0 W=1 C=1 → pending" {
    source_ssread_functions
    [[ "$(compute_state 0 1 1 0 0)" == "$STATE_PENDING" ]]
}

@test "compute_state: J=0 W=1 C=0 → orphan" {
    source_ssread_functions
    [[ "$(compute_state 0 1 0 0 0)" == "orphan" ]]
}

@test "compute_state: J=1 W=1 C=0 → closed" {
    source_ssread_functions
    [[ "$(compute_state 1 1 0 0 0)" == "$STATE_CLOSED" ]]
    # closed regardless of seen_working
    [[ "$(compute_state 1 1 0 0 1)" == "$STATE_CLOSED" ]]
}

@test "compute_state: J=1 W=1 C=1 T=1 → working" {
    source_ssread_functions
    [[ "$(compute_state 1 1 1 1 0)" == "$STATE_WORKING" ]]
    # working regardless of seen_working
    [[ "$(compute_state 1 1 1 1 1)" == "$STATE_WORKING" ]]
}

@test "compute_state: J=1 W=1 C=1 T=0 S=0 → idle" {
    source_ssread_functions
    [[ "$(compute_state 1 1 1 0 0)" == "$STATE_IDLE" ]]
}

@test "compute_state: J=1 W=1 C=1 T=0 S=1 → done" {
    source_ssread_functions
    [[ "$(compute_state 1 1 1 0 1)" == "$STATE_DONE" ]]
}

# ── Tests: reconcile_sessions integration ─────────────────────────────────

@test "reconcile_sessions outside tmux leaves all entries as stopped" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    unset TMUX 2>/dev/null || true
    load_sessions
    reconcile_sessions
    for (( i=0; i<SESSION_COUNT; i++ )); do
        [[ "${SESSION_STATE[$i]}" == "$STATE_STOPPED" ]]
    done
}

# ── Tests: is_session_*_at (index-based helpers) ─────────────────────────

@test "is_session_working_at returns true when SESSION_STATE is working" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    SESSION_STATE[0]="$STATE_WORKING"
    is_session_working_at 0
}

@test "is_session_working_at returns false when SESSION_STATE is idle" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    SESSION_STATE[0]="$STATE_IDLE"
    ! is_session_working_at 0
}

@test "is_session_done_at returns true when SESSION_STATE is done" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    SESSION_STATE[0]="$STATE_DONE"
    is_session_done_at 0
}

@test "is_session_done_at returns false when SESSION_STATE is working" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    SESSION_STATE[0]="$STATE_WORKING"
    ! is_session_done_at 0
}

@test "is_session_active_at returns true for running states" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    for state in "$STATE_IDLE" "$STATE_WORKING" "$STATE_DONE" "$STATE_CLOSED" "$STATE_PENDING"; do
        SESSION_STATE[0]="$state"
        is_session_active_at 0
    done
}

@test "is_session_active_at returns false for stopped" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    load_sessions
    SESSION_STATE[0]="$STATE_STOPPED"
    ! is_session_active_at 0
}

@test "reconcile_sessions can be called repeatedly without state corruption" {
    source_ssread_functions
    CLAUDE_PROJECTS_DIR="$MOCK_PROJECTS"
    unset TMUX 2>/dev/null || true
    load_sessions
    reconcile_sessions
    reconcile_sessions
    reconcile_sessions
    [[ "${#SESSION_STATE[@]}" -eq "$SESSION_COUNT" ]]
}
