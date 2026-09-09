#!/usr/bin/env bash
# Claude Code status line (two lines). Reads JSON on stdin. Needs: bash, jq, git.
#   line 1: model · effort · repo · branch
#   line 2: context / 5h limit / 7d limit gauges with reset countdown
# Optional: STATUSLINE_ASCII=1 uses plain ASCII (no Nerd Font).
#           STATUSLINE_BG=#rrggbb paints the padding line in your terminal background color
#           (auto-detected from the active Ghostty theme when unset).

input=$(cat)
j() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

RESET=$'\e[0m'; DIM=$'\e[2m'; BOLD=$'\e[1m'
C_MODEL=$'\e[38;5;141m'; C_EFF=$'\e[38;5;183m'; C_REPO=$'\e[38;5;75m'; C_BRANCH=$'\e[38;5;213m'
C_OK=$'\e[38;5;114m'; C_WARN=$'\e[38;5;221m'; C_BAD=$'\e[38;5;203m'
C_MUTED=$'\e[38;5;245m'; C_TRACK=$'\e[38;5;238m'

if [[ -n $STATUSLINE_ASCII ]]; then
  ON="#"; OFF="."; SEP="  |  "; I_REPO=""; I_DIRTY="*"
else
  ON="▰"; OFF="▱"; SEP="  │  "; I_REPO="󰉋 "; I_DIRTY="●"
fi
SEP="${C_TRACK}${SEP}${RESET}"

tone() { local p=$1; if (( p >= 90 )); then printf '%s' "$C_BAD"; elif (( p >= 70 )); then printf '%s' "$C_WARN"; else printf '%s' "$C_OK"; fi; }

# gauge <label> <pct> <width> [suffix] -> "label ▰▰▱▱▱ 42% suffix"
gauge() {
  local label=$1 pct=${2%.*} width=$3 suffix=$4 i on="" off=""
  (( pct > 100 )) && pct=100; (( pct < 0 )) && pct=0
  local filled=$(( (pct * width + 50) / 100 ))
  for ((i=0;i<filled;i++)); do on+=$ON; done
  for ((i=filled;i<width;i++)); do off+=$OFF; done
  printf '%s%s%s %s%s%s%s %s%d%%%s%s' "$C_MUTED" "$label" "$RESET" \
    "$(tone "$pct")" "$on" "$C_TRACK" "$off" "$(tone "$pct")" "$pct" "$RESET" "$suffix"
}

# until <epoch> -> "2h05m" / "3d" countdown
until_txt() {
  local s=$(( $1 - $(date +%s) )); (( s < 0 )) && s=0
  local d=$(( s / 86400 )) h=$(( s % 86400 / 3600 )) m=$(( s % 3600 / 60 ))
  if (( d > 0 )); then printf '%dd%02dh' "$d" "$h"; else printf '%dh%02dm' "$h" "$m"; fi
}

# ---------- line 1: identity ----------
model=$(j '.model.display_name'); [[ -z $model ]] && model=$(j '.model.id'); [[ -z $model ]] && model="Claude"
effort=$(j '.effort.level')
cwd=$(j '.workspace.current_dir'); [[ -z $cwd ]] && cwd=$(j '.cwd'); [[ -z $cwd ]] && cwd=$PWD

line1="${BOLD}${C_MODEL}${model}${RESET}"
[[ -n $effort ]] && line1+=" ${C_EFF}$(tr a-z A-Z <<<"$effort")${RESET}"
line1+="${SEP}${C_REPO}${I_REPO}$(basename "$cwd")${RESET}"

if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null) || branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null) || branch="?"
  dirty=""; [[ -n $(git -C "$cwd" status --porcelain 2>/dev/null) ]] && dirty="${C_WARN}${I_DIRTY}${RESET}"
  line1+=" ${C_MUTED}(${RESET}${C_BRANCH}${branch}${RESET}${dirty}${C_MUTED})${RESET}"
fi

# ---------- line 2: gauges ----------
parts=()

pct=$(j '.context_window.used_percentage')
if [[ -n $pct ]]; then
  size=$(j '.context_window.context_window_size'); sfx=""
  [[ -n $size ]] && sfx="${C_MUTED}${DIM}/$(( size / 1000 ))k${RESET}"
  parts+=("$(gauge ctx "$pct" 10 "$sfx")")
fi

for pair in "5h:five_hour" "7d:seven_day"; do
  label=${pair%%:*}; key=${pair##*:}
  p=$(j ".rate_limits.${key}.used_percentage"); [[ -z $p ]] && continue
  at=$(j ".rate_limits.${key}.resets_at"); sfx=""
  [[ -n $at ]] && sfx=" ${C_MUTED}${DIM}$(until_txt "${at%.*}")${RESET}"
  parts+=("$(gauge "$label" "$p" 6 "$sfx")")
done

line2=""
for p in "${parts[@]}"; do [[ -n $line2 ]] && line2+="$SEP"; line2+="$p"; done

# third line: a dot painted in the terminal background color, so the host keeps
# a padding line under the gauges. Set STATUSLINE_BG=#rrggbb to match your theme.
ghostty_bg() {
  local cfg theme bgc="" thm=""
  for cfg in "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "$HOME/.config/ghostty/config"; do
    [[ -f $cfg ]] || continue
    while IFS= read -r line; do
      line=$(tr -d ' ' <<<"$line")
      case $line in
        background=*) bgc=${line#*=} ;;
        theme=*)      thm=${line#*=} ;;
      esac
    done <"$cfg"
  done
  # "theme = light:x,dark:y" -> use the dark entry
  [[ $thm == *dark:* ]] && { thm=${thm#*dark:}; thm=${thm%%,*}; }
  if [[ -n $thm && -z $bgc ]]; then
    for f in "$HOME/.config/ghostty/themes/$thm" "/Applications/Ghostty.app/Contents/Resources/ghostty/themes/$thm"; do
      [[ -f $f ]] || continue
      bgc=$(sed -n 's/^background *= *//p' "$f" | head -1 | tr -d ' ')
      break
    done
  fi
  printf '%s' "$bgc"
}
bg=$STATUSLINE_BG
[[ -z $bg && $TERM_PROGRAM == ghostty ]] && bg=$(ghostty_bg)
bg=${bg:-#0c0b14}; bg=${bg#\#}
printf '%s\n%s\n\e[38;2;%d;%d;%dm\xc2\xb7%s' "$line1" "$line2" "0x${bg:0:2}" "0x${bg:2:2}" "0x${bg:4:2}" "$RESET"
