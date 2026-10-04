# household-env

家計簿アプリとCardDock（クレカ管理SPA）の共通ローカル環境です。家計簿・CardDockは独立したVue SPAで、Laravel API・認証・MySQLを共用します。

標準の `compose.yml` は、各アプリの配信用Dockerfileからビルドした4サービスを起動します。ソース変更をすぐ確認する開発時は、bind mountとViteを使う `compose.dev.yml` に切り替えます。

## リポジトリとサービス

| サービス | ソースリポジトリ・配置 | ローカルURL・ポート | 役割 |
| --- | --- | --- | --- |
| `household-front` | [kanntan-kakeibo](https://github.com/yuuki-sakurai/kanntan-kakeibo) / `src/kanntan-kakeibo` | http://localhost:5174 | 家計簿SPA |
| `credit-card-front` | [CardDock](https://github.com/yuuki-sakurai/CardDock) / `src/credit-card-front` | http://localhost:5175 | クレカ管理SPA |
| `kakeibo-app` | [kakeibo-app](https://github.com/yuuki-sakurai/kakeibo-app) / `src/kakeibo` | http://localhost:8080 | 共通Laravel API・認証・マイグレーション |
| `db` | MySQL 8.4 | localhost:3306 | 共通DB。`mysql-data` ボリュームで保持 |

`src` 配下の3アプリはそれぞれ独立したGitリポジトリで、環境リポジトリの管理対象外です。`main` はリリース用、`develop` は開発の統合先とし、通常の作業ブランチは `develop` から作成します。月予算APIとCardDockのSPA分離・共通API化は `develop` に統合済みです。

標準構成の両フロントは、Nodeで作成した `dist/` をnginxで配信します。ローカル用の `docker/nginx/household-front.local.conf.template` をマウントし、`/api/` をDocker内部の `http://kakeibo-app.local:8080` へ転送します。LaravelのDB接続先は `db:3306`、データベースは `kakeibo` です。

## 初回セットアップ

以下は `household-env` ディレクトリで実行します。Docker DesktopとGitが必要です。ソースと設定ファイルは未取得の場合のみ用意してください。開発用に各リポジトリの `develop` を取得します。

```bash
git clone --branch develop https://github.com/yuuki-sakurai/kakeibo-app.git src/kakeibo
git clone --branch develop https://github.com/yuuki-sakurai/kanntan-kakeibo.git src/kanntan-kakeibo
git clone --branch develop https://github.com/yuuki-sakurai/CardDock.git src/credit-card-front
cp -n .env.example .env
cp -n src/kakeibo/.env.example src/kakeibo/.env
```

Laravelの `src/kakeibo/.env` で以下を設定します。既存環境では既存の `APP_KEY` とDB接続情報を維持してください。

```dotenv
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=kakeibo
DB_USERNAME=app_user
DB_PASSWORD=app_password
FRONTEND_ORIGINS=http://localhost:5174,http://localhost:5175
```

上記DBユーザーとパスワードはローカル開発用の初期SQLに対応します。環境側 `.env` の `DB_USERNAME` / `DB_PASSWORD` を変えても、初期SQLやLaravel側の設定には自動反映されません。`CREDIT_CARD_FRONT_PORT` を変更した場合、開発構成の `FRONTEND_ORIGINS` もそのポートに合わせます。

新規Laravel環境で `APP_KEY` が空の場合だけ、次のコマンドでキーを生成し、表示された値を `src/kakeibo/.env` の `APP_KEY` に設定します。既存キーは再生成しません。

```bash
docker compose build kakeibo-app
docker compose run --rm --no-deps kakeibo-app php artisan key:generate --show
```

設定後にサービスを起動し、マイグレーションを適用します。

```bash
docker compose up -d --build --remove-orphans
docker compose exec kakeibo-app php artisan migrate --force
docker compose ps
```

初期SQLは新しいDBボリュームの作成時だけ実行されます。スキーマ変更はLaravelのマイグレーションで管理します。家計簿の支出とCardDockの明細は別テーブルで、既存データを移動する必要はありません。データ保持のため `docker compose down -v` や `migrate:fresh` は使用しないでください。

## 標準構成での利用

```bash
docker compose up -d
docker compose logs -f household-front credit-card-front kakeibo-app
```

標準構成ではアプリのソースをbind mountしません。フロントを変更した場合は、対象イメージを再ビルドしてコンテナを更新します。

```bash
docker compose build household-front credit-card-front
docker compose up -d --no-deps household-front credit-card-front
```

バックエンドを変更した場合も `docker compose up -d --build kakeibo-app` で反映し、必要なスキーマ変更がある場合は `docker compose exec kakeibo-app php artisan migrate --force` を実行します。

両フロントのDockerビルドでは型チェックと本番ビルドが実行されます。起動後のフロントコンテナはnginxなので、`docker compose exec household-front npm run build` は使えません。Laravelの標準イメージも開発用依存を含まないため、テストは下記の開発構成で実行します。

標準構成のヘルスチェックURLは、家計簿が http://localhost:5174/healthz 、CardDockが http://localhost:5175/healthz 、APIが http://localhost:8080/up です。

## ホットリロードで開発する場合

`compose.dev.yml` は単独で使う開発構成です。両フロントをNode/Vite、LaravelをPHP-FPMで起動し、Laravel配信用の `kakeibo-web`（nginx）が加わる5サービス構成です。両SPAの `/api/` はViteから `http://kakeibo-web` へ転送します。Laravel側でnpmやViteを起動する必要はありません。

両構成は環境側 `.env` の `COMPOSE_PROJECT_NAME=household` により同じプロジェクトと `mysql-data` ボリュームを使用します。構成を切り替えるときは次を実行します。

```bash
docker compose -f compose.dev.yml up -d --build --remove-orphans
docker compose -f compose.dev.yml exec kakeibo-app composer install
docker compose -f compose.dev.yml exec kakeibo-app php artisan migrate
```

初回セットアップで用意したLaravelの `.env` と `APP_KEY` をそのまま使用します。フロントは起動時に `npm ci` を実行し、ソース変更を反映します。URLは標準構成と同じです。

型チェック・ビルドとLaravelテストは開発構成で実行できます。

```bash
docker compose -f compose.dev.yml exec household-front npm run build
docker compose -f compose.dev.yml exec credit-card-front npm run build
docker compose -f compose.dev.yml exec kakeibo-app php artisan test
```

標準構成へ戻すには次を実行します。`--remove-orphans` は現在のCompose定義に存在しないコンテナ（開発構成の `kakeibo-web` など）を削除しますが、DBボリュームは保持します。

```bash
docker compose up -d --build --remove-orphans
```

停止には使用中の構成に応じて `docker compose stop` または `docker compose -f compose.dev.yml stop` を使います。

## スマホからの確認

両フロントのポートはLANから接続できます。Macとスマホを同じWi-Fiに接続し、スマホのブラウザーで `http://<MacのLAN IP>:5174`（家計簿）または `http://<MacのLAN IP>:5175`（CardDock）を開きます。CardDockの公開ポートは環境側 `.env` の `CREDIT_CARD_FRONT_PORT` で変更できます。

MacのIPアドレスは「システム設定 → Wi-Fi → 詳細 → TCP/IP」で確認できます。Wi-Fiインターフェースが `en0` の場合、ターミナルでは `ipconfig getifaddr en0` でも確認できます。APIには各フロント経由で接続します。接続できない場合は同じネットワークにいることと、MacのファイアウォールがDocker Desktopの接続を許可していることを確認してください。

両SPAは同じメールアドレス・パスワードでログインできます。別ドメイン間でログイン状態を自動共有するSSOは未実装です。
