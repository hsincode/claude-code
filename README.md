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
| `theme` | `"custom:catppuccin"` | 下記のカスタムテーマ |
| `spinnerTipsEnabled` | `false` | 作業中のスピナー行に出る使い方のヒントを消す |
| `timeFormat` | `"24-hour"` | 回答後の「Cooked for 1m 6s · done 18:05」の時刻 |
| `showTurnDuration` | `true` | 上の所要時間表示（既定値） |
| `env.CLAUDE_CODE_NATIVE_CURSOR` | `"1"` | 入力欄で描画したブロックではなく端末自身のカーソルを使う（点滅や形が端末の設定に従う） |

`fullscreen` は起動し直してから効く。ツール呼び出しの表示は既定のまま（1 行要約、`Ctrl+O` で展開）。（`viewMode` は設定しない。`"focus"` にすると最終回答以外がほぼ畳まれる）

### Catppuccin テーマ

カスタムテーマは `~/.claude/themes/<slug>.json` に置き、`theme` に `custom:<slug>` を指定する。Claude Code はこのディレクトリを監視していて、ファイルが変わると起動中のセッションにもそのまま反映する。

カスタムテーマには「端末が明るいときは A、暗いときは B」という指定がない（`"auto"` が選ぶのは組み込みの dark / light だけ）。そこで dwm のテーマ切り替えスクリプトが、latte 版と mocha 版のどちらかを `~/.claude/themes/catppuccin.json` にコピーしている。コピーにしているのは、ディレクトリの監視にふつうのファイル変更として拾わせるため。

mocha 版（アクセント peach）。latte 版は `base` を `"light-ansi"` にし、同じ役割の色を latte の値に、diff の背景を明るい 256 色（194 / 224 / 157 / 217 / 254）に置き換える。

```json
{
  "name": "Catppuccin",
  "base": "dark-ansi",
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
    "diffAdded": "ansi256(22)",
    "diffRemoved": "ansi256(52)",
    "diffAddedWord": "ansi256(28)",
    "diffRemovedWord": "ansi256(88)",
    "diffAddedDimmed": "ansi256(235)",
    "diffRemovedDimmed": "ansi256(235)",
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
- diff の背景は 256 色の番号で指定する（mocha: 追加 22 / 削除 52、単語単位の強調 28 / 88、却下後の薄い表示 235）

### diff の構文ハイライト

diff・コードブロック・ファイルプレビューの構文の色は、カスタムテーマのトークンでは変えられない。v2.1.283 の実装では、`base` が dark 系なら Monokai、light 系なら GitHub の固定の表を使い、`*-ansi` のときだけ端末の 16 色パレットを使う（キーワード=bright magenta、`const`・`fn`・型=bright cyan、数値=bright blue、文字列=bright green、関数名・クラス名=bright yellow、コメント=bright black）。Ghostty のパレットが Catppuccin なので、`base` を `dark-ansi` / `light-ansi` にすると構文の色も Catppuccin になり、latte / mocha にも追従する。

代わりに `*-ansi` の diff は 256 色で描かれ、hex で指定した背景は最も近い 256 色に丸められる。Catppuccin の淡い混色は、追加と削除がどちらも同じ灰色（`#3a3a3a`）になってしまう。そのため diff の背景だけは `ansi256(n)` で指定している。これはドキュメントにない内部の実装なので、アップデートで変わるかもしれない。
- 自分のメッセージの背景は base と surface0 の 60% 混合

トークンの一覧は [Terminal configuration › Create a custom theme](https://code.claude.com/docs/en/terminal-config#create-a-custom-theme) を参照。
