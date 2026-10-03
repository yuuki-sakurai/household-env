# syntax=docker/dockerfile:1

# Composerの実行環境ではなく、バイナリだけを取得する
FROM composer/composer:2-bin AS composer

# アプリケーション本体
FROM php:8.4.23-fpm-alpine3.24 AS app

ENV TZ=Asia/Tokyo \
    COMPOSER_ALLOW_SUPERUSER=1

RUN set -eux; \
    \
    # 実行時に必要なパッケージ
    apk add --no-cache \
        git \
        openssh-client \
        unzip \
        tzdata \
        mariadb-client \
        libstdc++ \
        icu-data-full \
        icu-libs \
        libzip \
    ; \
    \
    # PHP拡張のコンパイル時だけ必要なパッケージ
    apk add --no-cache --virtual .php-ext-build-deps \
        icu-dev \
        libzip-dev \
    ; \
    \
    # mbstringとopcacheはPHP 8.4公式イメージに含まれるため不要
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        intl \
        pdo_mysql \
        zip \
    ; \
    \
    # コンパイル用パッケージを最終イメージから削除
    apk del --no-network .php-ext-build-deps

RUN docker-php-ext-install pcntl

# Composerバイナリのみコピー
COPY --from=composer /composer /usr/local/bin/composer

COPY docker/app/php.ini /usr/local/etc/php/conf.d/99-household.ini

WORKDIR /var/www/html

CMD ["php-fpm"]