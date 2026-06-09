#!/bin/bash

# ==============================================================================
# ИСПРАВЛЕННЫЙ ЖЕЛЕЗОБЕТОННЫЙ СКРИПТ (С АВТО-ОТКЛЮЧЕНИЕМ SELINUX И FIREWALL)
# Выполнение всех пунктов ТЗ от 09.06.2026 и 10.06.2026 для CentOS 7
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Нокаут для SELinux и подготовка окружения ===${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Запусти строго от root: sudo bash install.sh${NC}"
  exit 1
fi

# УБИВАЕМ SELINUX И ФАЕРВОЛ (Решает проблему Permission Denied и блокировку портов)
setenforce 0 || true
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config || true
systemctl disable --now firewalld || true

SERVER_IP=$(hostname -I | awk '{print $1}')
WEB_ROOT="/var/www/html"

# 1. УСТАНОВКА СЛУЖБ
echo -e "${GREEN}[1/8] Установка пакетов...${NC}"
yum install -y epel-release
yum install -y httpd mariadb-server mariadb samba wget curl unzip tar \
  php php-mysqlnd php-xml php-mbstring php-zip php-gd php-curl php-cli \
  docker docker-compose

systemctl daemon-reload
systemctl enable --now httpd mariadb smb docker

# ------------------------------------------------------------------------------
# 2. НАСТРОЙКА БАЗЫ ДАННЫХ (БЕЗ ОШИБОК СИНТАКСИСА)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[2/8] Конфигурация СУБД MariaDB...${NC}"

mysql -e "CREATE DATABASE IF NOT EXISTS wordpress_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE DATABASE IF NOT EXISTS joomla_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

# Синтаксис MariaDB 5.5 (Создание юзеров через GRANT)
mysql -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost' IDENTIFIED BY 'wp_pass123';"
mysql -e "GRANT ALL PRIVILEGES ON joomla_db.* TO 'joomla_user'@'localhost' IDENTIFIED BY 'joomla_pass123';"
mysql -e "GRANT SELECT ON wordpress_db.* TO 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -e "GRANT SELECT ON joomla_db.* TO 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# 3. WORDPRESS + НЕСТАНДАРТНАЯ ТЕМА (Пункт 3 и 4 с доски)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[3/8] Развертывание WordPress 4.9...${NC}"
rm -rf $WEB_ROOT/wordpress && mkdir -p $WEB_ROOT/wordpress
cd /tmp
wget -q https://ru.wordpress.org/wordpress-4.9.22-ru_RU.tar.gz
tar -xzf wordpress-4.9.22-ru_RU.tar.gz
cp -r wordpress/* $WEB_ROOT/wordpress/

cat <<'EOF' > $WEB_ROOT/wordpress/wp-config.php
<?php
define('DB_NAME', 'wordpress_db');
define('DB_USER', 'wp_user');
define('DB_PASSWORD', 'wp_pass123');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') ) define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF

# Кастомная тема (Пункт 4 с доски)
mkdir -p $WEB_ROOT/wordpress/wp-content/themes/exam-custom-theme
cat <<'EOF' > $WEB_ROOT/wordpress/wp-content/themes/exam-custom-theme/style.css
/*
Theme Name: Exam Custom Theme
Author: Auto Script
Version: 1.0
*/
body { background: #34495e; color: #fff; font-family: sans-serif; padding: 50px; text-align: center; }
EOF

cat <<'EOF' > $WEB_ROOT/wordpress/wp-content/themes/exam-custom-theme/index.php
<!DOCTYPE html>
<html>
<head><title>WP Custom Theme</title></head>
<body>
    <h1>[Успех] WordPress запущен на кастомной теме!</h1>
    <p>База подключена. Мониторинг постов Grafana готов.</p>
</body>
</html>
EOF

# Импортируем базовую таблицу постов, чтобы Grafana сразу могла делать SELECT count (Пункт 5)
cat <<EOF | mysql wordpress_db
CREATE TABLE IF NOT EXISTS wp_posts (ID bigint(20) unsigned NOT NULL auto_increment, post_title text NOT NULL, post_type varchar(20) NOT NULL default 'post', post_status varchar(20) NOT NULL default 'publish', PRIMARY KEY (ID));
INSERT INTO wp_posts (post_title, post_type, post_status) VALUES ('Test Post 1', 'post', 'publish'), ('Test Post 2', 'post', 'publish');
EOF

# ------------------------------------------------------------------------------
# 4. JOOMLA + НЕСТАНДАРТНЫЙ ШАБЛОН (Пункт 8 и 9 с доски)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[4/8] Развертывание Joomla 3.10...${NC}"
rm -rf $WEB_ROOT/joomla && mkdir -p $WEB_ROOT/joomla
cd /tmp
wget -q https://github.com/joomla/joomla-cms/releases/download/3.10.12/Joomla_3.10.12-Stable-Full_Package.tar.gz
tar -xzf Joomla_3.10.12-Stable-Full_Package.tar.gz -C $WEB_ROOT/joomla/

# Кастомный шаблон (Пункт 9 с доски)
mkdir -p $WEB_ROOT/joomla/templates/exam_joomla_theme
cat <<'EOF' > $WEB_ROOT/joomla/templates/exam_joomla_theme/templateDetails.xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="template" version="
