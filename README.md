# 联思官网（WordPress）

线上 MVP：<https://danieleo.alwaysdata.net/>（中文） · <https://danieleo.alwaysdata.net/en/>（英文）
服务器：alwaysdata，WordPress 安装目录 `/home/danieleo/www/liansi`

## 仓库里有什么

| 路径 | 作用 |
|---|---|
| `wp-content/mu-plugins/liansi-core.php` | 用代码注册"产品 / 解决方案 / 客户"和"产品分类"，设置与线上 CPT UI 完全一致 |
| `wp-content/themes/liansi-child/` | Kadence 子主题，放品牌样式和模板调整（**尚未在线上启用**，见下文） |
| `config/plugins.txt` | 插件清单（slug@版本），新服务器上部署时自动安装 |
| `config/snapshots/site-settings.json` | 线上设置快照（Polylang、主题定制、菜单、表单 ID 等），供参考和迁移 |
| `scripts/post-deploy.sh` | 部署后在服务器上运行：补装缺失插件、刷新网址规则和缓存 |
| `scripts/activate-child-theme.sh` | 一次性：切换到子主题并保留定制器设置 |
| `.github/workflows/deploy.yml` | 推送到 `main` 后自动部署 |

## 不在仓库里的东西

页面、产品、方案、客户、菜单、翻译关联、主题定制等都存放在**数据库**里，图片在 `wp-content/uploads`。
这些内容以**服务器后台为准**，在后台直接编辑；用 UpdraftPlus 定期备份。

> 改代码 → 提交到 Git → 流水线部署。
> 改内容 → 直接在 WordPress 后台改。

## 首次配置 GitHub 部署

1. 在 alwaysdata 后台 **Remote access → SSH** 为账号启用 SSH。
2. 在本机生成部署专用密钥：
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/liansi_deploy -C "liansi-deploy"
   ```
   把 `~/.ssh/liansi_deploy.pub` 的内容追加到服务器的 `~/.ssh/authorized_keys`。
3. 在 GitHub 仓库 **Settings → Environments** 新建 `production` 环境，并添加以下 Secrets：

   | Secret | 值 |
   |---|---|
   | `SSH_PRIVATE_KEY` | `~/.ssh/liansi_deploy` 的完整内容 |
   | `SSH_KNOWN_HOSTS` | `ssh-keyscan ssh-danieleo.alwaysdata.net` 的输出 |
   | `SSH_USER` | `danieleo` |
   | `SSH_HOST` | `ssh-danieleo.alwaysdata.net` |
   | `DEPLOY_PATH` | `/home/danieleo/www/liansi` |

4. 推送到 `main`，或在 **Actions → Deploy → Run workflow** 手动运行。

流水线只会同步 `liansi-child` 主题文件夹和 `liansi-core.php`，不会动上传文件、第三方插件和数据库。

## 从 CPT UI 切换到代码注册（可选，建议迁移前做）

`liansi-core.php` 只在内容类型**尚未注册**时才注册，所以 CPT UI 还启用时它不会生效，也不会有冲突。
确认部署成功后，在后台停用 CPT UI 即可由代码接管；数据不受影响。之后可删除 CPT UI 并从 `plugins.txt` 移除。

## 启用子主题（可选）

WordPress 按主题分别保存定制器设置，直接在后台切换会丢失 Logo、页头页脚等设置。
流水线运行过一次后，在服务器上执行（会先备份 Kadence 的设置）：

```bash
cd /home/danieleo/www/liansi && bash ~/.liansi-deploy/activate-child-theme.sh
```

## 迁移到新服务器（阿里云 ECS，Ubuntu 24.04）

已迁移到阿里云 ECS（华北 2 北京，`123.56.8.177`），站点目录 `/var/www/liansi`，部署用户 `deploy`。

1. 新服务器以 root 运行一次初始化脚本（Nginx、PHP 8.3、MariaDB、防火墙、Swap、自动安全更新、部署用户、数据库）：
   ```bash
   scp scripts/provision-ubuntu.sh root@<IP>:/root/ && ssh root@<IP> bash /root/provision-ubuntu.sh
   ```
   数据库密码随机生成，只保存在服务器的 `/root/liansi-db.env`。
2. 中国大陆服务器访问不了 GitHub：wp-cli 需在本机下载并校验后上传到 `/usr/local/bin/wp`。
3. 在本机运行迁移脚本（复制插件、主题、上传文件、语言包和数据库，并替换网址；只读取旧站）：
   ```bash
   scripts/migrate-from-alwaysdata.sh http://<IP>        # 有域名后改成 https://www.<域名>
   ```
4. 修改 GitHub Secrets：`SSH_HOST`、`SSH_USER=deploy`、`DEPLOY_PATH=/var/www/liansi`、`SSH_KNOWN_HOSTS`，再运行 Deploy。
5. 域名备案通过后：解析域名、用 certbot 配置 HTTPS、把网址替换成域名，
   并在 **设置 → 阅读** 取消"建议搜索引擎不索引本站点"。
