#!/usr/bin/env bash
# Claude Code status line (settings.json statusLine.command).
#   Opus 5.5 · medium · ctx 79.9k    reset 39m · 5h 15% · 7d 15% · fable 5%
#   ~/ghq/github.com/hsincode · main                                 my-task
# Catppuccin truecolour: the flavour (latte / mocha) and the accent follow the
# current dwm theme (~/.local/state/dwm/theme, written by dwm on every switch;
# the accent comes from ~/.config/dwm/themes/<theme>.env). Without dwm, set
# CLAUDE_STATUSLINE_FLAVOUR (latte / mocha) and CLAUDE_STATUSLINE_ACCENT
# (a Catppuccin colour name); the default is mocha / peach. Everything else
# comes from the JSON on stdin, except the Fable weekly limit, which is fetched
# in the background and cached (see below). On the Ultra plan
# (~/.claude.json .oauthAccount.planDisplayName) the 5-hour limit and its reset
# countdown are left out.

IFS=$'\x1f' read -r model effort tokens h5 h5reset d7 dir sid sname < <(jq -r '[
	.model.display_name // "?",
	.effort.level // "",
	(.context_window.total_input_tokens // ""),
	(.rate_limits.five_hour.used_percentage // ""),
	(.rate_limits.five_hour.resets_at // ""),
	(.rate_limits.seven_day.used_percentage // ""),
	.workspace.current_dir // .cwd // "",
	.session_id // "",
	.session_name // ""
] | map(tostring) | join("\u001f")')

# --- palette ----------------------------------------------------------------
theme=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dwm/theme" 2>/dev/null)
ACCENT=peach
envf=$HOME/.config/dwm/themes/$theme.env
[ -r "$envf" ] && ACCENT=$(sed -n "s/^ACCENT='\(.*\)'/\1/p" "$envf")
FLAVOUR=${CLAUDE_STATUSLINE_FLAVOUR:-${theme##*-}}
ACCENT=${CLAUDE_STATUSLINE_ACCENT:-$ACCENT}
declare -A C
if [ "$FLAVOUR" = latte ]; then
	C=([rosewater]=dc8a78 [flamingo]=dd7878 [pink]=ea76cb [mauve]=8839ef [red]=d20f39
	   [maroon]=e64553 [peach]=fe640b [yellow]=df8e1d [green]=40a02b [teal]=179299
	   [sky]=04a5e5 [sapphire]=209fb5 [blue]=1e66f5 [lavender]=7287fd [text]=4c4f69
	   [subtext1]=5c5f77 [subtext0]=6c6f85 [overlay2]=7c7f93 [overlay1]=8c8fa1
	   [overlay0]=9ca0b0 [surface2]=acb0be)
else
	C=([rosewater]=f5e0dc [flamingo]=f2cdcd [pink]=f5c2e7 [mauve]=cba6f7 [red]=f38ba8
	   [maroon]=eba0ac [peach]=fab387 [yellow]=f9e2af [green]=a6e3a1 [teal]=94e2d5
	   [sky]=89dceb [sapphire]=74c7ec [blue]=89b4fa [lavender]=b4befe [text]=cdd6f4
	   [subtext1]=bac2de [subtext0]=a6adc8 [overlay2]=9399b2 [overlay1]=7f849c
	   [overlay0]=6c7086 [surface2]=585b70)
fi
fg() { # fg <name> [bold]: truecolour escape for a palette colour
	local h=${C[$1]:-${C[text]}}
	printf '\e[%s38;2;%d;%d;%dm' "${2:+1;}" $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2}))
}
R=$'\e[0m'
TEXT=$(fg text) LBL=$(fg overlay1) SEP="$(fg surface2) · $R"

# level <percent>: green, yellow from 50 %, peach from 70 %, red from 85 %
level() {
	local p=${1%.*}
	if ((p >= 85)); then fg red bold; elif ((p >= 70)); then fg peach
	elif ((p >= 50)); then fg yellow; else fg green; fi
}
pct() { [ -n "$1" ] && printf '%s%.0f%%%s' "$(level "$1")" "$1" "$R"; }

# effort in a cool-to-warm ramp, so a raised effort stands out
case $effort in
	low) EFF=$(fg teal) ;; medium) EFF=$(fg sapphire) ;; high) EFF=$(fg mauve) ;;
	xhigh) EFF=$(fg pink) ;; max) EFF=$(fg maroon bold) ;; *) EFF=$(fg subtext1) ;;
esac

# --- layout -----------------------------------------------------------------
# Segments are kept as (text, visible width) so the right block can be
# aligned without counting escape codes.
left= lw=0 right= rw=0
add() { # add <side> <coloured text> <plain text>
	local sep=$SEP sw=3
	if [ "$1" = l ]; then
		[ -z "$left" ] && sep= sw=0
		left+=$sep$2 lw=$((lw + sw + ${#3}))
	else
		[ -z "$right" ] && sep= sw=0
		right+=$sep$2 rw=$((rw + sw + ${#3}))
	fi
}

add l "$(fg "$ACCENT" bold)$model$R" "$model"
[ -n "$effort" ] && add l "$EFF$effort$R" "$effort"
if [ -n "$tokens" ] && [ "$tokens" != 0 ]; then
	k=$(awk -v t="$tokens" 'BEGIN { if (t >= 1000) printf "%.1fk", t / 1000; else printf "%d", t }')
	add l "${LBL}ctx$R $TEXT$k$R" "ctx $k"
else
	add l "${LBL}ctx$R ${LBL}—$R" "ctx —"
fi

# Ultra has no 5-hour limit worth watching: drop it and its reset countdown
plan=$(jq -r '.oauthAccount.planDisplayName // ""' "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json" 2>/dev/null)
[ "$plan" = Ultra ] && h5= h5reset=

if [ -n "$h5reset" ]; then
	s=$(( ${h5reset%.*} - $(date +%s) ))
	((s < 0)) && s=0
	h=$((s / 3600)) m=$(((s % 3600 + 59) / 60))
	((m == 60)) && h=$((h + 1)) m=0
	if ((h > 0)); then t=$(printf '%dh%02dm' "$h" "$m"); else t=${m}m; fi
	add r "${LBL}reset$R $(fg sky)$t$R" "reset $t"
fi
[ -n "$h5" ] && add r "${LBL}5h$R $(pct "$h5")" "5h $(printf '%.0f%%' "$h5")"
[ -n "$d7" ] && add r "${LBL}7d$R $(pct "$d7")" "7d $(printf '%.0f%%' "$d7")"

# Fable weekly limit: not in the stdin JSON, so it comes from the OAuth usage
# endpoint (limits[] kind weekly_scoped, scope.model.display_name "Fable").
# Fetched in the background at most every 5 minutes into a cache; the line
# always shows the cached value, so it never waits on the network.
fcache=${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline/fable-weekly
mkdir -p "${fcache%/*}"
if [ ! -e "$fcache" ] || (($(date +%s) - $(stat -c %Y "$fcache") >= 300)); then
	touch "$fcache" # claim this round so parallel runs don't fetch too
	(
		tok=$(jq -r '.claudeAiOauth.accessToken // empty' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" 2>/dev/null)
		[ -n "$tok" ] || exit
		v=$(curl -sf -m 10 https://api.anthropic.com/api/oauth/usage \
			-H "Authorization: Bearer $tok" -H 'anthropic-beta: oauth-2025-04-20' |
			jq -r 'first(.limits[]? | select(.kind == "weekly_scoped" and .scope.model.display_name == "Fable") | .percent) // empty') || exit
		[ -n "$v" ] && printf '%s\n' "$v" >"$fcache.tmp" && mv "$fcache.tmp" "$fcache"
	) >/dev/null 2>&1 &
	disown
fi
fable=$(cat "$fcache" 2>/dev/null)
[ -n "$fable" ] && add r "${LBL}fable$R $(pct "$fable")" "fable $(printf '%.0f%%' "$fable")"

# Claude Code indents the status line by 2 and truncates 2 before the right
# edge (measured: COLUMNS=146 shows 142 columns of output)
cols=${COLUMNS:-0} margin=4
if [ -z "$right" ]; then
	printf '%s\n' "$left"
elif ((cols - margin - lw - rw >= 4)); then
	printf '%s%*s%s\n' "$left" $((cols - margin - lw - rw)) '' "$right"
else
	printf '%s%s%s\n' "$left" "$SEP" "$right"
fi

# line 2: directory and git branch; on the right, the session name (set with
# /rename; Claude Code sends it only once one is set), else the short session id
# widths are display columns (wc -L), since the name is often Japanese
dw() { printf '%s' "$1" | wc -L; }
d=${dir/#$HOME/\~}
line2="$(fg subtext0)$d$R" l2w=$(dw "$d")
if [ -n "$dir" ] && branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null ||
	git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null); then
	line2+="$SEP$(fg mauve)$branch$R" l2w=$((l2w + 3 + $(dw "$branch")))
fi
name=${sname:-${sid:0:8}}
if [ -z "$name" ]; then
	printf '%s\n' "$line2"
	exit
fi
# right-align with a gap of at least 4; a name too long for that is cut
# with "…" instead of letting Claude Code truncate the whole line
room=$((cols - margin - l2w - 4))
nw=$(dw "$name")
if ((cols > 0 && nw > room)); then
	while ((${#name} > 0 && nw + 1 > room)); do
		name=${name:0:-1} nw=$(dw "$name")
	done
	[ -n "$name" ] && name+=… nw=$((nw + 1))
fi
if [ -z "$name" ]; then
	printf '%s\n' "$line2"
elif ((cols > 0)); then
	printf '%s%*s%s\n' "$line2" $((cols - margin - l2w - nw)) '' "$(fg "$ACCENT")$name$R"
else
	printf '%s%s%s\n' "$line2" "$SEP" "$(fg "$ACCENT")$name$R"
fi
