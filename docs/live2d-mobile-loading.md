# Flutter 移动端 Live2D 载入步骤

本文档说明移动端 V1.0 如何载入真实 Live2D Cubism 模型。

## 1. 目标结构

Flutter WebView 会加载：

```text
assets/live2d_web/index.html
assets/live2d_web/live2d_stage.js
```

真实模型默认读取：

```text
assets/live2d_web/models/yzl/yzl.model3.json
```

Cubism 与渲染依赖默认读取：

```text
assets/live2d_web/cubism/live2dcubismcore.min.js
assets/live2d_web/vendor/pixi.min.js
assets/live2d_web/vendor/cubism4.min.js
```

如果这些文件不存在，App 不会崩溃，会显示 fallback 舞台和缺失提示。

## 2. 准备 Live2D 模型

把你的模型目录放到：

```text
apps/flutter_client/assets/live2d_web/models/yzl/
```

目录里至少要有：

```text
yzl.model3.json
```

并保持 model3.json 内部引用的文件相对路径不变，例如：

```text
yzl.moc3
textures/
motions/
expressions/
physics3.json
```

最终类似：

```text
assets/live2d_web/models/yzl/
  yzl.model3.json
  yzl.moc3
  textures/
  motions/
  expressions/
```

## 3. 准备 Cubism Web 运行文件

放入 Cubism Core：

```text
apps/flutter_client/assets/live2d_web/cubism/live2dcubismcore.min.js
```

放入 Pixi：

```text
apps/flutter_client/assets/live2d_web/vendor/pixi.min.js
```

放入 pixi-live2d-display 的 Cubism 4 版本：

```text
apps/flutter_client/assets/live2d_web/vendor/cubism4.min.js
```

注意：Cubism SDK 授权文件不要提交到公开仓库，按官方授权要求管理。

## 4. 确认 pubspec 资源

`pubspec.yaml` 需要包含：

```yaml
flutter:
  assets:
    - assets/live2d_web/
```

如果 Flutter 没有递归打包你的模型资源，请把子目录也加上：

```yaml
    - assets/live2d_web/cubism/
    - assets/live2d_web/vendor/
    - assets/live2d_web/models/yzl/
    - assets/live2d_web/models/yzl/textures/
    - assets/live2d_web/models/yzl/motions/
    - assets/live2d_web/models/yzl/expressions/
```

## 5. 后端字段对接

Flutter 会把后端返回的 `live2d` payload 传给 WebView：

```json
{
  "character": {
    "emotion": "happy",
    "expression": "bright_smile",
    "motion": "soft_idle",
    "mouth": {
      "mode": "audio",
      "audio_url": "/audio/xxx.wav"
    }
  },
  "scene": {
    "background_id": "room_default"
  }
}
```

移动端会调用：

```dart
Live2DBridge.applyPayload(payload)
Live2DBridge.setSpeaking(true)
```

Web 侧会尝试：

```javascript
model.expression(expression)
model.motion(motion)
```

如果模型里的表情名、动作名和后端字段不一致，需要在 `live2d_stage.js` 里增加映射。

## 6. 测试顺序

1. 启动后端。
2. 手机打开 Flutter App。
3. 确认主舞台不再提示缺少模型。
4. 发一条文本消息。
5. 检查角色是否根据 `expression` / `motion` 变化。
6. 检查 TTS 播放时角色是否进入 speaking 状态。

## 7. 常见问题

### 仍然显示 fallback

检查这些文件是否存在：

```text
models/yzl/yzl.model3.json
cubism/live2dcubismcore.min.js
vendor/pixi.min.js
vendor/cubism4.min.js
```

### 模型显示但动作不变

后端返回的 motion 名称可能和模型 motions 分组不一致，需要做 motion 映射。

### 表情不变

后端返回的 expression 名称可能和模型 expressions 文件名不一致，需要做 expression 映射。

### Android 能运行但白屏

优先检查 WebView 控制台不可见时的文件路径问题。可以临时看舞台左上角 label，它会显示缺失文件。
