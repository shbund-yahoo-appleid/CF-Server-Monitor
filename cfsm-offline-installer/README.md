# CF-Server-Monitor 离线安装包

本安装包包含了在无法访问 GitHub 的环境中安装 CF-Server-Monitor Agent 所需的所有文件。

## 文件说明

- `cf-probe-linux-amd64` - CF-Server-Monitor Agent 二进制文件（Linux x86_64）
- `local-install.sh` - 本地一键安装脚本
- `config.json` - （可选）配置文件

## 快速开始

### 方法一：直接携带参数运行（推荐）

直接将您在后台获取的长命令中的 `curl ... | sh -s -- install` 替换为 `sudo bash local-install.sh`。

```bash
cd /tmp
tar -xzf cfsm-offline-installer.tar.gz
cd cfsm-offline-installer
chmod +x local-install.sh
sudo bash local-install.sh -id=您的ID -secret=您的Secret -url=您的URL -connection_mode=http ...（跟官方后台复制的参数完全一致即可）
```

### 方法二：使用 config.json 运行

如果您不想在命令行里附带这么长的参数，可以将参数提前写入到 `config.json` 里。
然后直接执行：

```bash
cd /tmp
tar -xzf cfsm-offline-installer.tar.gz
cd cfsm-offline-installer
chmod +x local-install.sh
sudo bash local-install.sh
```

脚本检测到没有跟任何参数时，会自动读取同目录下的 `config.json` 并应用配置。
sudo bash local-install.sh -id=SERVER_ID -secret=SECRET -url=WORKER_URL
```

## 参数说明

### 必填参数

- `-id=SERVER_ID` - 服务器 ID，从管理后台获取
- `-secret=SECRET` - 服务器密钥，从管理后台获取
- `-url=WORKER_URL` - Worker 上报地址，从管理后台获取

### 可选参数

- `-user=USERNAME` - 非 root 安装时指定用户（需要 systemd --user 支持）
- `-interval=N` - 上报间隔，单位秒（默认: 60）
- `-collect_interval=N` - 采样间隔，单位秒（默认: 0）
- `-reset_day=N` - 每月流量重置日（默认: 1）
- `-auto_update=0|1` - 是否开启自动检查更新（默认: 0）
- `-debug=0|1` - 是否开启调试日志（默认: 0）
- `-dir=PATH` - 安装目录（默认: /usr/local/bin）

## 非 root 安装

如果你的系统支持 `systemd --user`，可以使用非 root 用户安装：

```bash
# 创建用户
useradd -m -s /bin/bash cfsm
loginctl enable-linger cfsm
passwd cfsm

# 以该用户登录
su - cfsm

# 在用户目录下安装
bash /tmp/cfsm-offline-installer/local-install.sh -id=SERVER_ID -secret=SECRET -url=WORKER_URL -user=cfsm
```

## 查看状态和日志

### Root 安装

```bash
# 查看服务状态
systemctl status cf-probe

# 查看实时日志
journalctl -u cf-probe -f

# 查看日志文件
tail -f /var/lib/cf-probe/cf-probe.log
```

### 非 root 安装

```bash
# 切换到安装用户
su - cfsm

# 查看服务状态
systemctl --user status cf-probe

# 查看实时日志
journalctl --user -u cf-probe -f

# 查看日志文件
tail -f ~/.cf-probe/cf-probe.log
```

## 卸载

### Root 安装

```bash
sudo /usr/local/bin/cf-probe uninstall
```

### 非 root 安装

```bash
# 切换到安装用户
su - cfsm

systemctl --user stop cf-probe
systemctl --user disable cf-probe
rm -f ~/.config/systemd/user/cf-probe.service
rm -rf ~/.cf-probe
# 然后以 root 用户删除二进制文件
sudo rm -f /usr/local/bin/cf-probe
```

## 故障排除

### 服务无法启动

```bash
# 检查服务状态
systemctl status cf-probe

# 查看详细日志
journalctl -u cf-probe -n 50 --no-pager

# 检查配置文件
cat /var/lib/cf-probe/cf-probe.conf
```

### 网络连接问题

```bash
# 测试 Worker 地址连通性
curl -I https://你的Worker域名/update

# 检查防火墙规则
sudo iptables -L -n
sudo ufw status
```

> ⚠️ **国内服务器避坑指南（重要）：**
> 1. **禁止直接使用默认的 `*.workers.dev` 域名**：默认域名在国内已被拦截，会导致国内服务器安装后无法上报，面板长期显示“离线”。
> 2. **必须使用自定义域名**：请前往 Cloudflare Workers 的 *Settings -> Domains & Routes* 绑定您自己的自定义域名（例如 `probe.deepseo.us`）。
> 3. **必须等待自定义域名变为 `Active`**：在 CF 后台添加自定义域名后，**必须等待几分钟直到其状态变为 "Active"** 后路由才真正生效。如果添加后立刻使用，可能会遇到 522 错误。
> 4. **更新配置文件**：确认域名 Active 后，将 `config.json` 中的 `"url"` 变更为 `https://您的自定义域名/update`，再重新执行安装。

### 权限问题

```bash
# 检查文件权限
ls -la /usr/local/bin/cf-probe
ls -la /var/lib/cf-probe/

# 修正权限（如需要）
sudo chmod +x /usr/local/bin/cf-probe
sudo chown -R root:root /var/lib/cf-probe/
```

## 获取服务器信息

1. 登录 CF-Server-Monitor 管理后台
2. 进入「服务器管理」
3. 点击「添加服务器」
4. 填写服务器名称后点击「添加」
5. 点击服务器右侧的「复制安装命令」
6. 从命令中提取 SERVER_ID、SECRET 和 WORKER_URL

## 技术支持

- 项目主页：https://github.com/huilang-me/CF-Server-Monitor
- Agent 项目：https://github.com/huilang-me/cfsm-agent
- 文档：https://github.com/huilang-me/CF-Server-Monitor/blob/main/README.md
