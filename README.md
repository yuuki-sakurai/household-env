# household-env
家計簿アプリとクレカ管理ツールの環境用リポジトリ

## 構成と開発方針

- `src/kakeibo`: 既存のクレカ管理アプリ（Laravel + Vue）。現在のフロントエンドとバックエンドは分離せず、家計簿向けAPIもこのLaravelに実装する。
- `src/kanntan-kakeibo`: 家計簿フロントエンド（Vue + TypeScript）。取得元: https://github.com/yuuki-sakurai/kanntan-kakeibo
- `db`: 共通のMySQL。Laravelから `db:3306` の `kakeibo` データベースへ接続する。家計簿フロントエンドはDBへ直接接続しない。
- 家計簿の `/api` リクエストはViteから `kakeibo-web` へ転送する。今後のAPIはJSONを返し、業務処理は画面描画から独立させ、将来のフロント分離に備える。
- 家計簿画面は `src/api/expenseApi.ts` のHTTPクライアントからLaravel API v1へ接続し、共通MySQLへ保存する。API・DB仕様は `src/kakeibo/docs/household-api.md` を参照。
- 共通DBのスキーマ変更はLaravel側のマイグレーションで管理する。

## 初回セットアップ

このディレクトリで実行する。ソースは環境リポジトリの管理対象外のため、未取得の場合のみ個別にcloneする。

```bash
git clone git@github.com:yuuki-sakurai/kakeibo-app.git src/kakeibo
git clone https://github.com/yuuki-sakurai/kanntan-kakeibo.git src/kanntan-kakeibo
cp -n .env.example .env
cp -n src/kakeibo/.env.example src/kakeibo/.env
docker compose up -d --build db kakeibo-app
docker compose exec kakeibo-app composer install
```

Laravelの `.env` は `DB_CONNECTION=mysql`、`DB_HOST=db`、`DB_PORT=3306`、`DB_DATABASE=kakeibo` とする。ユーザーとパスワードは既存DBに合わせる。初期SQLでは `app_user` / `app_password` を作成する（環境側 `.env` の `DB_USERNAME` / `DB_PASSWORD` と自動連動しない）。`APP_URL` は `http://localhost:8080` に設定する。

新規Laravel環境で `APP_KEY` が空の場合だけ `docker compose exec kakeibo-app php artisan key:generate` を実行する。既存キーは再生成しない。

```bash
docker compose exec kakeibo-app php artisan migrate
docker compose exec kakeibo-app npm ci
docker compose exec kakeibo-app npm run build
docker compose up -d
```

MySQL初期SQLはデータボリュームの初回作成時だけ実行される。既存データを維持するため、`docker compose down -v` や `migrate:fresh` は使用しない。

## 日常の開発

```bash
docker compose up -d
docker compose logs -f household-front
```

- 家計簿: http://localhost:5174
- クレカ管理 / Laravel: http://localhost:8080
- クレカ側Viteを使用する場合: `docker compose exec kakeibo-app npm run dev`（5173ポート）
- 家計簿の型チェック・ビルド: `docker compose exec household-front npm run build`
- Laravelテスト: `docker compose exec kakeibo-app php artisan test`
- 停止: `docker compose stop`

家計簿サービスは起動時にlockfileどおり `npm ci` を実行する。依存パッケージはDockerの名前付きボリュームに保存する。Dockerでのローカル開発を対象とし、Sitesへの公開は行わない。
