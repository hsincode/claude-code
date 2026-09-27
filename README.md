# claude-code

Claude Code（v2.1.283）の表示まわりの設定と、自作のステータスライン。

```
Opus 5.5 · medium · ctx 125.8k                         reset 41m · 5h 17% · 7d 16%
~/ghq/github.com/hsincode/claude-code · main
```

## statusline.sh

Claude Code が標準入力に渡す JSON だけで描くステータスライン。外部 API は叩かない。必要なのは `bash`・`jq`・`git`（ブランチ表示用）で、1回の実行は 10 ms 程度。

| 表示 | 元の値 |
|---|---|
| モデル名 | `model.display_name` |
| effort | `effort.level`（effort 非対応のモデルでは出さない） |
| ctx | `context_window.total_input_tokens` を k 表記 |
| reset | `rate_limits.five_hour.resets_at` までの残り時間 |
| 5h / 7d | `rate_limits.five_hour` / `seven_day` の `used_percentage` |
| 2 行目 | `workspace.current_dir`（`$HOME` は `~`）と git ブランチ（detached なら短い SHA） |

`rate_limits` は claude.ai の Pro / Max で、セッション最初の応答のあとにしか来ない。それまでは右側のブロックを丸ごと出さない。

### 配色

Catppuccin の truecolor。

- モデル名: アクセント色（太字）
- effort: low=teal、medium=sapphire、high=mauve、xhigh=pink、max=maroon
- 5h / 7d: 50% 未満 green、50% 以上 yellow、70% 以上 peach、85% 以上 red
- reset: sky、ラベル: overlay1、区切り `·`: surface2、ディレクトリ: subtext0、ブランチ: mauve

フレーバー（latte / mocha）とアクセントは次の順で決まる。

1. 環境変数 `CLAUDE_STATUSLINE_FLAVOUR`（`latte` / `mocha`）と `CLAUDE_STATUSLINE_ACCENT`（Catppuccin の色名、例 `lavender`）
2. dwm のテーマ切り替え（自分の環境用）: `~/.local/state/dwm/theme` のテーマ名（`linen-mocha` など）の末尾をフレーバーに、`~/.config/dwm/themes/<テーマ>.env` の `ACCENT=` をアクセントにする。描画のたびに読み直すので、テーマを切り替えると次の更新で色が変わる
3. どちらもなければ mocha / peach

### 右寄せ

右のブロックは `$COLUMNS` から計算して右端に寄せる。Claude Code はステータスラインの左右に 2 桁ずつ余白を取るので、使える幅は `COLUMNS - 4`（`COLUMNS=146` のとき 142 桁）。これを超えると末尾が `…` で切られる。幅が足りないときは右寄せをやめ、`·` でつないだ 1 行にする。

### 導入

```sh
ghq get hsincode/claude-code
ln -s "$(ghq root)/github.com/hsincode/claude-code/statusline.sh" ~/.claude/statusline.sh
```

`~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "padding": 0,
  "refreshInterval": 30
}
```

`refreshInterval` は reset の残り時間を進めるためのもの。Claude Code は応答やレート制限のリセット時にも描き直すが、アイドル中はそれが止まる。

## 表示まわりの設定

どれも `~/.claude/settings.json` のキー。値は [settings reference](https://code.claude.com/docs/en/settings-reference) の「Interface and terminal」を参照。

| キー | 値 | 理由 |
|---|---|---|
| `tui` | `"fullscreen"` | ちらつかない alt-screen レンダラ。通知がステータスラインと別の行に出る。`/tui fullscreen` でも書き込める |
| `viewMode` | `"focus"` | 直前の入力・ツール呼び出しの 1 行要約（差分の行数付き）・最終回答だけを表示。fullscreen が前提 |
| `theme` | `"custom:catppuccin"` | 下記のカスタムテーマ |
| `spinnerTipsEnabled` | `false` | 作業中のスピナー行に出る使い方のヒントを消す |
| `timeFormat` | `"24-hour"` | 回答後の「Cooked for 1m 6s · done 18:05」の時刻 |
| `showTurnDuration` | `true` | 上の所要時間表示（既定値） |
| `env.CLAUDE_CODE_NATIVE_CURSOR` | `"1"` | 入力欄で描画したブロックではなく端末自身のカーソルを使う（点滅や形が端末の設定に従う） |

`fullscreen` と `viewMode` は起動し直してから効く。

### Catppuccin テーマ

カスタムテーマは `~/.claude/themes/<slug>.json` に置き、`theme` に `custom:<slug>` を指定する。Claude Code はこのディレクトリを監視していて、ファイルが変わると起動中のセッションにもそのまま反映する。

カスタムテーマには「端末が明るいときは A、暗いときは B」という指定がない（`"auto"` が選ぶのは組み込みの dark / light だけ）。そこで dwm のテーマ切り替えスクリプトが、latte 版と mocha 版のどちらかを `~/.claude/themes/catppuccin.json` にコピーしている。コピーにしているのは、ディレクトリの監視にふつうのファイル変更として拾わせるため。

mocha 版（アクセント peach）。latte 版は `base` を `"light"` にし、同じ役割の色を latte の値に置き換える。

```json
{
  "name": "Catppuccin",
  "base": "dark",
  "overrides": {
    "claude": "#fab387",
    "text": "#cdd6f4",
    "inverseText": "#1e1e2e",
    "inactive": "#7f849c",
    "subtle": "#6c7086",
    "suggestion": "#b4befe",
    "permission": "#89b4fa",
    "remember": "#cba6f7",
    "success": "#a6e3a1",
    "error": "#f38ba8",
    "warning": "#f9e2af",
    "merged": "#cba6f7",
    "promptBorder": "#585b70",
    "planMode": "#94e2d5",
    "autoAccept": "#cba6f7",
    "bashBorder": "#f5c2e7",
    "ide": "#89dceb",
    "fastMode": "#f2cdcd",
    "effortUltra": "#cba6f7",
    "diffAdded": "#364143",
    "diffRemoved": "#443244",
    "diffAddedDimmed": "#282c36",
    "diffRemovedDimmed": "#2d2637",
    "diffAddedWord": "#52695a",
    "diffRemovedWord": "#6f475c",
    "userMessageBackground": "#292a3b",
    "userMessageBackgroundHover": "#313244",
    "bashMessageBackgroundColor": "#342e40",
    "memoryBackgroundColor": "#2f2c42",
    "selectionBg": "#45475a",
    "rate_limit_fill": "#fab387",
    "rate_limit_empty": "#45475a",
    "briefLabelYou": "#89b4fa",
    "briefLabelClaude": "#fab387"
  }
}
```

色の対応:

- 役割色はそのまま使う（アクセント=`claude`、success=green、error=red、warning=yellow、プランモード=teal）
- 差分の背景は base に green / red を混ぜる（通常 18%、却下後の薄い表示 7%、単語単位の強調 38%）
- 自分のメッセージの背景は base と surface0 の 60% 混合

トークンの一覧は [Terminal configuration › Create a custom theme](https://code.claude.com/docs/en/terminal-config#create-a-custom-theme) を参照。
