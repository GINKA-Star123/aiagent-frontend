# AIAgent Mobile

Flutter 手机端，当前进入 `1.0.0-rc.1+1`。

## 快速运行

```powershell
cd F:\aiagent\apps\flutter_client
flutter pub get
flutter run
```

首次启动后，在设置页把 API 地址改成电脑后端的局域网地址，例如：

```text
http://192.168.x.x:8000
```

## V1.0 RC 验证

```powershell
cd F:\aiagent\apps\flutter_client
dart format lib test
flutter analyze
flutter test
flutter build apk --release
```

真机手动验收项见 [docs/v1-release-checklist.md](docs/v1-release-checklist.md)。

## Android 签名

Release 构建会读取 `android/key.properties`。文件不存在时会使用 debug signing，方便内测安装，但不能作为正式外发包。

`android/key.properties` 示例：

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

keystore 和 `key.properties` 不要提交到仓库。
