# React / TypeScript の観点（tech-put-app）

> このプロジェクトには ESLint が無い。他所では機械が潰す `any` / 空 catch / `useEffect` 依存配列 / インライン style も **人が見る**。

## 3.1 型と契約
- `any` / 不要な `as` が増えていないか
- `src/lib/*Api.ts` の interface がバックエンドの `*_json` と一致しているか（キー名・camelCase・`id: string`）。片方だけ変わっていたら P1
- 難読型に名前が付いているか

## 3.2 副作用の場所
- `useEffect` の依存配列に漏れがないか。クリーンアップがあるか
- `useLayoutEffect` は描画前の同期 DOM 測定だけか
- fetch をコンポーネントから直接呼んでいないか（`*Api.ts` 経由か）

## 3.3 ルーティング・認可
- 「閲覧」と「編集」が同じパスに飛んでいないか。固定パスと動的パスの順序
- 新しいページに `useRequireAuth` / `useRequireAdmin` / `useRequireManager` があるか
- 管理者 API のパスが `/admin/` から、マネージャー API が `/manager/` から始まっているか（トークン切替の条件）
- 受講生の操作で `user_id` / `tenant_id` を送っていないか

## 3.4 状態の境界
- ロード中 / 空 / エラー / 成功の 4 状態。空フォームのちらつき
- submit / delete のエラーが画面に出るか。`catch` で握りつぶしていないか
- 連打・二重送信の抑止（送信中は disabled）

## 3.5 IndexedDB / 永続化
- DB 接続がモジュール内シングルトンか
- `put` で既存フィールドを落としていないか
- 並び順を id 依存にしていないか

## 3.6 CSS / レイアウト
- Tailwind クラスを書いていないか（効かない）
- `style={{}}`・`!important`・`overflow: hidden` で隠す応急処置がないか（`/layout-defense` §2）
- 320 / 375 幅で横溢れしないか（`scrollWidth` の数値が報告にあるか）

## 3.7 セキュリティ
- `dangerouslySetInnerHTML` / `innerHTML` の新設。rehype-sanitize を外していないか
- トークンを新しい場所（URL・別キー・ログ）に置いていないか
- `VITE_*` に秘密を置いていないか
- 依存の追加で `npm audit --omit=dev` の high が増えていないか

## 3.8 命名・構造
- state が `data` / `list` になっていないか。コールバック引数が 1 文字になっていないか
- 「追加用」「編集用」を別コンポーネントにしていないか
- Layout / 共通部品への「ついで修正」が混ざっていないか
