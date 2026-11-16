# AIAgent Mobile（Flutter）

AIAgent 的独立移动端仓库，只负责交互：聊天、语音、图片、记忆、反馈。
不包含任何 LLM/TTS/ASR/RAG 配置，也不包含后端代码；服务地址与访问令牌由 **激活码** 一次性带入。

- 仓库：https://github.com/GINKA-Star123/aiagent-frontend
- 后端仓库：https://github.com/GINKA-Star123/OmniAgent（前后端分离）
- 当前版本：**1.5.7+28**
- 包名：`com.aiagent.mobile`

## 环境要求

| 项 | 版本 |
| --- | --- |
| Flutter | 3.41.9（stable，已验证） |
| Dart | 3.11 |
| JDK | 17 |
| Android SDK | 由 Flutter 自动解析（compileSdk = flutter.compileSdkVersion） |

## 独立仓库说明

本仓库是**独立 Git 项目**，不再位于后端仓库的跟踪范围内（后端 `.gitignore` 已忽略 `apps/flutter_client`）。
克隆后即可单独构建，不需要后端源码：

```bash
git clone https://github.com/GINKA-Star123/aiagent-frontend.git
cd aiagent-frontend
flutter pub get
```

激活码由后端侧生成（后端仓库的 `scripts/gen_activation_codes.py`），本仓库只负责粘贴使用。
激活码内容：`base64url(JSON{主入口, 备用入口[], token, user_id, 昵称})`。

## 本地运行

```powershell
flutter pub get
flutter run --dart-define=ACTIVATION_CODE=<激活码>
```

不传 `ACTIVATION_CODE` 时，App 首屏显示「激活设备」，粘贴激活码即可。

## 测试

```powershell
flutter analyze
flutter test
```

覆盖：激活码解析、发件箱/退避、多入口切换、降级 503 当回复、网络错误分类、遥测批量与失败保留、音频 URL token。

## 构建 release

```powershell
# 按 ABI 拆分（推荐分发）
flutter build apk --release --split-per-abi

# 通用包（不知道手机 ABI 时用）
flutter build apk --release

# 上架用 AAB（可选）
flutter build appbundle --release
```

产物：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

版本号在 `pubspec.yaml`：

```yaml
version: 1.3.0+1   # versionName+versionCode
```

每次发版递增 `+1` 的 versionCode。

## 签名配置（独立仓库必读）

### 1. 生成 keystore（只做一次）

```powershell
keytool -genkeypair -v ^
  -keystore android/app/release.jks ^
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 ^
  -alias aiagent ^
  -storepass <你的密码> -keypass <你的密码> ^
  -dname "CN=AIAgent, OU=Mobile, O=AIAgent, L=Local, S=Local, C=CN"
```

### 2. 配置 `android/key.properties`

```properties
storePassword=<你的密码>
keyPassword=<你的密码>
keyAlias=aiagent
storeFile=release.jks
```

`storeFile` 相对 `android/app/` 解析，所以 `release.jks` 放在 `android/app/release.jks`。

### 3. 不要提交密钥

以下文件已被 `android/.gitignore` 忽略，**不要**加进 Git：

```text
android/key.properties
android/app/*.jks
android/app/*.keystore
android/local.properties
```

> 没有 `android/key.properties` 时，Gradle 会回退到 debug 签名，APK 仍能安装，但不能用于正式升级分发。
> **务必备份 keystore 和密码**；丢失后已安装用户无法覆盖升级。

## GitHub Actions 自动 release

工作流：`.github/workflows/flutter-release.yml`

触发方式：

1. 打 tag：`git tag v1.3.0 && git push origin v1.3.0`
2. 或在 GitHub Actions 页面手动 **Run workflow**

构建内容：

- `flutter analyze` + `flutter test`
- 按 ABI 拆分 APK + 通用 APK
- tag 触发时自动附加到 GitHub Release
- 每次运行上传 `flutter-release-apk` artifact

### 配置签名 Secrets

在仓库 **Settings → Secrets and variables → Actions** 添加：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `release.jks` 的 Base64 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_KEY_ALIAS` | 例如 `aiagent` |

生成 Base64（PowerShell）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/release.jks")) | Set-Clipboard
```

- 手动 **Run workflow**：未配置 `ANDROID_KEYSTORE_BASE64` 时会警告并使用 debug 签名（仅自测）。
- 推送 `v*` tag：**必须**配置签名 Secrets，否则工作流直接失败，避免发出 debug 签名的正式 release。

## 目录结构

```text
lib/
  api/           Dio 客户端、模型、降级解析
  app/           主页面与聊天 UI
  auth/          激活页（登录页保留但默认隐藏）
  chat/          消息模型、历史、错误文案、操作菜单
  core/          激活码、会话、发件箱、遥测、反馈
  audio/         录音与播放
  memory/        记忆页
  settings/      设置
  theme/         主题
android/         Android 壳、签名、图标
test/            单元/契约测试
```

## 已知说明

- 默认允许明文 HTTP（`android:usesCleartextTraffic="true"`），便于内网/隧道联调；正式分发建议 HTTPS。
- 语音播放地址会自动附加 `access_token` 查询参数（后端 `/audio/*` 支持）。
- 快速隧道（trycloudflare）每次重启 URL 会变，激活码需要重新生成。
