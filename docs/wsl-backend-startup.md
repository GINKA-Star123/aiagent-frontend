# WSL 后端启动 Runbook（AIAgent / OmniAgent）

> 适用环境：Windows + WSL2 发行版 **sp3-build**，后端源码在 /root/aiagent。
> 原则：**所有服务手动启动**，本文不要求开机自启；不要提交 .env、.admin_token 或 data/auth 下的账号文件。

## 0. 一页速查

Windows PowerShell 打开 WSL：

~~~powershell
wsl -l -v
wsl -d sp3-build
~~~

WSL 终端 1（后端，允许新账号注册）：

~~~bash
cd /root/aiagent
AUTH_REGISTRATION_ENABLED=true AUTH_INVITE_CODE= bash run_api.sh
~~~

WSL 终端 2（Cloudflare 临时隧道）：

~~~bash
cloudflared tunnel --url http://127.0.0.1:8000 --protocol http2
~~~

复制输出的 https://xxxx.trycloudflare.com，填入 App 登录页的“服务器地址”。

App 首屏：填服务器地址 → 注册（邮箱 + 用户名 + 密码）或登录（邮箱/用户名 + 密码）。

---

## 1. 当前环境事实

| 项 | 值 |
|---|---|
| WSL 发行版 | sp3-build（Ubuntu 24.04） |
| 后端目录 | /root/aiagent |
| Python venv | /root/.venvs/aiagent-native |
| 启动脚本 | /root/aiagent/run_api.sh |
| 后端监听 | 127.0.0.1:8000 |
| cloudflared | /usr/local/bin/cloudflared（2026.11.0） |
| 固定隧道配置 | 尚未创建（/root/.cloudflared 不存在） |

说明：

- WSL 默认启动目录可能是 /mnt/f/aiagent，不是后端目录；每次先 cd /root/aiagent。
- run_api.sh 会设置静态 token 映射、关闭本地音频播放、写入 .admin_token，然后启动 uvicorn；不要修改或打印这些密钥。
- 新的登录/注册使用后端动态 token，和原有静态 token 映射合并生效。
- 后端是单文件 JSON 账号存储，建议只跑一个 worker。

---

## 2. 一次性配置：允许注册

当前后端 .env 没有 AUTH_* 覆盖，默认值是：

~~~env
AUTH_REGISTRATION_ENABLED=false
AUTH_INVITE_CODE=
~~~

不打开注册，App 注册页会收到 registration_disabled。二选一：

### 方案 A：启动时临时注入（不改任何文件，推荐先验证）

~~~bash
cd /root/aiagent
AUTH_REGISTRATION_ENABLED=true AUTH_INVITE_CODE= bash run_api.sh
~~~

环境变量优先级高于 .env，进程退出后失效。

### 方案 B：写入后端 .env（长期使用）

编辑 /root/aiagent/.env，加入或修改：

~~~env
AUTH_REGISTRATION_ENABLED=true
AUTH_INVITE_CODE=
AUTH_GUEST_ENABLED=false
~~~

保存后重启后端。这是配置修改，不需要改后端代码。

### 确认进程环境

后端启动后另开一个 WSL 终端：

~~~bash
curl -s http://127.0.0.1:8000/health
~~~

正常应返回 JSON 且 ok=true。

> 不要用 /auth/register 反复创建测试账号；确认注册页能打开即可。账号文件在 data/auth/auth_store.json，请备份。

---

## 3. 启动后端（终端 1）

从 Windows PowerShell：

~~~powershell
wsl -d sp3-build
~~~

进入后端并启动：

~~~bash
cd /root/aiagent
AUTH_REGISTRATION_ENABLED=true AUTH_INVITE_CODE= bash run_api.sh
~~~

看到 uvicorn 监听 127.0.0.1:8000 即成功。

检查端口：

~~~bash
ss -ltnp | grep 8000
~~~

停止：在该终端按 Ctrl+C。

> 如果你是第一次启动，data/auth 目录会自动创建。
> 如果 8000 已被占用，先查占用进程，不要盲目 kill 其他程序：
> ~~~bash
> ss -ltnp | grep 8000
> ~~~

---

## 4. 启动 Cloudflare 隧道（终端 2）

### 4.1 临时隧道（没有域名时先用这个）

新开一个 WSL 终端：

~~~bash
cloudflared tunnel --url http://127.0.0.1:8000 --protocol http2
~~~

输出中会出现：

~~~text
https://random-words-1234.trycloudflare.com
~~~

这个 URL 每次重启都会变。保持该终端运行。

验证：

~~~bash
curl -s https://random-words-1234.trycloudflare.com/health
~~~

也可以从 Windows 浏览器或手机浏览器打开该地址的 /health。

### 4.2 固定域名隧道（可选，需要自己的域名）

前提：

1. 已购买域名；
2. 域名已添加到 Cloudflare，NS 已生效（Cloudflare 显示 Active）；
3. cloudflared 已登录。

步骤：

~~~bash
cloudflared tunnel login
cloudflared tunnel create aiagent
cloudflared tunnel route dns aiagent api.你的域名.com
~~~

记下 create 输出的 UUID。创建 /root/.cloudflared/config.yml：

~~~yaml
tunnel: 你的隧道UUID
credentials-file: /root/.cloudflared/你的隧道UUID.json

ingress:
  - hostname: api.你的域名.com
    service: http://127.0.0.1:8000
  - service: http_status:404
~~~

启动：

~~~bash
cloudflared tunnel run aiagent
~~~

App 服务器地址改为：

~~~text
https://api.你的域名.com
~~~

固定域名后不需要每次改登录页地址。

---

## 5. App 登录 / 注册（终端 3 或手机）

安装新版 APK（2.1.0+49 或之后）。

1. 打开 App，首屏是登录页；
2. “服务器地址”填隧道地址（不要带结尾 /，不要带 /api）；
3. 点“没有账号，先注册”；
4. 填邮箱、用户名、密码（至少 6 位）、确认密码；
5. 注册成功直接进入聊天；
6. 以后登录：邮箱或用户名 + 密码。

重要限制：

- 后端没有 email 字段，邮箱只保存在**本机**作为登录别名；
- 换手机/清空 App 数据后邮箱别名失效，只能用用户名登录；
- 邮箱验证码当前无法发送，详见 docs/email-verification-feasibility.md；
- 后端用户名唯一，重复用户名会被拒绝；
- 长期记忆和本地聊天数据都按服务端 user_id 隔离，不按 username 拼接。

---

## 6. 验证清单

### 6.1 后端

~~~bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/live
~~~

### 6.2 隧道

~~~bash
curl -s https://你的隧道地址/health
~~~

### 6.3 App

- 登录页能打开；
- 注册成功（如果后端注册已开启）；
- 能发一条文字消息并收到回复；
- 退出登录后能用同一账号重新登录；
- 切换另一个账号，聊天历史不串。

---

## 7. 常见故障

| 现象 | 原因 | 处理 |
|---|---|---|
| 注册提示“后端未开启注册” | AUTH_REGISTRATION_ENABLED=false | 按第 2 节启动或改 .env 后重启 |
| 注册提示“后端仍要求邀请码” | 后端 .env 设置了 AUTH_INVITE_CODE | 设为空并重启 |
| 登录提示“账号或密码错误” | 账号不存在/密码错 | 先注册；确认用户名大小写不敏感 |
| 邮箱登录失败 | 本机没有该邮箱别名 | 改用用户名登录；邮箱别名只在本机 |
| 隧道 502/无法连接 | 后端没启动或端口不对 | 先验证 127.0.0.1:8000/health |
| 隧道 URL 变了 | 临时隧道重启 | 登录页/设置里更新服务器地址 |
| WSL 提示 WSL_E_DISTRO_NOT_FOUND | 发行版名不对/未启动 | wsl -l -v，确认用 sp3-build |
| 8000 被占用 | 旧进程未退出 | ss -ltnp 查 PID，确认是自己的 uvicorn 再处理 |
| 重启 Windows 后全断 | WSL 和两个服务都停了 | 重新执行第 3、4 节 |

---

## 8. 关闭与重启

### 关闭

- 终端 1：Ctrl+C 停 uvicorn；
- 终端 2：Ctrl+C 停 cloudflared；
- 不要直接删 .admin_token、data/auth 或 .env。

### 重启

~~~powershell
wsl -d sp3-build
~~~

终端 1：

~~~bash
cd /root/aiagent
AUTH_REGISTRATION_ENABLED=true AUTH_INVITE_CODE= bash run_api.sh
~~~

终端 2：

~~~bash
cloudflared tunnel --url http://127.0.0.1:8000 --protocol http2
~~~

如果临时隧道 URL 变了，更新 App 服务器地址。

---

## 9. 安全注意事项

- 临时隧道是公网地址；注册开启时，知道 URL 的人都能注册。测试完成后建议关闭注册：
  ~~~bash
  cd /root/aiagent
  AUTH_REGISTRATION_ENABLED=false bash run_api.sh
  ~~~
- 长期公网使用建议固定域名 + Cloudflare Access，或只在内网使用。
- 不要提交或截图 .env、.admin_token、data/auth/auth_store.json。
- 账号 token 有效期由 AUTH_TOKEN_TTL_HOURS 控制，过期后重新登录。
- 中国大陆公网服务器涉及备案要求；当前 WSL + Cloudflare Tunnel 场景请按当地规定确认。

---

## 10. 与旧激活码的区别

- 旧流程：激活码同时包含隧道 URL、token、user_id；
- 新流程：隧道 URL 手动填；token/user_id 由 /auth/register 或 /auth/login 返回；
- Cloudflare 仍然是网络通道，只是不再把 URL 编码进激活码；
- 旧激活码本地数据不会自动迁移到新账号，旧 user_id 的服务端记忆也不会自动归到新账号。
