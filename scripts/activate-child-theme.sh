#!/usr/bin/env bash
# 一次性操作：把站点从 Kadence 切换到 liansi-child 子主题，并保留现有的定制器设置。
# WordPress 按主题分别保存定制器设置（theme_mods_<主题名>），直接切换会丢失 Logo、页头页脚等设置，
# 所以先把 Kadence 的设置复制给子主题，再激活。
# 在服务器上、WordPress 根目录下手动运行。
set -euo pipefail

backup="$HOME/theme_mods_kadence.$(date +%Y%m%d%H%M%S).json"
wp option get theme_mods_kadence --format=json > "$backup"
echo "backup saved to $backup"

wp option update theme_mods_liansi-child --format=json < "$backup"
wp theme activate liansi-child
wp cache flush
echo "liansi-child is active"
