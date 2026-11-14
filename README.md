# AIAgent Mobile（Flutter）

移动端只负责交互：聊天、语音、图片、记忆、反馈。不包含任何 LLM/TTS/ASR/RAG 配置，
服务地址与访问令牌由 **激活码** 一次性带入。Live2D 不参与构建。

当前版本：**1.3.0+1**

## 能力

- 聊天：多轮、Markdown 文本、图片多模态、语音输入、TTS 播放
- 可靠性：离线发件箱（自动重发）、多入口失败切换、服务端降级回复直接展示
- 身份：激活码 = base64url(JSON{主入口, 备用入口[], token, user_id, 昵称})
- 记忆：分层查看、搜索、置顶、删除、长期记忆开关
- 回流：匿名指标本地缓冲 + 批量上报 POST /telemetry/batch；每条回复 👍/👎 + 原因标签
- 隐私：默认不上传对话正文；用户名/设备标识仅本地

## 运行

```powershell
cd F:\aiagent\apps\flutter_client
flutter pub get
flutter run --dart-define=ACTIVATION_CODE=<激活码>
```

不传 ACTIVATION_CODE 时，App 首屏显示「激活设备」，粘贴激活码即可。

## 生成激活码（含后端 token 映射）

```powershell
# 仓库根目录执行；--base-urls 可多次传入（第一个为主入口）
.venv\Scripts\python.exe scripts\gen_activation_codes.py --count 50 --base-urls http://192.168.0.111:8000 --base-urls http://10.0.2.2:8000
```

产物在 data/private/activation/：activation_codes.csv、token_map.json、env_snippet.txt。
把 env_snippet.txt 追加到后端 .env（API_AUTH_MODE=bearer + token 映射），重启后端。

## 打包 release

```powershell
flutter build apk --release --split-per-abi   # arm64-v8a / armeabi-v7a / x86_64
flutter build apk --release                   # 通用包
```

签名读取 android/key.properties（不存在时回退 debug 签名）。
产物在 build/app/outputs/flutter-apk/。

## 测试

```powershell
flutter analyze
flutter test
```

覆盖：激活码解析、发件箱/退避、多入口切换、降级 503 当回复、网络错误分类、遥测批量与失败保留。
