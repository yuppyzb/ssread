# ssread

Claude Code session reader & manager TUI. Browse, search, and manage sessions from your terminal.

```
┌─ Sessions (42)  ▸ 3 running ─────────┬─ Detail ─────────────────────────────┐
│ ▼ hg-client (3)                       │  Session                             │
│ ⠹ 2b66aca3  2h ago  opus 15K         │  2b66aca3-bd00-445a-8437...          │
│   c2c8604d  1d ago  sonnet 5K         │  ⠹ working                           │
│ ● 5c2ceee2  3h ago  opus 80K  ⚠      │                                      │
│ ▼ webapp (2)                          │  Project   hg-client                 │
│ ⠹ new       now                       │  Branch    feature/HGNN-13198-zams  │
│   a1b2c3d4  5d ago  haiku 2K          │  CWD       /Users/ted/project/hg-.. │
│ ▶ Archive (1)                         │  Model     claude-opus-4-6          │
│                                       │  Context   15K tokens                │
│                                       │  Started   2026-03-30 17:23          │
│                                       │  Messages  24 user messages          │
│                                       │                                      │
│                                       │  ── First Message ────────────────   │
│                                       │  sellingaptcard.tsx:253 line의       │
│                                       │  h1171 이벤트가 실행되지 않는 이유   │
└───────────────────────────────────────┴──────────────────────────────────────┘
 ●2 done  │ j/k Nav  Enter: Open/Fold  b: Bookmark  a: Archive  `: List  q: Quit
```

## Features

- **Session browser** -- Left panel lists all Claude Code sessions grouped by project, sorted by recency
- **Detail view** -- Right panel shows session metadata (ID, project, branch, CWD, model, context, messages)
- **3-pane layout** -- Fixed tmux layout: list (left), detail (top-right), session (bottom-right)
- **Session lifecycle** -- Each session has a state: `stopped`, `pending`, `idle`, `working`, `done`, `closed`
- **Working indicator** -- Braille spinner when claude is executing tools
- **Done notification** -- `●` marker and status bar count when a session finishes work
- **Pending sessions** -- New sessions appear in the list immediately, before jsonl is created
- **Search** -- BM25-scored full-text search across all user messages (`/`)
- **Bookmarks** -- Pin sessions to the top (`b`)
- **Archive** -- Hide old sessions in a collapsible Archive group (`a`)
- **Fork** -- Branch a session into a new one (`f`)
- **New session** -- Launch a new claude session from command mode (`:new --root <path>`)
- **Context warning** -- `⚠` marker when context exceeds 80K tokens
- **Fork indicator** -- `⑂` marker showing the parent session

## Requirements

- **bash** 3.2+ (macOS default)
- **jq** -- JSON parsing
- **tmux** -- Session multiplexing
- **bats-core** -- Test runner (optional, for `--test`)

```bash
brew install jq tmux bats-core
```

## Install

```bash
git clone https://github.com/yuppyzb/ssread.git ~/tools/ssread
bash ~/tools/ssread/install.sh
source ~/.zshrc
```

The install script adds `~/tools/ssread` to your `PATH`.

## Usage

```bash
ssread          # Launch TUI (auto-creates tmux session)
ssread --test   # Run test suite
```

## Session Lifecycle

Each session in the list has one of six states, determined automatically by scanning tmux windows and process trees every 2 seconds:

| State | Indicator | Meaning |
|-------|-----------|---------|
| `stopped` | (none) | jsonl on disk, no tmux window |
| `pending` | `⠹` gray spinner | Launched but jsonl not yet created |
| `idle` | green text | claude running, no tool execution |
| `working` | `⠹` cyan spinner | claude executing tools |
| `done` | `●` yellow dot | Was working, now idle (review needed) |
| `closed` | `◌` gray | tmux window exists but claude exited |

The `done` indicator clears when you attach to the session (Enter).

Status bar shows aggregate counts: `⋯N pending  ●N done`

## Keybindings

### List navigation

| Key | Action |
|-----|--------|
| `j` / `↓` | Move selection down |
| `k` / `↑` | Move selection up |
| `g` | Jump to top |
| `G` | Jump to bottom |
| `Enter` | Open session / fold-unfold group header |
| `Esc` | Clear search or detach session pane |

### Session management

| Key | Action |
|-----|--------|
| `f` | Fork selected session |
| `b` | Toggle bookmark (pins to top) |
| `a` | Toggle archive (hides in Archive group) |
| `r` | Refresh session list |
| `Tab` | Focus attached session pane |
| `` ` `` | Return to list pane (works without prefix) |

### Modes

| Key | Action |
|-----|--------|
| `/` | Enter search mode |
| `:` | Enter command mode |
| `q` | Quit ssread (running sessions stay alive) |
| `Q` | Quit and kill all running session windows |

### Command mode (`:`)

```
:new --root <path> [--prompt <text>] [--branch <name>]
```

Launch a new claude session in the given directory. The session appears as `pending` in the list immediately and promotes to a real session once claude creates its jsonl file.

### In an attached session pane

| Key | Action |
|-----|--------|
| `` ` `` | Return focus to ssread list |
| Standard tmux keys | `Ctrl-b` prefix for tmux operations |

## Data source

Reads `.jsonl` session files from `~/.claude/projects/`. Subagent files (`*/subagents/*`) are excluded.

Bookmarks and archives are stored in `~/.config/ssread/`.

## Test

```bash
ssread --test
# or
bats tests/test_ssread.sh
```

## License

MIT
