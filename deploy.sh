#!/bin/bash

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root (sudo)"
  exit 1
fi

echo "=== Шаг 1, 2, 3, 8: Обновление системы и установка пакетов ==="
apt update -y && apt upgrade -y
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-cli php-common php-xml php-mbstring php-zip php-gd php-curl wget unzip samba samba-common-bin

# Установка Grafana
apt install -y apt-transport-https software-properties-common
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt update -y && apt install -y grafana

# Запуск сервисов
systemctl enable --now apache2 mariadb grafana-server smbd

echo "=== Настройка баз данных ==="
# Настройка паролей (для демонстрации без пароля root, базы данных с доступами)
mysql -e "CREATE DATABASE IF NOT EXISTS wp_db;"
mysql -e "CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'wp_password';"
mysql -e "GRANT ALL PRIVILEGES ON wp_db.* TO 'wp_user'@'localhost';"

mysql -e "CREATE DATABASE IF NOT EXISTS joomla_db;"
mysql -e "CREATE USER IF NOT EXISTS 'joomla_user'@'localhost' IDENTIFIED BY 'joomla_password';"
mysql -e "GRANT ALL PRIVILEGES ON joomla_db.* TO 'joomla_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "=== Шаг 3: Установка WordPress ==="
mkdir -p /var/www/html/wordpress
wget -q https://wordpress.org/latest.tar.gz -O /tmp/wp.tar.gz
tar -xzf /tmp/wp.tar.gz -C /var/www/html/
cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
sed -i "s/database_name_here/wp_db/g" /var/www/html/wordpress/wp-config.php
sed -i "s/username_here/wp_user/g" /var/www/html/wordpress/wp-config.php
sed -i "s/password_here/wp_password/g" /var/www/html/wordpress/wp-config.php

echo "=== Шаг 4: Установка нестандартной темы на WP ==="
# Создаем структуру кастомной темы программно, чтобы не зависеть от внешних ссылок
mkdir -p /var/www/html/wordpress/wp-content/themes/custom-lab-theme
cat <<EOT > /var/www/html/wordpress/wp-content/themes/custom-lab-theme/style.css
/*
Theme Name: Custom Non-Standard Lab Theme
Author: Student
Version: 1.0
*/
EOT
touch /var/www/html/wordpress/wp-content/themes/custom-lab-theme/index.php

echo "=== Шаг 8: Установка Joomla ==="
mkdir -p /var/www/html/joomla
# Скачивание актуальной Joomla 5 (или подставьте нужную версию)
wget -q https://github.com/joomla/joomla-cms/releases/download/5.0.3/Joomla_5.0.3-Stable-Full_Package.zip -O /tmp/joomla.zip
unzip -q /tmp/joomla.zip -d /var/www/html/joomla/

echo "=== Шаг 9: Установка нестандартной темы на Joomla ==="
mkdir -p /var/www/html/joomla/templates/custom_joomla_template
cat <<EOT > /var/www/html/joomla/templates/custom_joomla_template/templateDetails.xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="template" version="3.0" client="site">
	<name>custom_joomla_template</name>
	<creationDate>2026</creationDate>
	<author>Student</author>
	<version>1.0</version>
</extension>
EOT
touch /var/www/html/joomla/templates/custom_joomla_template/index.php

# Права на веб-директории
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

echo "=== Шаг 5, 11: Интеграция источника данных MariaDB в Grafana ==="
mkdir -p /etc/grafana/provisioning/datasources/
cat <<EOT > /etc/grafana/provisioning/datasources/mysql.yaml
apiVersion: 1
datasources:
  - name: MariaDB-Local
    type: mysql
    url: localhost:3306
    database: wp_db
    user: root
    secureJsonData:
      password: ""
    jsonData:
      authenticationMethod: mysql_native_password
EOT
systemctl restart grafana-server

echo "=== Шаг 6, 12: Настройка SAMBA доступа ==="
# Добавление конфигурации в конец smb.conf
cat <<EOT >> /etc/samba/smb.conf

[wordpress]
   path = /var/www/html/wordpress
   browseable = yes
   writable = yes
   guest ok = yes
   force user = www-data

[joomla]
   path = /var/www/html/joomla
   browseable = yes
   writable = yes
   guest ok = yes
   force user = www-data
EOT

systemctl restart smbd

echo "=== Развертывание успешно завершено! ==="
echo "WordPress доступен: http://localhost/wordpress"
echo "Joomla доступна: http://localhost/joomla"
echo "Grafana доступна: http://localhost:3000"
