#!/bin/bash

# ==============================================================================
# УНИВЕРСАЛЬНЫЙ АВТОМАТИЧЕСКИЙ СКРИПТ (ДЛЯ UBUNTU / CENTOS / ROCKY / ALMA)
# Выполняет задания от 09.06.2026 и 10.06.2026 одним махом
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Определение операционной системы... ===${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Запусти скрипт от имени root (через sudo bash install.sh)${NC}"
  exit 1
fi

SERVER_IP=$(hostname -I | awk '{print $1}')

# Определение пакетного менеджера и дистрибутива
if command -v apt-get &> /dev/null; then
    PM="apt"
    echo -e "${GREEN}Обнаружена система на базе Debian/Ubuntu (APT)${NC}"
elif command -v dnf &> /dev/null; then
    PM="dnf"
    echo -e "${GREEN}Обнаружена система на базе RHEL/CentOS/Rocky (DNF)${NC}"
elif command -v yum &> /dev/null; then
    PM="yum"
    echo -e "${GREEN}Обнаружена система на базе RHEL/CentOS (YUM)${NC}"
else
    echo -e "${RED}Неизвестная ОС. Скрипт поддерживает только apt, dnf, yum.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. УСТАНОВКА ПАКЕТОВ ПОД НАШУ ОС
# ------------------------------------------------------------------------------
echo -e "${GREEN}[1/8] Установка зависимостей...${NC}"

if [ "$PM" = "apt" ]; then
    apt-get update -y
    apt-get install -y apache2 mariadb-server mariadb-client samba wget curl unzip tar \
      php libapache2-mod-php php-mysql php-xml php-mbstring php-zip php-gd php-curl php-cli \
      apt-transport-https software-properties-common docker.io docker-compose
    
    WEB_SVC="apache2"
    WEB_ROOT="/var/www/html"
    WEB_USER="www-data"
    CONF_DIR="/etc/apache2/sites-enabled"
    
    # Настройка портов для Ubuntu
    if ! grep -q "Listen 8001" /etc/apache2/ports.conf; then echo "Listen 8001" >> /etc/apache2/ports.conf; fi
    if ! grep -q "Listen 8002" /etc/apache2/ports.conf; then echo "Listen 8002" >> /etc/apache2/ports.conf; fi

else
    # Для CentOS / Rocky / Alma
    $PM install -y epel-release
    $PM install -y httpd mariadb-server mariadb samba wget curl unzip tar \
      php php-mysqlnd php-xml php-mbstring php-zip php-gd php-curl php-cli \
      docker docker-compose
    
    WEB_SVC="httpd"
    WEB_ROOT="/var/www/html"
    WEB_USER="apache"
    CONF_DIR="/etc/httpd/conf.d"
fi

# Включаем и запускаем базовые службы
systemctl daemon-reload
systemctl enable --now $WEB_SVC mariadb smb docker

# ------------------------------------------------------------------------------
# 2. НАСТРОЙКА БАЗЫ ДАННЫХ
# ------------------------------------------------------------------------------
echo -e "${GREEN}[2/8] Конфигурация СУБД MariaDB...${NC}"

mysql -e "CREATE DATABASE IF NOT EXISTS wordpress_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'wp_pass123';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';"

mysql -e "CREATE DATABASE IF NOT EXISTS joomla_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'joomla_user'@'localhost' IDENTIFIED BY 'joomla_pass123';"
mysql -e "GRANT ALL PRIVILEGES ON joomla_db.* TO 'joomla_user'@'localhost';"

mysql -e "CREATE USER IF NOT EXISTS 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -e "GRANT SELECT ON wordpress_db.* TO 'grafana_user'@'localhost';"
mysql -e "GRANT SELECT ON joomla_db.* TO 'grafana_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# 3. УСТАНОВКА WORDPRESS + КАСТОМНАЯ ТЕМА (Порт 8001)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[3/8] Развертывание WordPress...${NC}"
mkdir -p $WEB_ROOT/wordpress
cd $WEB_ROOT/wordpress

curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar

./wp-cli.phar core download --allow-root --force
./wp-cli.phar config create --dbname=wordpress_db --dbuser=wp_user --dbpass=wp_pass123 --allow-root --force
./wp-cli.phar core install --url="http://${SERVER_IP}:8001" --title="Exam WordPress" --admin_user="admin" --admin_password="adminpassword123" --admin_email="admin@example.com" --allow-root

# Создание нестандартной темы
mkdir -p wp-content/themes/exam-custom-theme
cat <<'EOF' > wp-content/themes/exam-custom-theme/style.css
/*
Theme Name: Exam Custom Theme
Author: Auto Script
Version: 1.0
*/
body { background: #34495e; color: #fff; font-family: sans-serif; padding: 50px; text-align: center; }
EOF

cat <<'EOF' > wp-content/themes/exam-custom-theme/index.php
<!DOCTYPE html>
<html>
<head><title>WP Custom Theme</title><?php wp_head(); ?></head>
<body>
    <h1>[Успех] WordPress запущен на кастомной теме!</h1>
    <p>Система мониторинга готова считывать данные.</p>
    <?php wp_footer(); ?>
</body>
</html>
EOF

./wp-cli.phar theme activate exam-custom-theme --allow-root
rm -f wp-cli.phar

# ------------------------------------------------------------------------------
# 4. УСТАНОВКА JOOMLA + ШАБЛОН (Порт 8002)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[4/8] Подготовка файлов Joomla...${NC}"
mkdir -p $WEB_ROOT/joomla
cd /tmp
wget -q https://github.com/joomla/joomla-cms/releases/download/5.1.0/Joomla_5.1.0-Stable-Full_Package.tar.gz || true
if [ -f Joomla_5.1.0-Stable-Full_Package.tar.gz ]; then
  tar -xzf Joomla_5.1.0-Stable-Full_Package.tar.gz -C $WEB_ROOT/joomla/
fi

# Кастомный шаблон для Joomla
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

chown -R $WEB_USER:$WEB_USER $WEB_ROOT

# ------------------------------------------------------------------------------
# 5. НАСТРОЙКА ВИРТУАЛЬНЫХ ХОСТОВ APACHE (ПОРТЫ 8001 И 8002)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[5/8] Настройка веб-сервера под порты сайтов...${NC}"

# Для RedHat систем явно прописываем Listen в vhost, если это не Ubuntu
if [ "$PM" != "apt" ]; then
    echo "Listen 8001" > $CONF_DIR/ports_wp.conf
    echo "Listen 8002" > $CONF_DIR/ports_joomla.conf
fi

cat <<EOF > $CONF_DIR/wordpress.conf
<VirtualHost *:8001>
    DocumentRoot $WEB_ROOT/wordpress
    <Directory $WEB_ROOT/wordpress>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

cat <<EOF > $CONF_DIR/joomla.conf
<VirtualHost *:8002>
    DocumentRoot $WEB_ROOT/joomla
    <Directory $WEB_ROOT/joomla>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

systemctl restart $WEB_SVC

# ------------------------------------------------------------------------------
# 6. НАСТРОЙКА SAMBA И СКРИПТОВ БЭКАПА
# ------------------------------------------------------------------------------
echo -e "${GREEN}[6/8] Настройка Samba и однострочников бэкапа...${NC}"
mkdir -p /share
chmod 777 /share

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
   force user = $WEB_USER

[joomla_files]
   path = $WEB_ROOT/joomla
   browseable = yes
   read only = no
   guest ok = yes
   force user = $WEB_USER
EOF

# Перезапуск службы Samba в зависимости от ОС
if [ "$PM" = "apt" ]; then systemctl restart smbd; else systemctl restart smb; fi

# Однострочные скрипты бэкапов (Пункт 7 и 13)
echo "tar -czf /share/wp_backup.tar.gz -C $WEB_ROOT wordpress" > /share/backup_wp.sh
echo "rm -rf $WEB_ROOT/wordpress && tar -xzf /share/wp_backup.tar.gz -C $WEB_ROOT/ && chown -R $WEB_USER:$WEB_USER $WEB_ROOT/wordpress" > /share/restore_wp.sh

echo "tar -czf /share/joomla_backup.tar.gz -C $WEB_ROOT joomla" > /share/backup_joomla.sh
echo "rm -rf $WEB_ROOT/joomla && tar -xzf /share/joomla_backup.tar.gz -C $WEB_ROOT/ && chown -R $WEB_USER:$WEB_USER $WEB_ROOT/joomla" > /share/restore_joomla.sh

chmod +x /share/*.sh

# ------------------------------------------------------------------------------
# 7. УСТАНОВКА GRAFANA
# ------------------------------------------------------------------------------
echo -e "${GREEN}[7/8] Установка Grafana...${NC}"
if [ "$PM" = "apt" ]; then
    mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update && apt-get install -y grafana
else
    cat <<EOF > /etc/yum.repos.get.d/grafana.repo
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
    $PM install -y grafana
fi

systemctl enable --now grafana-server

# Авто-подключение базы к Grafana
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
echo -e "${GREEN}[8/8] Развертывание Docker контейнеров...${NC}"

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
echo "<h1>[Docker Стек 2] Автоматический PHP-Лендинг запущен успешно!</h1>";
echo "<p>Сюда можно подкинуть любой ваш код из флешки.</p>";
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
# ФИНАЛ
# ------------------------------------------------------------------------------
echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}ВСЁ УСПЕШНО РАЗВЕРНУТО! Проверяй ссылки ниже:${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "1. WordPress:         http://${SERVER_IP}:8001"
echo -e "2. Joomla:            http://${SERVER_IP}:8002"
echo -e "3. Grafana (Админка): http://${SERVER_IP}:3000 (Логин: admin / Пароль: admin)"
echo -e "4. Docker Стек 1:     http://${SERVER_IP}:8081"
echo -e "5. Docker Стек 2:     http://${SERVER_IP}:8082"
echo -e "----------------------------------------------------------------------"
echo -e "Скрипты бэкапов лежат в папке /share/"
echo -e "Запуск бэкапа WP:        ${BLUE}bash /share/backup_wp.sh${NC}"
echo -e "Проверка восстановления:  ${BLUE}bash /share/restore_wp.sh${NC}"
echo -e "======================================================================"
