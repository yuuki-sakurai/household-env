CREATE DATABASE IF NOT EXISTS kakeibo
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'app_user'@'%'
    IDENTIFIED BY 'app_password';

GRANT ALL PRIVILEGES ON kakeibo.* TO 'app_user'@'%';

FLUSH PRIVILEGES;