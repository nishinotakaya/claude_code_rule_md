# 認証境界

> いつ読むか: 新規エンドポイント / Webhook / CORS / トークン保存先を触るとき。報告に秘密の値を書かない。

## 0. 結論

| # | 規則 |
|---|---|
| 1 | 認証 `before_action` をパス前方一致条件で書かない。既定で全部にかけ、公開するものだけ `skip_before_action` で外す |
| 2 | `protect_from_forgery` をコメントアウトのまま残さない（API モードは対象外。旧 ERB 側は残す） |
| 3 | `skip_before_action :verify_authenticity_token` には署名検証を併設する |
| 4 | CORS に `*` と部分一致正規表現を使わない |
| 5 | production で `force_ssl` を false にしない |
| 6 | トークンを localStorage / URL クエリに置かない（既存分は httpOnly Cookie 移行の TODO として扱う） |
| 7 | 未認証リクエストが 401 を返すテストを 1 本書く |

## 1. 認証をパス前方一致条件で書かない

```ruby
# ❌ 載っていないパスが素通りする
before_action :authenticate!, if: -> { request.path_info.start_with?('/api/v1/admin') }

# ✅ 既定で全部にかけ、外す側に理由を書く
before_action :authenticate!
skip_before_action :authenticate!, only: [:login]   # 認証前なので
```

テックプットの `Api::V1::BaseController` は `authenticate!` を既定でかけ、`auth/login` だけ skip する形。この形を崩さない。

## 2. Webhook の署名検証

```ruby
before_action :verify_webhook_signature   # skip の直後に足す

def verify_webhook_signature
  expected_signature = OpenSSL::HMAC.hexdigest('SHA256', ENV.fetch('WEBHOOK_SECRET'), request.raw_post)
  received_signature = request.headers['X-Signature'].to_s
  return if ActiveSupport::SecurityUtils.secure_compare(received_signature, expected_signature)

  head :unauthorized
end
```

- `==` で比較しない。`secure_compare` を使う
- 署名対象は `request.raw_post`。`params.to_json` で組み直すとバイト列が一致しない
- 署名検証でもリプレイは防げない。「既に処理済みなら何もしない」を入れる

## 3. CORS

```ruby
# ❌ サブドメインは誰でも取れるので実質ワイルドカード
origins /\Ahttps?:\/\/.*\.vercel\.app\z/
# ❌
origins '*'

# ✅ 完全一致の許可リスト（テックプットの cors.rb の形）
origins ENV.fetch('FRONTEND_ORIGIN')
credentials: false
```

`credentials: true` にする変更は、Cookie 認証へ移行するときに CSRF 対策とセットで入れる。

## 4. トークンの保存先

テックプットのフロントは `src/lib/api.ts` が `user_token` / `admin_token` / `manager_token` を localStorage に置いている。同一オリジンの任意 JS から読めるので XSS 1 件で抜ける。

- 新しいキーを増やさない。保存・取得は `tokenStorage` に閉じる
- URL クエリ（`?token=`）に載せない。Referer・履歴・ログに残る
- `dangerouslySetInnerHTML` / `innerHTML` を新設しない。Markdown は `rehype-sanitize` を通す
- 移行先は httpOnly + Secure + SameSite Cookie。`api.ts` の TODO が正本

## 5. JWT

- 署名鍵は `ENV['SECRET_KEY_BASE']`。コードにリテラルを置かない
- `role` をペイロードに含め、`authenticate_admin!` 等は `role` と対象テーブルの両方で判定する（id が一致しても role が違えば弾く）
- 有効期限（24h）を延ばす変更は失効手段（§role-boundary 4）とセットで

## 6. 締め

上の 7 行を確認したら、最後に未認証リクエストが 401 を返す request spec を 1 本書く。通る側のテストだけでは境界は守れない。境界を外す変更（skip / CORS 追加）は、代替の検証を同じコミットで入れる。
