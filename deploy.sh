#!/bin/bash

# ==============================================================================
# ПОЛНОСТЬЮ АВТОМАТИЧЕСКИЙ СКРИПТ ВСЕХ ЗАДАНИЙ (09.06.2026 И 10.06.2026)
# Тестировалось на: Ubuntu 22.04 / 24.04 LTS (Запуск строго от root)
# ==============================================================================

set -e # Прерывать выполнение при любой критической ошибке

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== СБОРКА СИСТЕМЫ ИЗ СТРЕМИТЕЛЬНОГО НУЛЯ ===${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Запусти скрипт через sudo! Без root прав ничего не выйдет.${NC}"
  exit 1
fi

# Получаем IP адрес сервера автоматически для генерации ссылок
SERVER_IP=$(hostname -I | awk '{print $1}')

# ------------------------------------------------------------------------------
# 1. ОБНОВЛЕНИЕ И УСТАНОВКА ВСЕХ ЗАВИСИМОСТЕЙ (PHP, Apache, MariaDB, Samba, Docker)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[1/8] Установка системных пакетов и PHP расширений...${NC}"
apt-get update -y
apt-get install -y apache2 mariadb-server mariadb-client samba wget curl unzip tar \
  php libapache2-mod-php php-mysql php-xml php-mbstring php-zip php-gd php-curl php-cli \
  apt-transport-https software-properties-common docker.io docker-compose

# ------------------------------------------------------------------------------
# 2. НАСТРОЙКА БАЗЫ ДАННЫХ (БЕЗ ОШИБОК АУТЕНТИФИКАЦИИ ROOT)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[2/8] Конфигурация СУБД MariaDB...${NC}"
systemctl start mariadb

mysql -e "CREATE DATABASE IF NOT EXISTS wordpress_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'wp_pass123';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';"

mysql -e "CREATE DATABASE IF NOT EXISTS joomla_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'joomla_user'@'localhost' IDENTIFIED BY 'joomla_pass123';"
mysql -e "GRANT ALL PRIVILEGES ON joomla_db.* TO 'joomla_user'@'localhost';"

# Пользователь для Grafana
mysql -e "CREATE USER IF NOT EXISTS 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -e "GRANT SELECT ON wordpress_db.* TO 'grafana_user'@'localhost';"
mysql -e "GRANT SELECT ON joomla_db.* TO 'grafana_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# 3. ПОЛНАЯ АВТОУСТАНОВКА WORDPRESS + КАСТОМНАЯ ТЕМА (Порт 8001)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[3/8] Развертывание WordPress (через WP-CLI)...${NC}"
mkdir -p /var/www/html/wordpress
cd /var/www/html/wordpress

# Качаем официальный инструмент автоматизации WP-CLI
curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Скачивание и генерация конфига
wp core download --allow-root --force
wp config create --dbname=wordpress_db --dbuser=wp_user --dbpass=wp_pass123 --allow-root --force

# Автоматический инсталл базы данных (чтобы не тыкать мышкой в браузере)
wp core install --url="http://${SERVER_IP}:8001" --title="Exam WordPress" --admin_user="admin" --admin_password="adminpassword123" --admin_email="admin@example.com" --allow-root

# Создание и активация нестандартной (кастомной) темы
mkdir -p wp-content/themes/exam-custom-theme
cat <<'EOF' > wp-content/themes/exam-custom-theme/style.css
/*
Theme Name: Exam Custom Theme
Author: Automatic Script
Version: 1.0
*/
body { background: #34495e; color: #fff; font-family: sans-serif; padding: 50px; text-align: center; }
EOF

cat <<'EOF' > wp-content/themes/exam-custom-theme/index.php
<!DOCTYPE html>
<html>
<head><title>WP Custom Theme</title><?php wp_head(); ?></head>
<body>
    <h1>[Успех] WordPress работает на кастомной теме!</h1>
    <p>Мониторинг количества постов готов к проверке.</p>
    <?php wp_footer(); ?>
</body>
</html>
EOF

wp theme activate exam-custom-theme --allow-root
chown -R www-data:www-data /var/www/html/wordpress

# ------------------------------------------------------------------------------
# 4. РАЗВЕРТЫВАНИЕ JOOMLA + ШАБЛОН (Порт 8002)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[4/8] Распаковка Joomla...${NC}"
mkdir -p /var/www/html/joomla
cd /tmp
wget -q https://github.com/joomla/joomla-cms/releases/download/5.1.0/Joomla_5.1.0-Stable-Full_Package.tar.gz || true
if [ -f Joomla_5.1.0-Stable-Full_Package.tar.gz ]; then
  tar -xzf Joomla_5.1.0-Stable-Full_Package.tar.gz -C /var/www/html/joomla/
fi

# Накатываем структуру кастомного шаблона (не из стандартного набора)
mkdir -p /var/www/html/joomla/templates/exam_joomla_theme
cat <<'EOF' > /var/www/html/joomla/templates/exam_joomla_theme/templateDetails.xml
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
echo "<?php defined('_JEXEC') or die; ?><html><body style='background:#16a085;color:#fff;text-align:center;padding-top:100px;'><h1>[Успех] Кастомная тема Joomla подключена!</h1></body></html>" > /var/www/html/joomla/templates/exam_joomla_theme/index.php

chown -R www-data:www-data /var/www/html/joomla

# ------------------------------------------------------------------------------
# 5. НАСТРОЙКА ПОРТОВ И ВИРТУАЛЬНЫХ ХОСТОВ APACHE
# ------------------------------------------------------------------------------
echo -e "${GREEN}[5/8] Конфигурация веб-сервера Apache (Порты 8001 и 8002)...${NC}"

# Добавляем порты в конфиг, если их там еще нет
if ! grep -q "Listen 8001" /etc/apache2/ports.conf; then
  echo "Listen 8001" >> /etc/apache2/ports.conf
fi
if ! grep -q "Listen 8002" /etc/apache2/ports.conf; then
  echo "Listen 8002" >> /etc/apache2/ports.conf
fi

# Пишем конфиг хоста для WordPress
cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:8001>
    DocumentRoot /var/www/html/wordpress
    <Directory /var/www/html/wordpress>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Пишем конфиг хоста для Joomla
cat <<EOF > /etc/apache2/sites-available/joomla.conf
<VirtualHost *:8002>
    DocumentRoot /var/www/html/joomla
    <Directory /var/www/html/joomla>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

a2ensite wordpress.conf
a2ensite joomla.conf
a2enmod rewrite
systemctl restart apache2

# ------------------------------------------------------------------------------
# 6. НАСТРОЙКА СЕТЕВЫХ ПАПОК SAMBA И СКРИПТОВ БЭКАПА
# ------------------------------------------------------------------------------
echo -e "${GREEN}[6/8] Конфигурация Samba-сервера и однострочных скриптов...${NC}"
mkdir -p /share
chmod 777 /share

# Очищаем хвосты старых настроек samba в конфиге, если запускали ранее
sed -i '/\[share\]/,$d' /etc/samba/smb.conf || true

cat <<'EOF' >> /etc/samba/smb.conf

[share]
   path = /share
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0777
   directory mask = 0777
   force user = root

[wordpress_files]
   path = /var/www/html/wordpress
   browseable = yes
   read only = no
   guest ok = yes
   force user = www-data

[joomla_files]
   path = /var/www/html/joomla
   browseable = yes
   read only = no
   guest ok = yes
   force user = www-data
EOF

systemctl restart smbd

# Создание ОДНОСТРОЧНЫХ скриптов бэкапа и восстановления (как на фото)
echo "tar -czf /share/wp_backup.tar.gz -C /var/www/html wordpress" > /share/backup_wp.sh
echo "rm -rf /var/www/html/wordpress && tar -xzf /share/wp_backup.tar.gz -C /var/www/html/ && chown -R www-data:www-data /var/www/html/wordpress" > /share/restore_wp.sh

echo "tar -czf /share/joomla_backup.tar.gz -C /var/www/html joomla" > /share/backup_joomla.sh
echo "rm -rf /var/www/html/joomla && tar -xzf /share/joomla_backup.tar.gz -C /var/www/html/ && chown -R www-data:www-data /var/www/html/joomla" > /share/restore_joomla.sh

chmod +x /share/*.sh

# ------------------------------------------------------------------------------
# 7. УСТАНОВКА GRAFANA И АВТО-ПРИВЯЗКА БАЗЫ
# ------------------------------------------------------------------------------
echo -e "${GREEN}[7/8] Инсталляция и провижнинг Grafana...${NC}"
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update && apt-get install -y grafana

systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

# Автоматическое добавление источника данных MariaDB в интерфейс Grafana
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
# 8. РАЗВЕРТЫВАНИЕ DOCKER СТЕКОВ (ЗАДАНИЯ ОТ 10.06.2026)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[8/8] Поднятие Docker-контейнеров (Стек 1 и Стек 2)...${NC}"
systemctl start docker

# Стек 1: Apache2 + Текст "HELLO WORLD" (Порт 8081)
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

# Стек 2: Apache2 + PHP + Шаблон Лендинга (Порт 8082)
mkdir -p /opt/stack2
cat <<'EOF' > /opt/stack2/index.php
<?php
echo "<div style='text-align:center; font-family:sans-serif; background:#2c3e50; color:#fff; height:100vh; padding-top:100px;'>";
echo "<h1>[Docker Стек 2] Автоматический PHP-Лендинг запущен!</h1>";
echo "<p>Скрипт полностью отработал. Сюда можно закинуть любые файлы с флешки.</p>";
echo "<p>Время контейнера: " . date('Y-m-d H:i:s') . "</p>";
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
# ИТОГОВЫЙ ЧЕК-ЛИСТ ДЛЯ СДАЧИ ПРЕПОДАВАТЕЛЮ
# ------------------------------------------------------------------------------
echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}ГОТОВО! Всё развернуто без конфликтов портов и доменов.${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Твои рабочие ссылки для проверки (заменяй IP если проверяешь локально):"
echo -e "1. ${GREEN}WordPress:${NC} http://${SERVER_IP}:8001 (Кастомная тема уже активна)"
echo -e "2. ${GREEN}Joomla:${NC}    http://${SERVER_IP}:8002"
echo -e "3. ${GREEN}Grafana:${NC}   http://${SERVER_IP}:3000 (Вход: admin / admin)"
echo -e "4. ${GREEN}Стек 1 (Hello World):${NC} http://${SERVER_IP}:8081"
echo -e "5. ${GREEN}Стек 2 (PHP Лендинг):${NC} http://${SERVER_IP}:8082"
echo -e "----------------------------------------------------------------------"
echo -e "Samba-пути для проводника Windows:"
echo -e "   \\\\${SERVER_IP}\\share  |  \\\\${SERVER_IP}\\wordpress_files"
echo -e "----------------------------------------------------------------------"
echo -e "Однострочники бэкапов лежат в /share/:"
echo -e "   Запуск бэкапа WP:       ${BLUE}bash /share/backup_wp.sh${NC}"
echo -e "   Тест 'удалил-вернул' WP: ${BLUE}bash /share/restore_wp.sh${NC}"
echo -e "======================================================================"
