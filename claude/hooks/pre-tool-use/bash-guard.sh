#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/bash-guard.sh — Bash ツール実行前の安全確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : コマンドのリスクレベルを classify() で機械判定し、
#          通過・ユーザー確認（ask）・拒否（deny）を判定する。
#          description は判定に使わない。Cursor CLI の preToolUse ペイロードには
#          description が存在せず、記載必須にするとエージェントに修正手段のない
#          恒久 deny になるため（Why not: description プロトコルは除去済み）。
#
# リスク階層による判定:
#   READ         : 状態を変えない（ls/cat/grep/git status/git diff/git log 等）→ 通過
#   WRITE        : ローカル状態を変える（mkdir/touch/mv/cp/sed -i/リダイレクト 等）→ 通過
#   INSTALL      : 依存追加（npm install/pnpm add/pip install/brew install 等）
#                  → ユーザー確認（サプライチェーン攻撃のリスク）
#   NETWORK_WRITE: 外部状態を変える（git push/gh pr merge/gh api 書き込み 等）→ ユーザー確認
#   DESTRUCTIVE  : 取り返しがつかない（rm/git reset --hard/git push --force 等）→ ユーザー確認
#
# ask の理由文の先頭タグ:
#   `[DESTRUCTIVE]` `[SECRET_PATH]` は、確認を出せない環境で deny へ落とす対象の目印です。
#   codex/hooks/wrap/pre-tool-use.sh がこの2つのタグを見て変換します（Codex CLI は ask を
#   無視して実行するため。2026-08-31 実測、explore/codex-ask-decision-check.md）。
#   `[SECRET_NAME]` は変換しません。どこにでも現れ得る名前（.env）への一致で、
#   deny にすると Codex で無害な命令まで恒久的に実行できなくなるためです。
#   タグは deny-rules.txt の4列目が持ち、scripts/generate-permissions.py が
#   情報源の glob から機械的に決めます（人が分類しません）。
#   タグを消したり文言の先頭から動かしたりすると変換が止まるため、
#   codex/tests/ask-fallback.test.sh がタグの存在を検査します。
#
# 階層判定より前に適用するルール:
#   - permissions/deny-rules.json から生成した deny-rules.txt に一致したら deny または ask
#     （秘密ファイルへの操作と、秘密情報の書き換え・公開・削除を伴う命令）
#     秘密ファイルは「名前が一致し、かつ中身を読み書きする命令である」ときだけ deny です。
#
# Why not: `.env.example` `.env.sample` を検査の対象外にする例外リストを作りません。
#          claude/settings.json の permissions.deny はグロブで書かれ、否定を表現できません。
#          シェル層だけ除外すると Read ツールでの読み取りは拒否されたままになり、
#          同じファイルに cat は通り Read は通らない状態が生まれます。ツールでの失敗を
#          シェルコマンドで迂回する動作を誘発するため、非対称を作りません。
#          上記の deny の条件により `.env.example` は ask へ落ちるので、例外は不要です。
#
# 個別ルール（階層判定の後に適用）:
#   - 保護ブランチ上での git commit / git merge は deny（PR 経由を強制）
#   - WORK_RECORD_FILES がステージ済みで git commit しようとした場合は deny
#   - npm install（パッケージ名なし）と pip install -r は deny
#     WHY: semver範囲でバージョンが解決されるため、意図しないバージョンが入り、
#          挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性がある
#     ※ npm install <pkg> / npm ci / pnpm install --frozen-lockfile / yarn install --immutable は通過する
#       pnpm install（--frozen-lockfile なし）・yarn install（--immutable なし）は INSTALL としてユーザー確認
#
# 注: rm -rf / shred / xargs rm / find -delete 等は pre-tool-use/dangerous-guard.sh で拒否済み。
#     単一ファイルの rm は dangerous-guard.sh の対象外のため、このスクリプトで DESTRUCTIVE に分類する。
#
# 終了コード:
#   0 → 通過（READ / WRITE）または ask / deny JSON を出力して終了
#
# 入力 : stdin の JSON（tool_input.command）
# 出力 : stdout の JSON（permissionDecision: "ask" または "deny"）
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で判定済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
# shellcheck source=../lib/decision.sh
source "$(dirname "$0")/../lib/decision.sh"
exit_if_cursor_payload "$INPUT"

# command / cwd を1回の jq でまとめて取得する（同一 stdin を2回 parse しない）。
# command は改行を含み得るため、read（改行で切れる）ではなく NUL 区切り＋mapfile で
# 分割する。各フィールドを NUL 終端して連結し（join + 末尾 NUL）、末尾要素のズレを防ぐ。
# コミット先のブランチは「いま作業しているディレクトリ（worktree）」で判定する。
# CLAUDE_PROJECT_DIR は worktree 切り替えに追従せず起動時のプロジェクトルートを指したままなので、
# worktree 上での git commit / git merge を誤って保護ブランチ扱いしてしまう。
# Claude Code が hook 入力で渡す .cwd（worktree に追従する）を使い、空のときだけ pwd にフォールバックする。
mapfile -d '' -t _fields < <(
  jq -j '[.tool_input.command // "", .cwd // ""]
         | join("\u0000") + "\u0000"' <<<"$INPUT"
)
COMMAND="${_fields[0]:-}"
CWD="${_fields[1]:-}"

# 引用符内の文字列を除去してパターンマッチングの誤検知を防ぐ
# （例: grep "git push" が git push コマンドとして誤検知されることを防ぐ）
COMMAND_UNQUOTED=$(echo "$COMMAND" | sed 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

_deny() {
  hook_emit_decision deny PreToolUse "$1"
  exit 0
}

_ask() {
  hook_emit_decision ask PreToolUse "$1"
  exit 0
}

# --- 秘密ファイルの読み書きと、拒否する命令を deny ---
# permissions/deny-rules.json から生成した deny-rules.txt と照合する。
# WHY: claude/settings.json の permissions.deny は Claude Code しか読まない。Codex CLI には
#      許可・拒否の設定がなく、gh secret set / vault kv put / security find-generic-password は
#      classify() のどのパターンにも一致せず無警告で通っていた。シェル層で止めて3つのCLIで揃える。
# WHY: コマンド名（cat）ではなくパス名で判定する。head / sed / awk / python -c 経由の読み取りも
#      同じ1行で捕まえられる。誤検知（無害な命令が止まる）は、見逃しより害が小さいので許容する。
# WHY: deny と ask を分ける。deny は情報源のglobが表す範囲に忠実な一致（cat .env.local など）。
#      ask はその範囲外だが名前が一致するもの（grep "process.env" など）。検知の網は狭めず、
#      判断が要るものはユーザーへ回す。過去891セッション1918件の実測では ask 相当が6件（0.3%）。
# Why not: COMMAND_UNQUOTED（引用符の中を除去した文字列）を使わない。cat "$HOME/.ssh/..." のように
#          引用符で囲めば素通りしてしまうため。代わりに、秘密パスを引用符付きで書いただけの
#          grep や echo も止まる。理由が表示されるので回避できる。
# Why not: 変数を `$label` と裸で書かない。ロケールがCのとき bash 5.3 は全角括弧のバイト列を
#          変数名の一部として読み、展開結果が壊れる（実際に `（$label）` が `（??` になった）。
#          日本語が直後に続く展開は必ず `${label}` の形で書く。
# Why not: シェル層の照合には原理的な取りこぼしがある。この層はコマンドの「文字列」しか見えず、
#          実行時に何のパスへ届くかを知らないため、パスを分割して組み立てる書き方は通過する。
#            例: `H=~/.ssh; cd $H; cat id_ed25519` — 連結後のパスが文字列に現れない
#            例: `"npm" publish` — 引用符でトークンが割れる（COMMAND_UNQUOTED は前述の理由で使えない）
#          （`cd ~/.ssh && cat id_ed25519` は 2026-09-02 に塞いだ。ディレクトリを表すルールの
#            末尾スラッシュを任意にしたため、移動先の指定として書いても一致する。）
# Why not: この取りこぼしを塞ぐために変数や `$(...)` の使用を止めない。分割の手段は
#          eval / printf / base64 / スクリプトファイルへの退避と無限にあり、1つ塞いでも
#          次が残るので防御にならない。一方で `for f in ...; do cat $f; done` のような
#          普通のシェル操作がすべて確認要求になり、承認が常態化して本当に危険なときの
#          確認まで効かなくなる。防御を足したつもりで全体の防御が下がる。
#          塞ぐなら claude/settings.json の permissions.deny（実パスとツール引数で判定する）。
#          ツール層とシェル層は互いの穴を埋める関係で、シェル層だけで完結させようとすると
#          正規表現が際限なく増えて誤検知が実害になる。
# Why not: `grep -qE` を使わない。ルール1行ごとにプロセスを起動するため、Bashを1回呼ぶたびに
#          約200ms増えた（46行で実測）。bash の `=~` はEREを同じ構文で解釈し、起動が要らない。
#          `^` の扱いだけが異なる（grepは行頭、`=~` は文字列の先頭）が、行頭の直前は改行であり、
#          どのルールも直前に改行を許す文字クラスを持つため判定は変わらない（T7で検証する）。

# ファイルの中身を読む・書く・外へ送る命令かどうかを判定する。
# 秘密ファイルの名前に一致しただけでは deny にせず、この判定と両方を満たしたときだけ deny する。
# WHY: 名前が現れただけで deny にしていたため、`git commit -m "docs: .env の読み方"` や
#      `ls -la .env.example` が拒否されていた。deny はユーザーの承認で覆せないので、
#      コミットメッセージや検索語に秘密ファイルの名前を書くことが恒久的にできなかった。
#      止めたいのは中身が外へ出ることであり、名前が文字列として現れること自体ではない。
# Why not: この一覧を網羅しようとしない。原理的に尽きないし、漏れたときの判定は deny から
#          ask へ落ちるだけで、無言の実行にはならない。安全側に倒れる形なので、
#          日常的に使う命令を入れておけば足りる。
# Why not: COMMAND_UNQUOTED（引用符の中を除去した文字列）を使わない。`cat "$HOME/.ssh/..."`
#          のように引用符で囲めば命令の判定も素通りしてしまうため。
CONTENT_ACCESS_ERE='(^|[|;&(]|[[:space:]])(cat|bat|head|tail|less|more|nl|od|xxd|base64|strings|sed|awk|perl|ruby|python3?|node|deno|bun|jq|yq|cp|mv|install|rsync|scp|sftp|ssh|curl|wget|nc|tar|zip|gzip|openssl|gpg|source|dotenv|env|export|grep|rg|ag|ack)([[:space:]]|$)|[<>]'

_is_content_access() {
  [[ $COMMAND =~ $CONTENT_ACCESS_ERE ]]
}

DENY_RULES="$(dirname "$0")/deny-rules.txt"
if [ -f "$DENY_RULES" ]; then
  while IFS=$'\t' read -r kind regex label tag; do
    case "$kind" in ''|'#'*) continue;; esac
    [[ $COMMAND =~ $regex ]] || continue
    case "$kind" in
      PATH)
        if _is_content_access; then
          _deny "ERROR: 秘密情報を含むファイルへの操作は禁止されています（${label}）。WHY: 認証情報がコマンド出力やログに残ると、会話履歴や画面共有から漏れます。FIX: 値が必要な場合は環境変数の名前だけを扱うか、ユーザー自身に確認してください。コマンド: $(hook_excerpt "$COMMAND")"
        fi
        _ask "[${tag}] 確認: 秘密情報を含むファイルの名前が含まれています（${label}）。WHY: 中身を読み書きする命令ではありませんが、名前が一致するため事故の可能性が残ります。FIX: 内容を確認し、問題なければ承認してください。コマンド: $(hook_excerpt "$COMMAND")"
        ;;
      PATHASK)
        _ask "[${tag}] 確認: 秘密情報を含むファイルの名前が含まれています（${label}）。WHY: 拒否ルールが表す範囲の外ですが、名前が一致するため事故の可能性が残ります。FIX: 内容を確認し、問題なければ承認してください。読み取りが必要な場合はユーザー自身が実行してください。コマンド: $(hook_excerpt "$COMMAND")"
        ;;
      CMD)
        _deny "ERROR: この命令の実行は禁止されています（${label}）。WHY: 秘密情報の書き換えや外部への公開・削除は取り消せず、影響がこの端末の外へ及びます。FIX: 必要な場合はユーザー自身が実行してください。コマンド: $(hook_excerpt "$COMMAND")"
        ;;
    esac
  done < "$DENY_RULES"
fi

# --- リスク階層を機械判定 ---
classify() {
  local c="$1"
  case "$c" in

    # frozen lockfile install: lockfile に固定されたバージョンのみインストール。新バージョンを解決しない
    *"npm ci"* |\
    *"pnpm install --frozen-lockfile"* |\
    *"yarn install --immutable"*)
      echo "READ"; return;;

    # --force-with-lease は DESTRUCTIVE より前に評価する。
    # WHY: リモートが自分の知る状態と違えば失敗するため、他人のコミットを消せない。
    #      無条件で上書きする --force とは危険度が違う。
    #      パターンの順序を変えると `*"git push --force"*` に先に一致して DESTRUCTIVE になる。
    *"git push --force-with-lease"*)
      echo "NETWORK_WRITE"; return;;

    # DESTRUCTIVE: 取り返しがつかない操作
    # ※ git push --force / git reset --hard は NETWORK_WRITE より前に評価する必要がある
    *"git reset --hard"* |\
    *"git push --force"* |\
    *"git push -f "* |\
    *"git commit"*"--amend"* |\
    *"rm "* |\
    *"unlink "* |\
    *"truncate "*)
      echo "DESTRUCTIVE"; return;;

    # NETWORK_WRITE: 外部リポジトリ・GitHub の状態を変える操作
    # gh api は書き込みメソッド（-X / --method）またはフィールド指定（--field / -f）で判定
    *"git commit"* |\
    *"git push"* |\
    *"npm publish"* |\
    *"gh pr merge"* |\
    *"gh issue close"* |\
    *"gh api"*"-X POST"* |\
    *"gh api"*"-X PUT"* |\
    *"gh api"*"-X PATCH"* |\
    *"gh api"*"-X DELETE"* |\
    *"gh api"*"--method POST"* |\
    *"gh api"*"--method PUT"* |\
    *"gh api"*"--method PATCH"* |\
    *"gh api"*"--method DELETE"* |\
    *"gh api"*"--field "* |\
    *"gh api"*" -f "*)
      echo "NETWORK_WRITE"; return;;

    # INSTALL: 依存パッケージの追加（lock file・node_modules を変更する。サプライチェーン攻撃のリスク）
    *"npm install"* |\
    *"npm i "* |\
    *"yarn add"* |\
    *"yarn install"* |\
    *"pnpm add"* |\
    *"pnpm install"* |\
    *"pip install"* |\
    *"brew install"*)
      echo "INSTALL"; return;;

    # WRITE: ローカルファイルシステムを変更する操作
    *" > "* |\
    *" >> "* |\
    *"sed -i"* |\
    *"mkdir "* |\
    *"touch "* |\
    *"mv "* |\
    *"cp "*)
      echo "WRITE"; return;;

    # READ: 状態を変えない参照系操作
    *)
      echo "READ"; return;;

  esac
}

LEVEL=$(classify "$COMMAND_UNQUOTED")

# --- READ は通過（過剰な要求をしない）---
if [ "$LEVEL" = "READ" ]; then
  exit 0
fi

# --- 個別ルール: 保護ブランチ上での git commit → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+commit'; then
  CURRENT_BRANCH=$(git -C "${CWD:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      _deny "ERROR: 保護ブランチ '$CURRENT_BRANCH' への直接コミットは禁止されています。WHY: レビューなしに変更が保護ブランチへ反映されるリスクがあります。FIX: フィーチャーブランチを作成してから Pull Request を作成してください。"
    fi
  done
fi

# --- 個別ルール: 保護ブランチ上での git merge → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+merge'; then
  CURRENT_BRANCH=$(git -C "${CWD:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      _deny "ERROR: 保護ブランチ '$CURRENT_BRANCH' へのローカルマージは禁止されています。WHY: 直接マージによる意図しない変更混入を防ぎ、レビューを必須化するためです。FIX: GitHub で Pull Request を作成してください。"
    fi
  done
fi

# --- 個別ルール: git commit で WORK_RECORD_FILES がステージ済み → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+commit'; then
  STAGED=$(git -C "${CWD:-$(pwd)}" diff --cached --name-only 2>/dev/null || echo "")
  file_pattern=$(IFS='|'; echo "${WORK_RECORD_FILES[*]}" | sed 's/\./\\./g')
  dir_pattern=$(IFS='|'; echo "${WORK_RECORD_DIRS[*]}")
  matched=$(echo "$STAGED" | grep -E "^($file_pattern)$|^($dir_pattern)/")
  if [ -n "$matched" ]; then
    restore_args=$(echo "$matched" | tr '\n' ' ')
    _deny "ERROR: 作業記録ファイルがステージされています。WHY: これらはセッション中の作業記録であり、コミット履歴に含めてはいけません。FIX: git restore --staged ${restore_args}を実行してから再度コミットしてください。"
  fi
fi

# --- 個別ルール: npm install（パッケージ名なし）/ pip install -r → deny ---
# pip/pip3 install -r / uv pip install -r: requirementsファイルからの一括インストール
if echo "$COMMAND_UNQUOTED" | grep -qE '(^|[|;&][[:space:]]*)pip3?[[:space:]]+install[[:space:]].*(-r|--requirement)[[:space:]]'; then
  _deny "ERROR: pip install -r をパッケージ名なしで実行しようとしています。WHY: semver範囲でバージョンが解決されるため、挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性があります。FIX: 特定のパッケージを追加したい場合はpip install <package-name>を使ってください。"
fi
if echo "$COMMAND_UNQUOTED" | grep -qE '(^|[|;&][[:space:]]*)uv[[:space:]]+pip[[:space:]]+install[[:space:]].*(-r|--requirement)[[:space:]]'; then
  _deny "ERROR: uv pip install -r をパッケージ名なしで実行しようとしています。WHY: semver範囲でバージョンが解決されるため、挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性があります。FIX: 特定のパッケージを追加したい場合はuv pip install <package-name>を使ってください。"
fi
# npm install / npm i: フラグ以外のトークン（パッケージ名）がなければパッケージ追加・削除なし
if echo "$COMMAND_UNQUOTED" | grep -qE '(^|[|;&][[:space:]]*)npm[[:space:]]+(install|i)([[:space:]]|$)'; then
  rest=$(echo "$COMMAND_UNQUOTED" \
    | grep -oE 'npm[[:space:]]+(install|i)[[:space:]]*[^|;&]*' \
    | head -1 \
    | sed -E 's/^npm[[:space:]]+(i|install)[[:space:]]*//')
  pkg_count=$(echo "$rest" | tr ' ' '\n' | grep -v '^$' | grep -cvE '^-' || true)
  if [ "$pkg_count" -eq 0 ]; then
    _deny "ERROR: npm install をパッケージ名なしで実行しようとしています。WHY: semver範囲でバージョンが解決されるため、挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性があります。FIX: 特定のパッケージを追加したい場合はnpm install <package-name>を、lockfileを再現したい場合はnpm ciを使ってください。"
  fi
fi

# --- INSTALL / NETWORK_WRITE / DESTRUCTIVE → ユーザー確認 ---
if [ "$LEVEL" = "INSTALL" ] || [ "$LEVEL" = "NETWORK_WRITE" ] || [ "$LEVEL" = "DESTRUCTIVE" ]; then
  _ask "[$LEVEL] コマンド: $(hook_excerpt "$COMMAND")"
fi

# WRITE は通過
exit 0
