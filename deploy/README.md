# CF-Server-Monitor 实战部署记录

> 本文档基于实际部署过程整理，包含完整步骤和踩坑记录。
> 部署时间：2026-08-18
> 最终访问地址：https://probe.deepseo.us

---

## 最终部署结果

| 项目 | 值 |
|---|---|
| 监控面板地址 | https://probe.deepseo.us |
| 后台地址 | https://probe.deepseo.us/admin#/admin |
| Worker 原始地址 | https://cf-server-monitor.yd9868p62r.workers.dev |
| D1 数据库名 | server-monitor-db |
| 上报间隔 | 60 秒 |

---

## 前置准备

- Cloudflare 账号（域名 deepseo.us 在此账号下）
- GitHub 账号，Fork 仓库：https://github.com/shbund-yahoo-appleid/CF-Server-Monitor
- 生成 API_SECRET（Mac 终端执行）：
  ```bash
  openssl rand -hex 32
  ```
  > ⚠️ 生成的值避免包含 `& = + # % $ @ !`，hex 格式最安全

---

## 部署步骤（已验证可行）

### 1. 创建 D1 数据库

进 Cloudflare Dashboard → **Storage & Databases → D1 → Create database**

- 名称：`server-monitor-db`
- 创建后记下 Database ID

> ⚠️ 坑：这步容易漏掉，必须先建，否则 Worker 部署后无法写数据。

---

### 2. Fork 仓库并连接 Cloudflare Workers

1. Fork 仓库到自己 GitHub
2. 进 Cloudflare Dashboard → **Workers & Pages → Create → Import a repository**
3. 连接 GitHub，选 Fork 的仓库
4. Build & Deploy 配置：

| 字段 | 值 |
|---|---|
| Build command | `npm run build:frontend` |
| Deploy command | `npx wrangler deploy` |

> ⚠️ 坑：Cloudflare 界面可能不会自动填 Build command，只填了 Deploy command 导致 `dist` 目录不存在报错：
> ```
> The directory specified by the "assets.directory" field does not exist: /opt/buildhome/repo/dist
> ```
> 解决：把两条命令合并填到 Deploy command：
> ```
> npm run build:frontend && npx wrangler deploy
> ```

---

### 3. 绑定 D1 数据库

Worker 部署完成后（第一次可能失败，正常）：

进 Worker → **Settings → Bindings → Add binding**

| 字段 | 值 |
|---|---|
| Variable name | `DB` |
| D1 database | server-monitor-db |

---

### 4. 添加环境变量

进 Worker → **Settings → Variables and Secrets**

| 变量名 | 值 |
|---|---|
| `API_SECRET` | 第一步生成的强密码 |

---

### 5. 重新触发部署

加完 Binding 和变量后，手动触发：**Deployments → Retry deployment**

---

### 6. 绑定自定义域名（国内服务器必须）

`*.workers.dev` 域名在国内被墙，国内 VPS 无法上报数据，必须绑自定义域名。

#### 血泪史：三次失败才成功

**第一次尝试**：Worker → Settings → Domains & Routes → 添加自定义域 → 填 `probe.deepseo.us`

报错：`没有区域匹配 probe.deepseo.us`

原因：虽然 `deepseo.us` 在同一 Cloudflare 账号，但 DNS 区域没有 `probe` 这条记录，界面无法识别。

---

**第二次尝试**：先在 DNS 手动加 AAAA 占位记录

进 DNS → Add record：
- Type: `AAAA`
- Name: `probe`
- IPv6: `100::`
- Proxy: 已代理（橙云）

再回 Worker 添加自定义域 → 成功添加，但访问返回 **522 错误**。

原因：AAAA `100::` 占位记录没有被 Worker 覆盖，Cloudflare 还在尝试连接 `100::` 这个地址。

---

**第三次尝试**：改 AAAA 为 CNAME 指向 workers.dev

把 DNS 记录改为：
- Type: `CNAME`
- Name: `probe`
- Target: `cf-server-monitor.yd9868p62r.workers.dev`

结果还是 **522 错误**。

原因：CNAME 指向 `workers.dev` 不会被路由到 Worker 逻辑，这不是正确的绑定方式。

---

**最终成功**：等待自定义域 Active 状态生效

回 Worker → Settings → Domains & Routes，确认 `probe.deepseo.us` 状态变为 **Active**（需要等待几分钟）。

Active 之后 Cloudflare 自动管理路由，删掉手动加的 CNAME 记录，由 Worker 自定义域接管流量。

> ✅ 结论：添加自定义域后**必须等状态变为 Active**，不是添加完就立刻生效。

---

### 7. 登录后台

```
https://probe.deepseo.us/admin#/admin
```

| 项目 | 值 |
|---|---|
| 用户名 | `admin` |
| 密码 | `API_SECRET` 的值 |

登录后立即修改用户名和密码。

---

## 安装 Agent（VPS 端）

### 国外服务器

直接用后台生成的安装命令，Worker URL 保持 `workers.dev` 即可。

### 国内服务器

后台生成的命令中，将两处 `workers.dev` 地址替换为 `probe.deepseo.us`：

```bash
curl -sL https://probe.deepseo.us/install.sh | sudo bash -s install \
  -id=<后台生成的服务器ID> \
  -secret='<你的API_SECRET>' \
  -url=https://probe.deepseo.us/update \
  -interval=60 \
  -ping=http \
  -reset_day=1 \
  -ct=gd-ct-dualstack.ip.zstaticcdn.com \
  -cu=gd-cu-dualstack.ip.zstaticcdn.com \
  -cm=gd-cm-dualstack.ip.zstaticcdn.com \
  -bd=lf3-ips.zstaticcdn.com
```

> ⚠️ 坑1：直接跑不加 `sudo` 会报 `请使用 root 权限运行此脚本`，加 `sudo` 解决。
>
> ⚠️ 坑2：每台服务器的 `-id=` 不同，必须在后台单独添加服务器后复制对应 ID，不能复用同一个 ID。

---

## 参数说明

| 参数 | 说明 | 当前值 |
|---|---|---|
| `-interval` | 上报间隔（秒） | 60 |
| `-reset_day` | 月流量重置日 | 1 |
| `-ct/-cu/-cm/-bd` | 网络质量测试节点 | 内置节点 |

60 秒间隔支持约 60 台服务器（D1 免费额度），台数多时可改为 120s。

---

## 常见问题速查

| 现象 | 原因 | 解决 |
|---|---|---|
| 构建失败，`dist` 不存在 | Build command 没执行 | Deploy command 改为 `npm run build:frontend && npx wrangler deploy` |
| 访问返回 522 | 自定义域未 Active 或 DNS 配置错误 | 等待 Active 状态，或检查 DNS |
| 国内服务器无法上报 | `workers.dev` 被墙 | 绑自定义域，安装命令换域名 |
| Agent 安装报 `command not found` | install.sh 下载失败（域名不通） | 先 `curl -v` 测试连通性 |
| Agent 安装报需要 root 权限 | 没加 sudo | 命令加 `sudo` |
| 忘记后台密码 | - | D1 数据库 `setting` 表改 `password` 字段 |
