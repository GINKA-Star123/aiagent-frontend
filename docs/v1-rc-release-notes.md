# AIAgent Mobile 1.0.0-rc.1 Release Notes

## 本版范围

- 手机端聊天主流程：文本、图片、语音输入。
- TTS 播放：支持自动播放和历史消息手动重播。
- Live2D：接入过渡模型，支持显示、待机动作、说话状态和口型切换。
- 记忆：支持读取和清空当前用户长期记忆。
- 设置：支持 API 地址保存、后端健康检查、自动播放开关、清空本机聊天历史。
- Android：应用名切换为 `AIAgent`，正式安装包 ID 为 `com.aiagent.mobile`，release 构建支持 keystore 配置。

## 验收重点

- 真机网络地址必须使用电脑局域网 IP，不能使用 `127.0.0.1`。
- 后端不可用时，聊天页和设置页应显示可读错误。
- 图片、录音、TTS、Live2D 都需要在 Android 真机上验收。
- 使用正式外发包前必须配置 release keystore。

## 已知限制

- 当前 Live2D 模型是过渡资源，正式模型交付后需要替换并复测。
- 华为 WebView/OpenGL 日志较多，RC 阶段以页面可见、模型可动、无 JS 渲染异常为准。
- 未配置 keystore 时 release 构建使用 debug signing，只适合内测。
