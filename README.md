# household-env

家計簿アプリとクレカ管理ツールのローカル環境。標準の `compose.yml` は、Railwayと同じく家計簿フロントエンド・クレカフロントエンド・Laravel・MySQLの4サービスで起動する。フロントエンドとLaravelは、それぞれのリポジトリにある本番用 `Dockerfile` からビルドする。

## 構成

| サービス | ソース | ローカルURL・ポート | 役割 |
| --- | --- | --- | --- |
| `household-front` | `src/kanntan-kakeibo` | http://localhost:5174 | ビルド済みVue画面。`/api/` は内部ネットワークのLaravelへ転送 |
| `credit-card-front` | `src/credit-card-front` | http://localhost:5175 | 独立したクレカSPA。同じLaravel API・DB・ユーザーを利用 |
| `kakeibo-app` | `src/kakeibo` | http://localhost:8080 | Laravel API・マイグレーション |
| `db` | MySQL 8.4 | localhost:3306 | 共通DB。`mysql-data` ボリュームで保持 |

本番のフロントエンドは公開HTTPSホストへAPIを転送する。ローカルではフロントエンドのイメージを変えず、nginx設定ファイルだけ `docker/nginx/household-front.local.conf.template` に差し替えてDocker内部のHTTPへ転送する。LaravelのDB接続先は `db:3306`、データベースは `kakeibo`。スキーマ変更はLaravelのマイグレーションで管理する。

## スマホからの確認

フロントエンドの5174番・クレカ画面の5175番ポートはLANから接続できるよう公開している。Macとスマホを同じWi-Fiに接続し、MacのIPアドレスを調べてスマホのブラウザーから `http://<MacのIPアドレス>:5174` を開く。MacのIPアドレスは「システム設定 → Wi-Fi → 詳細 → TCP/IP」で確認できる。ターミナルでは `ipconfig getifaddr en0` でも確認できる。

通常構成は `docker compose up -d --force-recreate household-front`、ホットリロード構成は `docker compose -f compose.dev.yml up -d --force-recreate household-front` でフロントを再起動する。APIはフロント経由で接続するため、スマホからLaravelへ直接接続する必要はない。接続できない場合は、Macとスマホが同じネットワークにいることと、MacのファイアウォールがDocker Desktopの接続を許可していることを確認する。

## 初回セットアップ

このディレクトリで実行する。ソースは環境リポジトリの管理対象外のため、未取得の場合のみ個別にcloneする。

```bash
git clone git@github.com:yuuki-sakurai/kakeibo-app.git src/kakeibo
git clone https://github.com/yuuki-sakurai/kanntan-kakeibo.git src/kanntan-kakeibo
cp -n .env.example .env
cp -n src/kakeibo/.env.example src/kakeibo/.env
```

Laravelの `src/kakeibo/.env` に永続的な `APP_KEY` とDB接続情報を設定する。`DB_CONNECTION=mysql`、`DB_HOST=db`、`DB_PORT=3306`、`DB_DATABASE=kakeibo` とする。初期SQLでは `app_user` / `app_password` を作成する。環境側 `.env` の `DB_USERNAME` / `DB_PASSWORD` とは自動連動しないため、Laravel側の値を初期SQLに合わせる。既存DBと既存の `APP_KEY` は引き継ぐ。

新規Laravel環境で `APP_KEY` が空の場合だけ、起動前にキーを生成し、表示された値を `src/kakeibo/.env` の `APP_KEY` に設定する。既存キーは再生成しない。

```bash
docker compose run --rm --no-deps kakeibo-app php artisan key:generate --show
```

```bash
docker compose up -d --build --remove-orphans
docker compose exec kakeibo-app php artisan migrate --force
docker compose ps
```

既存の4サービス構成から切り替える際、`--remove-orphans` は旧 `kakeibo-web` コンテナだけを削除する。MySQLの `mysql-data` ボリュームは残る。初期SQLは新しいDBボリュームの作成時だけ実行される。データ保持のため `docker compose down -v` や `migrate:fresh` は使用しない。

## 日常の利用

```bash
docker compose up -d
docker compose logs -f household-front kakeibo-app
```

標準構成ではソースをコンテナへマウントせず、本番と同様にビルドした内容を配信する。ソースを変更したら `docker compose up -d --build` で反映する。バックエンドのヘルスチェックは http://localhost:8080/up、フロントエンドは http://localhost:5174/healthz。LaravelはAPI専用で、クレカ管理画面はcredit-card-frontが配信します。

## ホットリロードで開発する場合

従来の bind mount とViteを使う開発構成を `compose.dev.yml` に残している。同じ `household` プロジェクトと `mysql-data` ボリュームを使用する。構成を切り替える場合は次のコマンドで旧構成の余分なコンテナを削除する。

```bash
docker compose -f compose.dev.yml up -d --build --remove-orphans
docker compose -f compose.dev.yml exec kakeibo-app composer install
docker compose -f compose.dev.yml exec kakeibo-app php artisan migrate
```

開発構成でも家計簿画面は http://localhost:5174、クレカ管理画面は http://localhost:5175、共通APIは http://localhost:8080 です。両SPAは専用NodeコンテナでViteが起動し、ソースの変更が反映されます。Laravel側でnpmやViteを起動する必要はありません。

型チェックとビルドは `docker compose -f compose.dev.yml exec credit-card-front npm run build`（家計簿は `household-front`）、Laravelテストは `docker compose -f compose.dev.yml exec kakeibo-app php artisan test` を使います。

標準構成へ戻すには `docker compose up -d --build --remove-orphans` を実行する。停止は使用中の構成に対応する `docker compose stop` または `docker compose -f compose.dev.yml stop` を使う。

## クレカSPAの分離

`src/credit-card-front` は独立したローカルGitリポジトリです。リモートは別途作成予定のため、cloneコマンドはまだありません。リモート公開まではこのディレクトリのソース一式を用意してからComposeを起動してください。環境リポジトリにはsrc配下の各アプリのソースは含みません。

既存の2リポジトリはdevelopから `feature/credit-card-spa` を作成し、新規SPAも同名の作業ブランチで管理しています。家計簿フロントのソースは変更していません。

- クレカ画面: http://localhost:5175（`CREDIT_CARD_FRONT_PORT` で公開ポート変更可）
- クレカのヘルスチェック: http://localhost:5175/healthz（標準構成）
- 家計簿と同じメールアドレス・パスワードでログイン可能。既存データの移行は不要です。
- クレカ用テーブルはLaravelの追加マイグレーションで作成します。家計簿のexpensesとは別テーブルで、DBは共用します。
- 標準構成では各リポジトリのDockerfileを使います。本番への追加手順はcredit-card-frontのREADMEを参照してください。
- スマホは同じLANの `http://<MacのIP>:5175` へ接続します。

既存の家計簿画面との互換性を保つため、バックエンドの作業ブランチには前回の予算API（develop未マージ）も引き継いでいます。予算APIの既存PRが先にマージされた場合、重複分はGitの差分から消えます。
