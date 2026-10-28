# 初日の手順（Claude Code）

## 0. 用意するもの

- プロジェクトの実行環境（Docker / Node.js / Ruby など。`overview.md` を参照）/ Git / GitHub アカウント（対象リポジトリへの招待済み）
- Claude Code（`npm install -g @anthropic-ai/claude-code`）
- （任意）Codex CLI。`/dual-ai` で第二意見を取るときに使う

## 1. リポジトリを用意する

作業するリポジトリを clone する。複数リポジトリ構成（フロント・バックエンドなど）の置き方と起動方法は、各リポジトリの `.claude/rules/project/overview.md` と README を正とする。

## 2. ルールを配備する

```bash
git clone <このルール集の URL> /tmp/claude-rules
/tmp/claude-rules/install.sh ./<対象リポジトリ> --apply
```

配備後、対象リポジトリで `claude` を起動して `/develop` が候補に出れば完了。続けて `.claude/rules/project/overview.md` の `<...>` を実値で埋める。

## 3. 1 つのタスクの流れ

1. Issue か指示を受けたら、**ベースブランチから作業ブランチを切る**（`.claude/rules/git/branch-strategy.md`）
2. Claude Code に `/develop` と伝えて始める。要件が曖昧なら先に文章で確定する
3. 実装が終わったら自分で確かめる。`overview.md` の検証コマンドと画面操作で確かめる
4. PR テンプレートを埋めて PR を出す。**動作確認の結果（コマンドと出力、スクショ）を書く**
5. レビューの指摘には「直した / 直さない理由」を 1 件ずつ返す

## 4. やってはいけないこと（上位 5 つ）

- ステージング全追加（`git add` にドットや `-A` を渡す）。コミット対象はファイル名で指定する
- 統合先ブランチへの直接 push、force push
- DB を作り直す rake タスク（reset / drop / schema:load）。開発 DB が消える
- `.env`・トークン・パスワードをコミット・チャット・PR に書く
- AI が書いたコードを動かさずに「できました」と言う

## 5. 困ったら

- 仕様が分からない: 推測で作らず、PR か Issue に質問を書いてレビュアーに聞く
- Claude Code がコマンドをブロックした（🚫 が出た）: 回避せず、なぜブロックされたかをレビュアーに相談する
- 本番・共有データを書き換える作業: 実行前に必ずレビュアーの承認を取る
