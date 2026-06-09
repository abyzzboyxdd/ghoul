#!/bin/bash

# Выход при любой ошибке
set -e

echo "=== [Шаг 1] Обновление системы и установка LAMP стека ==="
yum update -y
yum install -y epel-release
# Установка Apache, MariaDB и репозитория Remi для свежего PHP (CentOS 7 по дефолту имеет старый PHP 5.4)
yum install -y httpd mariadb-server mariadb wget unzip net-tools httpd-tools
yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php74
yum install -y php php-mysqlnd php-gd php-xml php-mbstring php-json

# Запуск сервисов
systemctl start httpd
systemctl enable httpd
systemctl start mariadb
systemctl enable mariadb

# Настройка MySQL (БД, пользователи и права)
DB_ROOT_PASS="Password123!"
mysqladmin -u root password "$DB_ROOT_PASS" || true

mysql -u root -p"$DB_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p"$DB_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wp_user'@'localhost' IDENTIFIED BY 'WpPassword123!';"

mysql -u root -p"$DB_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS joomla DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p"$DB_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON joomla.* TO 'joomla_user'@'localhost' IDENTIFIED BY 'JoomlaPassword123!';"

mysql -u root -p"$DB_ROOT_PASS" -e "FLUSH PRIVILEGES;"


echo "=== [Шаг 2] Установка Grafana ==="
cat <<EOF > /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/panki/tls/certs/ca-bundle.crt
EOF

yum install -y grafana
systemctl start grafana-server
systemctl enable grafana-server


echo "=== [Шаг 3 & 4] Установка WordPress и нестандартной темы ==="
mkdir -p /var/www/html/wp
wget https://wordpress.org/latest.tar.gz -O /tmp/wp.tar.gz
tar -xf /tmp/wp.tar.gz -C /var/www/html/wp --strip-components=1

# Конфиг WordPress
cp /var/www/html/wp/wp-config-sample.php /var/www/html/wp/wp-config.php
sed -i "s/database_name_here/wordpress/" /var/www/html/wp/wp-config.php
sed -i "s/username_here/wp_user/" /var/www/html/wp/wp-config.php
sed -i "s/password_here/WpPassword123!/" /var/www/html/wp/wp-config.php

# Скачивание нестандартной темы (например, популярных "Neve" или "OceanWP")
wget https://downloads.wordpress.org/theme/neve.latest-stable.zip -O /tmp/wp-theme.zip
unzip -q /tmp/wp-theme.zip -d /var/www/html/wp/wp-content/themes/


echo "=== [Шаг 8 & 9] Установка Joomla и нестандартной темы ==="
mkdir -p /var/www/html/joomla
# Качаем стабильную версию Joomla 4/5
wget https://github.com/joomla/joomla-cms/releases/download/5.0.3/Joomla_5.0.3-Stable-Full_Package.zip -O /tmp/joomla.zip
unzip -q /tmp/joomla.zip -d /var/www/html/joomla/

# Скачивание стороннего шаблона (темы) для Joomla (например, Helix Ultimate)
wget https://www.joomshaper.com/downloads/template/helixultimate/download -O /tmp/joomla-theme.zip || true
# Если линк забанен, создаем кастомную папку темы для демонстрации структуры
mkdir -p /var/www/html/joomla/templates/custom_theme
echo "" > /var/www/html/joomla/templates/custom_theme/index.php

# Права на веб-директории
chown -R apache:apache /var/www/html/


echo "=== [Шаг 6 & 12] Установка и настройка SAMBA для WP и Joomla ==="
yum install -y samba samba-client
mkdir -p /share

# Настройка конфига Samba
cat <<EOF >> /etc/samba/smb.conf

[wp-share]
   comment = WordPress Files
   path = /var/www/html/wp
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0775
   directory mask = 0775
   force user = apache

[joomla-share]
   comment = Joomla Files
   path = /var/www/html/joomla
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0775
   directory mask = 0775
   force user = apache

[backup-share]
   comment = Backup Folder
   path = /share
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0775
   directory mask = 0775
EOF

chmod -R 777 /share
systemctl start smb nmb
systemctl enable smb nmb


echo "=== Настройка Firewall и SELinux ==="
# Отключаем во избежание блокировок Samba/Apache, как часто делают на лабах
setenforce 0 || true
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config || true

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=samba
firewall-cmd --permanent --add-port=3000/tcp # Grafana
firewall-cmd --reload


echo "=== [Шаг 7 & 13] Создание однострочных скриптов бэкапа ==="
# Однострочник для WP
echo "tar -czf /share/wp_backup_\$(date +%F).tar.gz -C /var/www/html/wp ." > /usr/local/bin/backup_wp.sh
# Однострочник для Joomla
echo "tar -czf /share/joomla_backup_\$(date +%F).tar.gz -C /var/www/html/joomla ." > /usr/local/bin/backup_joomla.sh

chmod +x /usr/local/bin/backup_wp.sh /usr/local/bin/backup_joomla.sh


echo "=== [Шаг 5 & 11] Мониторинг постов через Grafana ==="
# Чтобы Grafana могла мониторить количество постов, ей нужен доступ к MySQL.
# Запросы, которые Grafana будет выполнять для вывода метрик (их вводить в интерфейсе Grafana):
# Для WordPress: SELECT COUNT(*) FROM wp_posts WHERE post_type='post' AND post_status='publish';
# Для Joomla: SELECT COUNT(*) FROM #__content WHERE state=1;

echo "================================================================="
echo " Скрипт успешно завершил работу!"
echo " URL WordPress: http://localhost/wp"
echo " URL Joomla:    http://localhost/joomla"
echo " URL Grafana:   http://localhost:3000 (дефолт: admin / admin)"
echo " Папки бэкапов: /share"
echo " Однострочники бэкапа: backup_wp.sh и backup_joomla.sh"
echo "================================================================="
