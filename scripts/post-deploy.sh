#!/usr/bin/env bash
# 在服务器上、WordPress 根目录下运行（流水线会自动调用）。
# 用法: post-deploy.sh <plugins.txt 路径>
set -euo pipefail

PLUGINS_FILE="${1:?usage: post-deploy.sh <plugins.txt>}"

# Make sure the parent theme of liansi-child exists (e.g. on a fresh server).
wp theme is-installed kadence || wp theme install kadence

# Install only what is missing; never downgrade or touch plugins that are already there.
# wp reads stdin, so it gets /dev/null to keep it from swallowing the rest of the list.
grep -vE '^\s*(#|$)' "$PLUGINS_FILE" | while IFS='@' read -r slug version; do
	if wp plugin is-installed "$slug" < /dev/null; then
		echo "ok      $slug"
	else
		echo "install $slug@$version"
		wp plugin install "$slug" --version="$version" --activate < /dev/null
	fi
done

wp rewrite flush
wp cache flush
echo "post-deploy done"
