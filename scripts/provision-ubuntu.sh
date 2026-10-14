#!/usr/bin/env bash
# 一次性初始化：在全新的 Ubuntu 24.04 服务器（阿里云 ECS）上准备联思官网的运行环境。
# 以 root 运行，可重复执行。
# 安装：Nginx、PHP 8.3-FPM、MariaDB、防火墙、2G Swap、自动安全更新，
# 并创建部署用户 deploy、站点目录、数据库和 Nginx 站点配置。
# wp-cli 不在这里安装：中国大陆服务器访问不了 GitHub，由本机下载校验后上传到 /usr/local/bin/wp。
set -euo pipefail

SITE_USER=deploy
SITE_DIR=/var/www/liansi
DB_NAME=liansi
DB_USER=liansi
PHP_V=8.3
export DEBIAN_FRONTEND=noninteractive

timedatectl set-timezone Asia/Shanghai

# 2G swap: the 2 GB instance has no swap, and MariaDB is the first thing the OOM killer takes.
if ! swapon --show | grep -q '^/swapfile'; then
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
echo 'vm.swappiness=10' > /etc/sysctl.d/99-liansi.conf
sysctl -q --system

apt-get update -q
apt-get -y -q upgrade
apt-get -y -q install \
	nginx mariadb-server \
	php${PHP_V}-fpm php${PHP_V}-mysql php${PHP_V}-curl php${PHP_V}-gd php${PHP_V}-intl \
	php${PHP_V}-mbstring php${PHP_V}-xml php${PHP_V}-zip php${PHP_V}-bcmath php${PHP_V}-imagick \
	unzip rsync ufw unattended-upgrades certbot python3-certbot-nginx

# Security updates are applied automatically every day.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Deploy user: owns the site files; GitHub Actions logs in as this user.
if ! id "$SITE_USER" >/dev/null 2>&1; then
	adduser --disabled-password --gecos '' "$SITE_USER"
fi
install -d -m 700 -o "$SITE_USER" -g "$SITE_USER" "/home/$SITE_USER/.ssh"
touch "/home/$SITE_USER/.ssh/authorized_keys"
chown "$SITE_USER:$SITE_USER" "/home/$SITE_USER/.ssh/authorized_keys"
chmod 600 "/home/$SITE_USER/.ssh/authorized_keys"
install -d -m 755 -o "$SITE_USER" -g "$SITE_USER" "$SITE_DIR"

# PHP runs as the deploy user, so WordPress can write uploads and update plugins
# without loosening file permissions. The default www pool is disabled to save memory.
cat > /etc/php/${PHP_V}/fpm/pool.d/liansi.conf <<EOF
[liansi]
user = ${SITE_USER}
group = ${SITE_USER}
listen = /run/php/liansi.sock
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 8
pm.process_idle_timeout = 30s
pm.max_requests = 500
php_admin_value[upload_max_filesize] = 32M
php_admin_value[post_max_size] = 32M
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 120
EOF
if [ -f /etc/php/${PHP_V}/fpm/pool.d/www.conf ]; then
	mv /etc/php/${PHP_V}/fpm/pool.d/www.conf /etc/php/${PHP_V}/fpm/pool.d/www.conf.disabled
fi

# MariaDB sized for a 2 GB machine.
cat > /etc/mysql/mariadb.conf.d/90-liansi.cnf <<'EOF'
[mysqld]
innodb_buffer_pool_size = 256M
max_connections = 50
performance_schema = OFF
EOF
systemctl restart mariadb

# Database and user. The password is generated here and only stored in a root-only file.
if ! mariadb -e "USE ${DB_NAME}" 2>/dev/null; then
	DB_PASS="$(openssl rand -hex 24)"
	mariadb -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
		CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
		GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
		FLUSH PRIVILEGES;"
	( umask 077; printf 'DB_NAME=%s\nDB_USER=%s\nDB_PASSWORD=%s\n' "$DB_NAME" "$DB_USER" "$DB_PASS" > /root/liansi-db.env )
fi

# Nginx: answers on any host name for now (IP access before the domain and ICP filing exist).
cat > /etc/nginx/sites-available/liansi <<EOF
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;

	root ${SITE_DIR};
	index index.php;
	client_max_body_size 32m;

	location / {
		try_files \$uri \$uri/ /index.php?\$args;
	}

	location ~ \.php\$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/liansi.sock;
	}

	location ~* \.(css|js|jpe?g|png|gif|svg|webp|ico|woff2?)\$ {
		expires 30d;
		access_log off;
	}

	location = /xmlrpc.php { deny all; }
	location ~ /\.(?!well-known) { deny all; }
}
EOF
ln -sf /etc/nginx/sites-available/liansi /etc/nginx/sites-enabled/liansi
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart php${PHP_V}-fpm
systemctl reload nginx

echo "provision done"
