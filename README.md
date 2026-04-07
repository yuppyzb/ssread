# ssread

Claude Code session reader & manager TUI. Browse, search, and resume sessions from your terminal.

```
┌─ Sessions (42)  ▸ 2 running ─────────┬─ Detail ─────────────────────────────┐
│ ▶ 2b66aca3  cli  2h ago  hg-client ▸ │ Session: 2b66aca3-bd00-445a-8437... │
│   c2c8604d  cli  1d ago  webapp       │ Project: hg-client                  │
│   5c2ceee2  cli  5d ago  apt3d        │ Branch:  feature/HGNN-13198-zams   │
│                                       │ CWD:     /Users/ted/project/hg-cl..│
│                                       │ Started: 2026-03-30 17:23          │
│                                       │ Messages: 24 user messages         │
│                                       │                                    │
│                                       │ ── First Message ────────────────  │
│                                       │ sellingaptcard.tsx:253 line의      │
│                                       │ h1171 이벤트가 실행되지 않는 이유  │
└───────────────────────────────────────┴────────────────────────────────────┘
 ↑↓ Navigate  Enter: Open  Tab: Next window  q: Quit  /: Search  r: Refresh
```

## Features

- **Session browser** — Left panel lists all Claude Code sessions sorted by recency
- **Detail view** — Right panel shows session ID, project, branch, CWD, messages
- **Search** — Filter sessions by ID, message content, directory, branch
- **tmux integration** — Each session opens in its own tmux window for parallel work
- **Running indicator** — Active sessions marked with `▸` in green

## Requirements

- **jq** — JSON parsing
- **tmux** — Session multiplexing
- **bats-core** — Test runner (optional, for `--test`)

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

### Keybindings

**In ssread list:**

| Key | Action |
|-----|--------|
| `↑` / `k` | Move selection up |
| `↓` / `j` | Move selection down |
| `Enter` | Open session (new tmux window) or switch to running session |
| `Tab` | Switch to next tmux window |
| `/` | Search sessions |
| `Esc` | Clear search |
| `r` | Refresh session list |
| `g` / `G` | Jump to top / bottom |
| `q` | Quit ssread (running sessions stay alive) |
| `Q` | Quit and close all running sessions |

**In a claude session (tmux window):**

| Key | Action |
|-----|--------|
| `Ctrl-b 0` | Return to ssread list (window 0) |
| `Ctrl-b n` / `Ctrl-b p` | Next / previous window |
| `Ctrl-b w` | tmux window picker |

## Data source

Reads `.jsonl` session files from `~/.claude/projects/`. Subagent files are excluded.

## Test

```bash
ssread --test
# or
bats tests/test_ssread.sh
```

## License

MIT
