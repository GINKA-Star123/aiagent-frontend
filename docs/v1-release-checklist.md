# AIAgent Mobile V1.0 RC Checklist

版本：`1.0.0-rc.1+1`

## 构建前

- 后端服务已启动，并且手机和电脑在同一个 Wi-Fi 或同一个可访问网络内。
- 手机端设置页里的 API 地址指向电脑局域网地址，例如 `http://192.168.x.x:8000`。
- Android release 签名已准备好：`android/key.properties` 和对应 keystore 存在。没有配置时会 fallback 到 debug signing，只适合内测安装。

## 真机验收

- 首次启动能进入引导页，完成引导后进入聊天页。
- 设置页可以保存 API 地址，并且“检查连接”能显示后端已连接。
- 文本聊天可以发送，能收到回复，并且错误时有可读提示。
- 图片聊天可以从相册或相机选择图片，随文字一起发送并收到回复。
- 录音按钮可以录音、停止、转写，并把转写内容发起聊天。
- TTS 自动播放开关生效；回复有音频时能自动播放，历史消息可以手动重播。
- Live2D 模型可显示、可运动，回复播放时口型/说话状态能切换。
- 记忆页可以读取当前用户长期记忆；清空长期记忆后列表刷新。
- 清空聊天记录只删除本机历史消息，不影响后端长期记忆。
- 关于页的版本、连接和隐私提示可读。

## 发布包

- `flutter analyze` 无错误。
- `flutter test` 通过。
- `flutter build apk --release` 可以生成安装包。
- 使用 release keystore 构建时，确认安装包签名不是 debug 证书。

## 已知 RC 风险

- Live2D 当前使用过渡模型，正式模型交付后需要替换资源并复测动作、表情和口型。
- 华为 WebView 会输出较多 WebGL/OpenGL 日志；只要没有 `render failed` 或未捕获异常，暂不阻塞 RC。
- 没有 release keystore 时构建会使用 debug signing，不能作为正式外发包。
