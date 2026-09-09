# clowk-claude-statusline

A two-line status line for [Claude Code](https://claude.com/claude-code), in pure bash.

```
Fable 5.1 HIGH  │  󰉋 clowk-js (main●)
ctx ▰▰▰▰▱▱▱▱▱▱ 42%/200k  │  5h ▰▰▱▱▱▱ 31% 2h05m  │  7d ▰▰▰▰▰▱ 76% 3d01h
```

- **Line 1:** model · effort level · `repo (branch)` (`●` = dirty tree)
- **Line 2:** gauges for context usage, 5-hour limit and 7-day limit. Each limit shows the time until reset.
- Gauges turn amber at 70% and red at 90%.

## Requirements

- `bash` 4+, `jq`, `git`
- A [Nerd Font](https://www.nerdfonts.com/) for the folder and branch icons (optional, see below)

## Install

```sh
git clone https://github.com/thadeu/clowk-claude-statusline ~/.claude/statusline
```

Add to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline/statusline.sh",
  "padding": 0
}
```

## Options

| Variable | Effect |
|---|---|
| `STATUSLINE_ASCII=1` | Plain ASCII bars and no icons, for terminals without a Nerd Font |
| `STATUSLINE_BG=#rrggbb` | Your terminal background color, used to hide the padding line below the gauges. Auto-detected from the active Ghostty theme; default `#0c0b14` |

Set it in the command, for example `"command": "STATUSLINE_ASCII=1 ~/.claude/statusline/statusline.sh"`.

## Test

```sh
./statusline.sh < test/sample.json
```

## License

MIT
