#!/usr/bin/env bash
# 在服务器上、WordPress 根目录下运行（流水线会自动调用）。
# 用法: post-deploy.sh <plugins.txt 路径>
set -euo pipefail

PLUGINS_FILE="${1:?usage: post-deploy.sh <plugins.txt>}"

# alwaysdata does not ship wp-cli; install the official phar (checksum-verified) when missing.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v wp >/dev/null 2>&1; then
	echo "installing wp-cli"
	mkdir -p "$HOME/.local/bin"
	tmp="$(mktemp -d)"
	base=https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar
	curl -fsSL -o "$tmp/wp-cli.phar" "$base/wp-cli.phar"
	curl -fsSL -o "$tmp/wp-cli.phar.sha512" "$base/wp-cli.phar.sha512"
	(cd "$tmp" && echo "$(cat wp-cli.phar.sha512)  wp-cli.phar" | sha512sum -c -)
	install -m 755 "$tmp/wp-cli.phar" "$HOME/.local/bin/wp"
	rm -rf "$tmp"
fi
wp --version

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
