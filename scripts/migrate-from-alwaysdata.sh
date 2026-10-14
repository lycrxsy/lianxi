#!/usr/bin/env bash
# 把网站从 alwaysdata 复制到阿里云服务器（在本机运行，本机同时能 SSH 到两台服务器）。
# 用法: scripts/migrate-from-alwaysdata.sh <新网址>     例如 http://123.56.8.177 或 https://www.liansi.com
#
# 复制 wp-content（插件、主题、上传文件、语言包）和数据库，并把旧网址替换成新网址。
# 只读取 alwaysdata，不改动它；目标服务器上已有的网站文件和数据库会被覆盖。
# 前提：目标服务器已运行过 provision-ubuntu.sh。
set -euo pipefail

NEW_URL="${1:?usage: migrate-from-alwaysdata.sh <new url, e.g. http://123.56.8.177>}"
NEW_URL="${NEW_URL%/}"

OLD_URL="https://danieleo.alwaysdata.net"
OLD_PATH="/home/danieleo/www/liansi"
NEW_PATH="/var/www/liansi"
WP_VERSION="7.1.3"
# JSON stored in the database escapes slashes (https:\/\/...), so those need a second pass.
OLD_URL_ESC="${OLD_URL//\//\\/}"
NEW_URL_ESC="${NEW_URL//\//\\/}"

SRC=(ssh -i ~/.ssh/liansi_deploy -o IdentitiesOnly=yes -o BatchMode=yes danieleo@ssh-danieleo.alwaysdata.net)
ROOT=(ssh -i ~/.ssh/liansi_aliyun -o IdentitiesOnly=yes -o BatchMode=yes root@123.56.8.177)
DEPLOY=(ssh -i ~/.ssh/liansi_deploy -o IdentitiesOnly=yes -o BatchMode=yes deploy@123.56.8.177)

echo "== 1/5 WordPress core ${WP_VERSION} =="
# Core comes as the en_US build; the Chinese language packs arrive with wp-content/languages.
"${DEPLOY[@]}" "cd ${NEW_PATH} && { [ -f wp-load.php ] || wp core download --version=${WP_VERSION}; }"

echo "== 2/5 wp-config.php =="
# Runs as root to read the DB password, then writes the file as the deploy user.
"${ROOT[@]}" bash -s <<EOF
set -euo pipefail
. /root/liansi-db.env
cd ${NEW_PATH}
if [ ! -f wp-config.php ]; then
	printf '%s' "\$DB_PASSWORD" | sudo -u deploy wp config create --dbname="\$DB_NAME" --dbuser="\$DB_USER" --prompt=dbpass --locale=zh_CN --skip-check >/dev/null
	sudo -u deploy wp config set FS_METHOD direct >/dev/null
	sudo -u deploy wp config set DISALLOW_FILE_EDIT true --raw >/dev/null
	sudo -u deploy wp config set WP_MEMORY_LIMIT 256M >/dev/null
	chmod 640 wp-config.php
fi
echo "wp-config ok"
EOF

echo "== 3/5 wp-content (plugins, themes, uploads, languages) =="
# Replace the default wp-content from the core download with an exact copy of the live one.
"${DEPLOY[@]}" "rm -rf ${NEW_PATH}/wp-content"
"${SRC[@]}" "tar czf - -C ${OLD_PATH} --exclude=wp-content/updraft --exclude=wp-content/upgrade --exclude=wp-content/cache wp-content" \
	| "${DEPLOY[@]}" "tar xzf - -C ${NEW_PATH}"
# alwaysdata uses 770/660; Nginx runs as www-data and needs to read static files.
"${DEPLOY[@]}" "cd ${NEW_PATH} && find . -type d -exec chmod 755 {} + && find . -type f ! -name wp-config.php -exec chmod 644 {} + && chmod 640 wp-config.php"

echo "== 4/5 database =="
"${SRC[@]}" "cd ${OLD_PATH} && wp db export - --single-transaction 2>/dev/null" \
	| "${DEPLOY[@]}" "cd ${NEW_PATH} && wp db import - >/dev/null && echo imported"

echo "== 5/5 replace URLs and paths =="
"${DEPLOY[@]}" bash -s <<EOF
set -euo pipefail
cd ${NEW_PATH}
wp search-replace '${OLD_URL}' '${NEW_URL}' --all-tables --skip-columns=guid --report-changed-only
wp search-replace '${OLD_URL_ESC}' '${NEW_URL_ESC}' --all-tables --skip-columns=guid --report-changed-only
wp search-replace '${OLD_PATH}' '${NEW_PATH}' --all-tables --report-changed-only
wp transient delete --all >/dev/null
wp rewrite flush
wp cache flush
echo "home: \$(wp option get home)"
EOF

echo "migration done -> ${NEW_URL}"
