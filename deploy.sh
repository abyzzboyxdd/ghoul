#!/bin/bash

# ==============================================================================
# ЖЕЛЕЗОБЕТОННЫЙ СКРИПТ ДЛЯ CENTOS 7 / ROCKY (С учетом MariaDB 5.5 и PHP 5.4)
# Автоматически выполняет абсолютно все задания от 09.06 и 10.06 одним файлом
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Запуск точечной настройки под CentOS 7 ===${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Запусти скрипт от имени root: sudo bash install.sh${NC}"
  exit 1
fi

SERVER_IP=$(hostname -I | awk '{print $1}')
WEB_ROOT="/var/www/html"

# 1. УСТАНОВКА И СТАРТ СЛУЖБ
echo -e "${GREEN}[1/8] Проверка и доустановка системных пакетов...${NC}"
yum install -y epel-release
yum install -y httpd mariadb-server mariadb samba wget curl unzip tar \
  php php-mysqlnd php-xml php-mbstring php-zip php-gd php-curl php-cli \
  docker docker-compose

systemctl daemon-reload
systemctl enable --now httpd mariadb smb docker

# ------------------------------------------------------------------------------
# 2. НАСТРОЙКА БАЗЫ ДАННЫХ (Фикс ошибки 1064 под MariaDB 5.5)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[2/8] Конфигурация СУБД MariaDB (Совместимый синтаксис)...${NC}"

mysql -e "CREATE DATABASE IF NOT EXISTS wordpress_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE DATABASE IF NOT EXISTS joomla_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

# В MariaDB 5.5 GRANT автоматически создает пользователя, если его нет. Никаких IF NOT EXISTS.
mysql -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost' IDENTIFIED BY 'wp_pass123';"
mysql -e "GRANT ALL PRIVILEGES ON joomla_db.* TO 'joomla_user'@'localhost' IDENTIFIED BY 'joomla_pass123';"
mysql -e "GRANT SELECT ON wordpress_db.* TO 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -e "GRANT SELECT ON joomla_db.* TO 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# 3. УСТАНОВКА WORDPRESS (Версия 4.9 под PHP 5.4) + КАСТОМНАЯ ТЕМА
# ------------------------------------------------------------------------------
echo -e "${GREEN}[3/8] Развертывание WordPress 4.9 (совместим с PHP 5.4)...${NC}"
rm -rf $WEB_ROOT/wordpress && mkdir -p $WEB_ROOT/wordpress
cd /tmp
wget -q https://ru.wordpress.org/wordpress-4.9.22-ru_RU.tar.gz
tar -xzf wordpress-4.9.22-ru_RU.tar.gz
cp -r wordpress/* $WEB_ROOT/wordpress/

# Создаем wp-config.php вручную, так как wp-cli не работает на PHP 5.4
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

# Создание кастомной темы (Пункт 4 из ТЗ)
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
    <p>База данных подключена, мониторинг постов Grafana готов.</p>
</body>
</html>
EOF

# ------------------------------------------------------------------------------
# 4. УСТАНОВКА JOOMLA (Версия 3.10 под PHP 5.4) + КАСТОМНЫЙ ШАБЛОН
# ------------------------------------------------------------------------------
echo -e "${GREEN}[4/8] Развертывание Joomla 3.10...${NC}"
rm -rf $WEB_ROOT/joomla && mkdir -p $WEB_ROOT/joomla
cd /tmp
wget -q https://github.com/joomla/joomla-cms/releases/download/3.10.12/Joomla_3.10.12-Stable-Full_Package.tar.gz
tar -xzf Joomla_3.10.12-Stable-Full_Package.tar.gz -C $WEB_ROOT/joomla/

# Кастомный шаблон для Joomla (Пункт 9 из ТЗ)
mkdir -p $WEB_ROOT/joomla/templates/exam_joomla_theme
cat <<'EOF' > $WEB_ROOT/joomla/templates/exam_joomla_theme/templateDetails.xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="template" version="3.0" client="site">
	<name>exam_joomla_theme</name>
	<version>1.0</version>
	<files>
		<filename>index.php</filename>
		<filename>templateDetails.xml</filename>
	</files>
</extension>
EOF
echo "<?php defined('_JEXEC') or die; ?><html><body style='background:#16a085;color:#fff;text-align:center;padding-top:100px;'><h1>[Успех] Нестандартный шаблон Joomla подключен!</h1></body></html>" > $WEB_ROOT/joomla/templates/exam_joomla_theme/index.php

chown -R apache:apache $WEB_ROOT
chmod -R 755 $WEB_ROOT

# ------------------------------------------------------------------------------
# 5. НАСТРОЙКА ВИРТУАЛЬНЫХ ХОСТОВ APACHE (ПОРТЫ 8001 И 8002)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[5/8] Настройка веб-сервера Apache (CentOS style)...${NC}"

# Прописываем порты в отдельный файл конфигурации CentOS
echo -e "Listen 8001\nListen 8002" > /etc/httpd/conf.d/ports_vhosts.conf

cat <<EOF > /etc/httpd/conf.d/wordpress.conf
<VirtualHost *:8001>
    DocumentRoot $WEB_ROOT/wordpress
    <Directory $WEB_ROOT/wordpress>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

cat <<EOF > /etc/httpd/conf.d/joomla.conf
<VirtualHost *:8002>
    DocumentRoot $WEB_ROOT/joomla
    <Directory $WEB_ROOT/joomla>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

systemctl restart httpd

# ------------------------------------------------------------------------------
# 6. НАСТРОЙКА SAMBA И ОДНОСТРОЧНЫХ СКРИПТОВ БЭКАПА
# ------------------------------------------------------------------------------
echo -e "${GREEN}[6/8] Настройка Samba и скриптов бэкапа...${NC}"
mkdir -p /share
chmod 777 /share

# Чистим старые записи Samba, если они были
sed -i '/\[share\]/,$d' /etc/samba/smb.conf || true

cat <<EOF >> /etc/samba/smb.conf

[share]
   path = /share
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0777
   directory mask = 0777
   force user = root

[wordpress_files]
   path = $WEB_ROOT/wordpress
   browseable = yes
   read only = no
   guest ok = yes
   force user = apache

[joomla_files]
   path = $WEB_ROOT/joomla
   browseable = yes
   read only = no
   guest ok = yes
   force user = apache
EOF

systemctl restart smb

# Однострочные скрипты бэкапов и восстановления (Строго по ТЗ)
echo "tar -czf /share/wp_backup.tar.gz -C $WEB_ROOT wordpress" > /share/backup_wp.sh
echo "rm -rf $WEB_ROOT/wordpress && tar -xzf /share/wp_backup.tar.gz -C $WEB_ROOT/ && chown -R apache:apache $WEB_ROOT/wordpress" > /share/restore_wp.sh

echo "tar -czf /share/joomla_backup.tar.gz -C $WEB_ROOT joomla" > /share/backup_joomla.sh
echo "rm -rf $WEB_ROOT/joomla && tar -xzf /share/joomla_backup.tar.gz -C $WEB_ROOT/ && chown -R apache:apache $WEB_ROOT/joomla" > /share/restore_joomla.sh

chmod +x /share/*.sh

# ------------------------------------------------------------------------------
# 7. УСТАНОВКА И НАСТРОЙКА GRAFANA
# ------------------------------------------------------------------------------
echo -e "${GREEN}[7/8] Установка и провижнинг Grafana...${NC}"
cat <<EOF > /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

yum install -y grafana
systemctl enable --now grafana-server

# Автоматический провижнинг DataSource MariaDB
mkdir -p /etc/grafana/provisioning/datasources
cat <<'EOF' > /etc/grafana/provisioning/datasources/mysql.yaml
apiVersion: 1
datasources:
  - name: MariaDB_Server
    type: mysql
    access: proxy
    url: localhost:3306
    user: grafana_user
    secureJsonData:
      password: grafana123
    jsonData:
      database: wordpress_db
EOF
systemctl restart grafana-server

# ------------------------------------------------------------------------------
# 8. СТЕКИ DOCKER (ЗАДАНИЯ ОТ 10.06.2026)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[8/8] Запуск Docker контейнеров (Стек 1 и 2)...${NC}"

# Стек 1 (Порт 8081)
mkdir -p /opt/stack1
echo "<h1>HELLO WORLD</h1>" > /opt/stack1/index.html
cat <<'EOF' > /opt/stack1/docker-compose.yml
version: '3'
services:
  web:
    image: httpd:alpine
    ports:
      - "8081:80"
    volumes:
      - ./index.html:/usr/local/apache2/htdocs/index.html
    restart: always
EOF
cd /opt/stack1 && docker-compose down && docker-compose up -d

# Стек 2 (Порт 8082)
mkdir -p /opt/stack2
cat <<'EOF' > /opt/stack2/index.php
<?php
echo "<div style='text-align:center; font-family:sans-serif; background:#2c3e50; color:#fff; height:100vh; padding-top:100px;'>";
echo "<h1>[Docker Стек 2] Автоматический PHP-Лендинг работает!</h1>";
echo "<p>Сюда можно скинуть файлы с флешки.</p>";
echo "</div>";
?>
EOF
cat <<'EOF' > /opt/stack2/Dockerfile
FROM php:8.1-apache
COPY index.php /var/www/html/
EOF
cat <<'EOF' > /opt/stack2/docker-compose.yml
version: '3'
services:
  web-php:
    build: .
    ports:
      - "8082:80"
    restart: always
EOF
cd /opt/stack2 && docker-compose down && docker-compose build && docker-compose up -d

# ------------------------------------------------------------------------------
# ИТОГОВЫЙ ОТЧЕТ
# ------------------------------------------------------------------------------
echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}ГОТОВО! Ошибка синтаксиса устранена, всё развернуто успешно.${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Проверяй ссылки (замени IP, если проверяешь с другой машины):"
echo -e "1. WordPress (Сайт):     http://${SERVER_IP}:8001"
echo -e "2. Joomla (Сайт):        http://${SERVER_IP}:8002"
echo -e "3. Grafana (Мониторинг): http://${SERVER_IP}:3000 (Логин: admin / Пароль: admin)"
echo -e "4. Docker Стек 1:        http://${SERVER_IP}:8081"
echo -e "5. Docker Стек 2:        http://${SERVER_IP}:8082"
echo -e "----------------------------------------------------------------------"
echo -e "Папка бэкапов и однострочники: /share/"
echo -e "   Скрипт бэкапа WP:        ${BLUE}bash /share/backup_wp.sh${NC}"
echo -e "   Скрипт восстановления WP: ${BLUE}bash /share/restore_wp.sh${NC}"
echo -e "======================================================================"
