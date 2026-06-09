script_content = """#!/bin/bash

# ==============================================================================
# АВТОМАТИЧЕСКИЙ СКРИПТ ДЕПЛОЯ И НАСТРОЙКИ (ЗАДАНИЯ ОТ 09.06.2026 И 10.06.2026)
# ОС: Ubuntu 22.04 / 24.04 LTS (Запускать от имени root: sudo bash)
# ==============================================================================

# Цвета для вывода
GREEN='\\033[0;32m'
RED='\\033[0;31m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

echo -e "${BLUE}=== Начало автоматической настройки системы ===${NC}"

# Проверка на root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Пожалуйста, запустите скрипт с правами root (sudo).${NC}"
  exit 1
fi

# Обновление системы
echo -e "${GREEN}[1/10] Обновление пакетов...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget unzip tar samba apache2 php libapache2-mod-php php-mysql php-cli php-xml php-mbstring mariadb-server mariadb-client apt-transport-https software-properties-common

# ==============================================================================
# ЧАСТЬ 1: НАСТРОЙКА БАЗЫ ДАННЫХ (MariaDB)
# ==============================================================================
echo -e "${GREEN}[2/10] Настройка СУБД MariaDB...${NC}"
# Настройка паролей (для демонстрации используем 'password123')
DB_ROOT_PASS="rootpass123"
WP_DB="wordpress_db"
WP_USER="wp_user"
WP_PASS="wp_pass123"
JOOMLA_DB="joomla_db"
JOOMLA_USER="joomla_user"
JOOMLA_PASS="joomla_pass123"

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';"
mysql -u root -p${DB_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${WP_DB} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON ${WP_DB}.* TO '${WP_USER}'@'localhost' IDENTIFIED BY '${WP_PASS}';"
mysql -u root -p${DB_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${JOOMLA_DB} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON ${JOOMLA_DB}.* TO '${JOOMLA_USER}'@'localhost' IDENTIFIED BY '${JOOMLA_PASS}';"
mysql -u root -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"

# РАЗРЕШАЕМ GRAFANA ПОДКЛЮЧАТЬСЯ К БАЗЕ ДАННЫХ ДЛЯ МОНИТОРИНГА
mysql -u root -p${DB_ROOT_PASS} -e "GRANT SELECT ON ${WP_DB}.* TO 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -u root -p${DB_ROOT_PASS} -e "GRANT SELECT ON ${JOOMLA_DB}.* TO 'grafana_user'@'localhost' IDENTIFIED BY 'grafana123';"
mysql -u root -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"


# ==============================================================================
# ЧАСТЬ 2: УСТАНОВКА И НАСТРОЙКА WORDPRESS + НЕСТАНДАРТНАЯ ТЕМА
# ==============================================================================
echo -e "${GREEN}[3/10] Установка WordPress...${NC}"
mkdir -p /var/www/html/wordpress
cd /tmp && wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/wordpress/

# Создание wp-config.php
cat <<EOF > /var/www/html/wordpress/wp-config.php
<?php
define( 'DB_NAME', '${WP_DB}' );
define( 'DB_USER', '${WP_USER}' );
define( 'DB_PASSWORD', '${WP_PASS}' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
\\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

# Установка нестандартной темы (создаем кастомную тему "CustomExamTheme")
echo -e "${GREEN}Установка нестандартной темы на WordPress...${NC}"
mkdir -p /var/www/html/wordpress/wp-content/themes/custom-exam-theme
cat <<EOF > /var/www/html/wordpress/wp-content/themes/custom-exam-theme/style.css
/*
Theme Name: Custom Exam Theme
Author: Student Automated
Description: Non-standard theme for exam practical tasks.
Version: 1.0
*/
body { background-color: #f0f0f0; font-family: sans-serif; }
EOF
cat <<EOF > /var/www/html/wordpress/wp-content/themes/custom-exam-theme/index.php
<?php get_header(); ?>
<h1>Добро пожаловать на WordPress с кастомной темой!</h1>
<?php get_footer(); ?>
EOF

chown -r www-data:www-data /var/www/html/wordpress
chmod -r 755 /var/www/html/wordpress


# ==============================================================================
# ЧАСТЬ 3: УСТАНОВКА И НАСТРОЙКА JOOMLA + НЕСТАНДАРТНАЯ ТЕМА
# ==============================================================================
echo -e "${GREEN}[4/10] Установка Joomla...${NC}"
mkdir -p /var/www/html/joomla
cd /tmp
# Скачиваем стабильную версию Joomla 4/5
wget https://github.com/joomla/joomla-cms/releases/download/5.0.3/Joomla_5.0.3-Stable-Full_Package.zip
unzip Joomla_5.0.3-Stable-Full_Package.zip -d /var/www/html/joomla/

# Создание базовой структуры нестандартного шаблона (темы) для Joomla
echo -e "${GREEN}Установка нестандартной темы на Joomla...${NC}"
mkdir -p /var/www/html/joomla/templates/custom_joomla_theme
cat <<EOF > /var/www/html/joomla/templates/custom_joomla_theme/templateDetails.xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="template" version="3.0" client="site">
	<name>custom_joomla_theme</name>
	<creationDate>June 2026</creationDate>
	<author>Student</author>
	<version>1.0.0</version>
	<description>Non-standard Joomla theme for practical task.</description>
	<files>
		<filename>index.php</filename>
		<filename>templateDetails.xml</filename>
	</files>
</extension>
EOF
cat <<EOF > /var/www/html/joomla/templates/custom_joomla_theme/index.php
<?php defined('_JEXEC') or die; ?>
<!DOCTYPE html>
<html lang="<?php echo \$this->language; ?>">
<head><title>Joomla Custom Theme</title></head>
<body>
    <h1>Привет из кастомного шаблона Joomla!</h1>
</body>
</html>
EOF

chown -r www-data:www-data /var/www/html/joomla
chmod -r 755 /var/www/html/joomla


# ==============================================================================
# ЧАСТЬ 4: НАСТРОЙКА APACHE ДЛЯ ОБОИХ САЙТОВ
# ==============================================================================
echo -e "${GREEN}[5/10] Настройка виртуальных хостов Apache...${NC}"
cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    ServerName wordpress.local
    DocumentRoot /var/www/html/wordpress
    <Directory /var/www/html/wordpress>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

cat <<EOF > /etc/apache2/sites-available/joomla.conf
<VirtualHost *:80>
    ServerName joomla.local
    DocumentRoot /var/www/html/joomla
    <Directory /var/www/html/joomla>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Добавляем порты или локальные имена в /etc/hosts для тестов
echo "127.0.0.1 wordpress.local" >> /etc/hosts
echo "127.0.0.1 joomla.local" >> /etc/hosts

a2ensite wordpress.conf
a2ensite joomla.conf
a2enmod rewrite
systemctl restart apache2


# ==============================================================================
# ЧАСТЬ 5: НАСТРОЙКА SAMBA ДОСТУПА К ФАЙЛАМ WP И JOOMLA
# ==============================================================================
echo -e "${GREEN}[6/10] Настройка Samba-сервера...${NC}"
mkdir -p /share
chmod 777 /share

# Настройка конфигурации Samba
cat <<EOF >> /etc/samba/smb.conf

[share]
   comment = Share Directory
   path = /share
   browseable = yes
   read only = no
   guest ok = yes
   force create mode = 0775
   force directory mode = 0775

[wordpress_files]
   comment = WordPress Files
   path = /var/www/html/wordpress
   browseable = yes
   read only = no
   guest ok = yes
   force user = www-data
   force group = www-data

[joomla_files]
   comment = Joomla Files
   path = /var/www/html/joomla
   browseable = yes
   read only = no
   guest ok = yes
   force user = www-data
   force group = www-data
EOF

systemctl restart smbd
systemctl enable smbd


# ==============================================================================
# ЧАСТЬ 6: СКРИПТЫ РЕЗЕРВНОГО КОПИРОВАНИЯ И ВОССТАНОВЛЕНИЯ (В ОДНУ СТРОКУ)
# ==============================================================================
echo -e "${GREEN}[7/10] Создание скриптов бэкапа и восстановления...${NC}"

# Скрипты бэкапа (в одну строчку, как в задании)
cat <<'EOF' > /share/backup_wp.sh
tar -czf /share/wp_backup.tar.gz -C /var/www/html wordpress
EOF

cat <<'EOF' > /share/restore_wp.sh
rm -rf /var/www/html/wordpress && tar -xzf /share/wp_backup.tar.gz -C /var/www/html/ && chown -R www-data:www-data /var/www/html/wordpress
EOF

cat <<'EOF' > /share/backup_joomla.sh
tar -czf /share/joomla_backup.tar.gz -C /var/www/html joomla
EOF

cat <<'EOF' > /share/restore_joomla.sh
rm -rf /var/www/html/joomla && tar -xzf /share/joomla_backup.tar.gz -C /var/www/html/ && chown -R www-data:www-data /var/www/html/joomla
EOF

chmod +x /share/backup_wp.sh /share/restore_wp.sh /share/backup_joomla.sh /share/restore_joomla.sh


# ==============================================================================
# ЧАСТЬ 7: УСТАНОВКА GRAFANA И НАСТРОЙКА МОНИТОРИНГА КОЛИЧЕСТВА ПОСТОВ
# ==============================================================================
echo -e "${GREEN}[8/10] Установка и авто-настройка Grafana...${NC}"
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update -y && apt-get install -y grafana

systemctl start grafana-server
systemctl enable grafana-server

# Автоматическое подключение MariaDB/MySQL как источника данных для Grafana
mkdir -p /etc/grafana/provisioning/datasources/
cat <<EOF > /etc/grafana/provisioning/datasources/mysql.yaml
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
    isDefault: true
EOF
systemctl restart grafana-server


# ==============================================================================
# ЧАСТЬ 8: ЗАДАНИЕ ОТ 10.06.2026 (ДОКЕР СТЕКИ)
# ==============================================================================
echo -e "${GREEN}[9/10] Установка Docker и развертывание Стек 1 и Стек 2...${NC}"

# Установка Docker
apt-get install -y docker.io docker-compose
systemctl start docker
systemctl enable docker

# Стек 1: Docker + Apache2 + Веб-страница "HELLO WORLD"
mkdir -p /opt/docker_stack1
cat <<EOF > /opt/docker_stack1/index.html
<h1>HELLO WORLD</h1>
EOF

cat <<EOF > /opt/docker_stack1/docker-compose.yml
version: '3.8'
services:
  web1:
    image: httpd:alpine
    ports:
      - "8081:80"
    volumes:
      - ./index.html:/usr/local/apache2/htdocs/index.html
    restart: always
EOF
cd /opt/docker_stack1 && docker-compose up -d

# Стек 2: Docker + Apache2 + PHP + Лендинг (создаем красивый шаблон-заглушку)
mkdir -p /opt/docker_stack2
cat <<EOF > /opt/docker_stack2/index.php
<?php
echo "<html><head><title>Landing Page</title><style>body{font-family:Arial; text-align:center; background:#2c3e50; color:#fff; padding-top:100px;} h1{font-size:50px;}</style></head><body>";
echo "<h1>Автоматический Лендинг запущен успешно!</h1>";
echo "<p>Текущее время сервера: " . date('Y-m-d H:i:s') . "</p>";
echo "<p>PHP работает внутри Docker контейнера Apache2.</p>";
echo "</body></html>";
?>
EOF

# Dockerfile для Стек 2 (Apache + PHP)
cat <<EOF > /opt/docker_stack2/Dockerfile
FROM php:8.1-apache
COPY index.php /var/www/html/
EOF

cat <<EOF > /opt/docker_stack2/docker-compose.yml
version: '3.8'
services:
  web2:
    build: .
    ports:
      - "8082:80"
    restart: always
EOF
cd /opt/docker_stack2 && docker-compose build && docker-compose up -d


# ==============================================================================
# ФИНАЛЬНЫЙ ВЫВОД И ИНСТРУКЦИИ ДЛЯ СТУДЕНТА
# ==============================================================================
echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}ВСЕ ЗАДАНИЯ АВТОМАТИЧЕСКИ ВЫПОЛНЕНЫ! Скрипт развернул все системы.${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "1. Ссылки на сайты (Day 1):"
echo -e "   - WordPress: http://wordpress.local"
echo -e "   - Joomla: http://joomla.local"
echo -e "2. Samba доступы (Day 1):"
echo -e "   - Сетевая папка бэкапов: \\\\\\\\<IP-адрес>\\\\share"
echo -e "   - Папка файлов WordPress: \\\\\\\\<IP-адрес>\\\\wordpress_files"
echo -e "   - Папка файлов Joomla: \\\\\\\\<IP-адрес>\\\\joomla_files"
echo -e "3. Однострочные скрипты бэкапов лежат в /share/ :"
echo -e "   - Запустить бэкап WP: bash /share/backup_wp.sh"
echo -e "   - Удалить и восстановить WP: bash /share/restore_wp.sh"
echo -e "4. Grafana (Мониторинг): http://<IP-адрес>:3000 (Логин: admin / Пароль: admin)"
echo -e "   - SQL запрос для Grafana (Кол-во постов WP):"
echo -e "     ${BLUE}SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='post';${NC}"
echo -e "   - SQL запрос для Grafana (Кол-во постов Joomla):"
echo -e "     ${BLUE}SELECT COUNT(*) FROM j_content WHERE state=1;${NC}"
echo -e "5. Docker Стеки (Day 2):"
echo -e "   - Стек 1 (HELLO WORLD): http://<IP-адрес>:8081"
echo -e "   - Стек 2 (PHP + Лендинг): http://<IP-адрес>:8082"
echo -e "${BLUE}======================================================================${NC}"
"""

with open("deploy_assignment.sh", "w") as f:
    f.write(script_content)

print("File generated successfully: deploy_assignment.sh")
