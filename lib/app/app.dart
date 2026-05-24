import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../about/about_page.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_models.dart';
import '../auth/auth_page.dart';
import '../audio/audio_playback_service.dart';
import '../audio/recorder_service.dart';
import '../chat/chat_error.dart';
import '../chat/chat_history_store.dart';
import '../chat/chat_message.dart';
import '../chat/memory_status.dart';
import '../chat/message_actions.dart';
import '../connectivity/backend_status.dart';
import '../identity/identity_store.dart';
import '../identity/user_identity.dart';
import '../live2d/live2d_bridge.dart';
import '../live2d/live2d_payload.dart';
import '../live2d/live2d_stage_view.dart';
import '../memory/memory_page.dart';
import '../profile/profile_page.dart';
import '../settings/app_preferences.dart';
import '../settings/settings_page.dart';
import '../theme/app_theme.dart';
import '../voice_call/voice_call_page.dart';

class AiAgentApp extends StatelessWidget {
  const AiAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIAgent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ChatHomePage(),
    );
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late ApiClient _apiClient;
  late final IdentityStore _identityStore;
  late final ChatHistoryStore _historyStore;
  late final AppPreferences _preferences;
  late final AudioPlaybackService _audioPlaybackService;
  late final RecorderService _recorderService;

  StreamSubscription<bool>? _speakingSubscription;
  Live2DBridge? _live2dBridge;

  ApiConfig _apiConfig = ApiConfig.defaults();
  UserIdentity? _identity;
  Live2DPayload? _currentLive2D;
  BackendStatus _backendStatus = BackendStatus.unknown();
  List<ChatMessage> _messages = [];

  bool _apiClientReady = false;
  bool _loading = true;
  bool _sending = false;
  bool _speaking = false;
  bool _recording = false;
  bool _autoPlayVoice = true;
  bool _chatPanelExpanded = false;
  String _statusText = '正在初始化...';
  String _selectedImagePath = '';

  @override
  void initState() {
    super.initState();
    _audioPlaybackService = AudioPlaybackService();
    _recorderService = RecorderService();
    _speakingSubscription = _audioPlaybackService.speakingStream.listen(
      _handleSpeakingChanged,
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speakingSubscription?.cancel();
    _audioPlaybackService.dispose();
    _recorderService.dispose();
    if (_apiClientReady) {
      _apiClient.close();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _identityStore = IdentityStore();
    _historyStore = ChatHistoryStore();
    _preferences = await AppPreferences.load();

    final config = await ApiConfig.load();
    final identity = await _identityStore.load();
    final history = await _historyStore.load();

    _apiConfig = config;
    _apiClient = ApiClient(config: config);
    _apiClientReady = true;

    if (!mounted) {
      return;
    }

    setState(() {
      _identity = identity;
      _messages = history;
      _autoPlayVoice = _preferences.autoPlayVoice;
      _loading = false;
      _statusText = identity == null ? '请先登录' : '准备好了';
    });

    if (identity != null) {
      await _checkHealth(silentWhenConnected: true);
    }
  }

  Future<UserIdentity> _login({
    required String username,
    required String password,
  }) async {
    final identity = await _identityStore.login(
      username: username,
      password: password,
    );
    await _activateIdentity(identity, '欢迎回来，${identity.username}');
    return identity;
  }

  Future<UserIdentity> _register({
    required String username,
    required String password,
    required String inviteCode,
  }) async {
    final identity = await _identityStore.register(
      username: username,
      password: password,
      inviteCode: inviteCode,
    );
    await _activateIdentity(identity, '账号已创建');
    return identity;
  }

  Future<void> _activateIdentity(
    UserIdentity identity,
    String statusText,
  ) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _identity = identity;
      _statusText = statusText;
    });
    await _checkHealth(silentWhenConnected: true);
  }

  Future<void> _logout() async {
    await _audioPlaybackService.stop();
    await _identityStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _identity = null;
      _currentLive2D = null;
      _selectedImagePath = '';
      _sending = false;
      _recording = false;
      _speaking = false;
      _statusText = '已退出登录';
    });
  }

  Future<void> _handleSpeakingChanged(bool speaking) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _speaking = speaking;
    });
    await _live2dBridge?.setSpeaking(speaking);
  }

  Future<void> _checkHealth({bool silentWhenConnected = false}) async {
    setState(() {
      _backendStatus = BackendStatus.checking();
      if (!silentWhenConnected) {
        _statusText = '正在检查连接...';
      }
    });

    try {
      final result = await _apiClient.getHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _backendStatus = result.ok
            ? BackendStatus.connected()
            : BackendStatus.disconnected('后端状态异常：${result.status}');
        _statusText = result.ok ? '准备好了' : '后端状态：${result.status}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final friendly = ChatErrorText.friendly(error);
      setState(() {
        _backendStatus = BackendStatus.disconnected(friendly);
        _statusText = friendly;
      });
    }
  }

  Future<void> _sendMessage() async {
    final rawText = _textController.text.trim();
    final identity = _identity;
    final imagePath = _selectedImagePath;

    if ((rawText.isEmpty && imagePath.isEmpty) ||
        identity == null ||
        _sending ||
        _recording) {
      return;
    }

    final text = rawText.isEmpty ? '请看看这张图片。' : rawText;
    final userMessage = ChatMessage.user(text: text, imagePath: imagePath);

    setState(() {
      _messages = [..._messages, userMessage];
      _textController.clear();
      _selectedImagePath = '';
      _sending = true;
      _chatPanelExpanded = true;
      _statusText = imagePath.isEmpty ? '正在发送...' : '正在发送图片...';
    });

    _scrollToBottomLater();

    try {
      if (imagePath.isEmpty) {
        await _sendTextToChat(text: text, identity: identity);
      } else {
        await _sendImageToChat(
          text: text,
          identity: identity,
          imagePath: imagePath,
        );
      }
    } catch (error) {
      await _appendSystemError(
        ChatErrorText.friendly(error),
        statusText: '发送失败',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
        _scrollToBottomLater();
      }
    }
  }

  Future<void> _sendTextToChat({
    required String text,
    required UserIdentity identity,
  }) async {
    await _audioPlaybackService.stop();
    final response = await _apiClient.sendChat(
      userId: identity.userId,
      username: identity.username,
      text: text,
    );
    await _appendAssistantResponse(response);
  }

  Future<void> _sendImageToChat({
    required String text,
    required UserIdentity identity,
    required String imagePath,
  }) async {
    await _audioPlaybackService.stop();
    final response = await _apiClient.sendMultimodalChat(
      userId: identity.userId,
      username: identity.username,
      text: text,
      imagePath: imagePath,
    );
    await _appendAssistantResponse(response);
  }

  Future<void> _appendAssistantResponse(ChatResponse response) async {
    final assistantMessage = ChatMessage.assistant(
      text: response.reply,
      emotion: response.emotion,
      motion: response.motion,
      expression: response.expression,
      audioUrl: response.audioUrl,
      live2d: response.live2d,
      requestId: response.requestId,
      memoryStatus: MemoryWriteStatus.fromMetadata(response.metadata),
    );
    final nextMessages = [..._messages, assistantMessage];

    if (!mounted) {
      return;
    }

    setState(() {
      _messages = nextMessages;
      _currentLive2D = response.live2d;
      _statusText = _memoryStatusText(response.metadata);
    });

    await _historyStore.save(nextMessages);
    if (_autoPlayVoice) {
      await _playResponseAudio(response.audioUrl, response.live2d);
    }
  }

  String _memoryStatusText(Map<String, dynamic> metadata) {
    final shouldStore = metadata['memory_write_should_store'];
    final storeStatus = metadata['memory_store_status']?.toString() ?? '';
    if (shouldStore == true && storeStatus != 'skipped') {
      return '已写入记忆';
    }
    if (storeStatus == 'skipped' || shouldStore == false) {
      return '临时聊天';
    }
    return '回复完成';
  }

  Future<void> _pickImageFromGallery() async {
    if (_sending || _recording) {
      return;
    }
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null || !mounted) {
      return;
    }
    setState(() {
      _selectedImagePath = image.path;
      _statusText = '图片已选择';
    });
  }

  Future<void> _takePhoto() async {
    if (_sending || _recording) {
      return;
    }
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null || !mounted) {
      return;
    }
    setState(() {
      _selectedImagePath = image.path;
      _statusText = '照片已准备好';
    });
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImagePath = '';
      _statusText = '已取消图片';
    });
  }

  Future<void> _toggleRecording() async {
    if (_sending && !_recording) {
      return;
    }
    if (_recording) {
      await _stopRecordingAndSend();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      await _audioPlaybackService.stop();
      await _recorderService.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = true;
        _statusText = '正在录音...';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = false;
        _statusText = ChatErrorText.friendly(error);
      });
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final identity = _identity;
    if (identity == null) {
      return;
    }
    setState(() {
      _sending = true;
      _statusText = '正在识别语音...';
    });

    try {
      final audioPath = await _recorderService.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = false;
      });

      final asrResult = await _apiClient.transcribeAudio(audioPath: audioPath);
      final transcript = asrResult.transcript.trim();
      if (transcript.isEmpty) {
        throw Exception('ASR 没有返回文本。');
      }

      final userMessage = ChatMessage.user(text: '[语音] $transcript');
      setState(() {
        _messages = [..._messages, userMessage];
        _chatPanelExpanded = true;
        _statusText = '语音识别完成，正在回复...';
      });
      _scrollToBottomLater();
      await _sendTextToChat(text: transcript, identity: identity);
    } catch (error) {
      await _appendSystemError(
        ChatErrorText.friendly(error),
        statusText: '语音输入失败',
      );
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _sending = false;
        });
        _scrollToBottomLater();
      }
    }
  }

  Future<void> _appendSystemError(
    String text, {
    required String statusText,
  }) async {
    final nextMessages = [..._messages, ChatMessage.system(text: text)];
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = nextMessages;
      _chatPanelExpanded = true;
      _statusText = statusText;
    });
    await _historyStore.save(nextMessages);
  }

  Future<void> _playResponseAudio(
    String responseAudioUrl,
    Live2DPayload? payload,
  ) async {
    final live2dAudioUrl = payload?.character.mouth.audioUrl ?? '';
    final audioUrl = responseAudioUrl.isNotEmpty
        ? responseAudioUrl
        : live2dAudioUrl;
    if (audioUrl.isEmpty) {
      return;
    }
    try {
      await _audioPlaybackService.playUrl(audioUrl);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = ChatErrorText.friendly(error);
      });
    }
  }

  Future<void> _playMessageAudio(ChatMessage message) async {
    final audioUrl = message.audioUrl.isNotEmpty
        ? message.audioUrl
        : message.live2d?.character.mouth.audioUrl ?? '';
    if (audioUrl.isEmpty) {
      setState(() {
        _statusText = '这条消息没有可播放的语音';
      });
      return;
    }
    try {
      await _audioPlaybackService.playUrl(audioUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '正在播放语音';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = ChatErrorText.friendly(error);
      });
    }
  }

  void _scrollToBottomLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _saveApiBaseUrl(String nextBaseUrl) async {
    if (nextBaseUrl.isEmpty) {
      return;
    }
    final nextConfig = _apiConfig.copyWith(apiBaseUrl: nextBaseUrl);
    await nextConfig.save();
    _apiClient.close();
    if (!mounted) {
      return;
    }
    setState(() {
      _apiConfig = nextConfig;
      _apiClient = ApiClient(config: nextConfig);
      _apiClientReady = true;
      _statusText = '服务器已更新';
    });
    await _checkHealth();
  }

  Future<void> _setAutoPlayVoice(bool value) async {
    await _preferences.setAutoPlayVoice(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _autoPlayVoice = value;
      _statusText = value ? '已开启自动播放语音' : '已关闭自动播放语音';
    });
    if (!value) {
      await _audioPlaybackService.stop();
    }
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return SettingsPage(
            apiBaseUrl: _apiConfig.apiBaseUrl,
            username: _identity?.username ?? '未登录',
            statusText: _statusText,
            autoPlayVoice: _autoPlayVoice,
            onSaveApiBaseUrl: _saveApiBaseUrl,
            onAutoPlayVoiceChanged: _setAutoPlayVoice,
            onOpenProfile: _openProfilePage,
            onOpenMemory: _openMemoryPage,
            onOpenAbout: _openAboutPage,
            onCheckHealth: _checkHealth,
            onClearHistory: _clearHistory,
            onLogout: _logout,
          );
        },
      ),
    );
  }

  Future<void> _openVoiceCallPage() async {
    final identity = _identity;
    if (identity == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) {
          return VoiceCallPage(
            apiClient: _apiClient,
            identity: identity,
            audioPlaybackService: _audioPlaybackService,
            recorderService: _recorderService,
            onAssistantResponse: _appendVoiceCallResponse,
            onLive2DChanged: (payload) {
              setState(() {
                _currentLive2D = payload;
              });
            },
            onSpeakingChanged: _handleSpeakingChanged,
          );
        },
      ),
    );
  }

  Future<void> _appendVoiceCallResponse(VoiceCallTurnResponse response) async {
    final messages = [..._messages];
    if (response.transcript.trim().isNotEmpty) {
      messages.add(ChatMessage.user(text: '[通话] ${response.transcript}'));
    }
    messages.add(
      ChatMessage.assistant(
        text: response.chat.reply,
        emotion: response.chat.emotion,
        motion: response.chat.motion,
        expression: response.chat.expression,
        audioUrl: response.chat.audioUrl,
        live2d: response.chat.live2d,
        requestId: response.requestId,
        memoryStatus: MemoryWriteStatus.fromMetadata(response.chat.metadata),
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _messages = messages;
      _currentLive2D = response.chat.live2d;
      _statusText = '通话回复完成';
    });
    await _historyStore.save(messages);
  }

  Future<void> _openAboutPage() async {
    final identity = _identity;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return AboutPage(
            apiBaseUrl: _apiConfig.apiBaseUrl,
            username: identity?.username ?? '未登录',
            userId: identity?.userId ?? '',
          );
        },
      ),
    );
  }

  Future<void> _openProfilePage() async {
    final identity = _identity;
    if (identity == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ProfilePage(identity: identity, onSave: _saveIdentity);
        },
      ),
    );
  }

  Future<void> _saveIdentity(UserIdentity identity) async {
    await _identityStore.save(identity);
    if (!mounted) {
      return;
    }

    setState(() {
      _identity = identity;
      _statusText = '资料已更新';
    });
  }

  Future<void> _openMemoryPage() async {
    final identity = _identity;
    if (identity == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return MemoryPage(apiClient: _apiClient, userId: identity.userId);
        },
      ),
    );
  }

  Future<void> _clearHistory() async {
    await _audioPlaybackService.stop();
    await _historyStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = [];
      _currentLive2D = null;
      _selectedImagePath = '';
      _chatPanelExpanded = false;
      _statusText = '聊天历史已清空';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_identity == null) {
      return AuthPage(onLogin: _login, onRegister: _register);
    }

    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardBottom > 0;
    final stageOffset = keyboardOpen ? -keyboardBottom * 0.42 : 0.0;
    final stageScale = keyboardOpen ? 0.82 : 1.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _StageBackground(),
          AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            offset: Offset(0, stageOffset / MediaQuery.sizeOf(context).height),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              scale: stageScale,
              alignment: Alignment.topCenter,
              child: Live2DStageView(
                statusText: _statusText,
                payload: _currentLive2D,
                expand: true,
                onBridgeReady: (bridge) {
                  _live2dBridge = bridge;
                },
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopOverlayBar(
                  username: _identity?.username ?? 'AIAgent',
                  status: _backendStatus,
                  speaking: _speaking,
                  onOpenVoiceCall: _openVoiceCallPage,
                  onOpenSettings: _openSettingsPage,
                  onCheckHealth: () => _checkHealth(),
                  onStopAudio: _audioPlaybackService.stop,
                ),
                const Spacer(),
                _ChatPanel(
                  expanded: _chatPanelExpanded,
                  statusText: _statusText,
                  messages: _messages,
                  controller: _scrollController,
                  onToggleExpanded: () {
                    setState(() {
                      _chatPanelExpanded = !_chatPanelExpanded;
                    });
                    _scrollToBottomLater();
                  },
                  onPlayAudio: _playMessageAudio,
                ),
                _InputBar(
                  controller: _textController,
                  sending: _sending,
                  recording: _recording,
                  selectedImagePath: _selectedImagePath,
                  onSend: _sendMessage,
                  onRecord: _toggleRecording,
                  onPickImage: _pickImageFromGallery,
                  onTakePhoto: _takePhoto,
                  onClearImage: _clearSelectedImage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBackground extends StatelessWidget {
  const _StageBackground();

  static const String _bedroomImageUrl =
      'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _bedroomImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE9F1ED),
                    Color(0xFFFFF6EF),
                    Color(0xFFF3C8BD),
                  ],
                ),
              ),
            );
          },
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.30)),
      ],
    );
  }
}

class _TopOverlayBar extends StatelessWidget {
  const _TopOverlayBar({
    required this.username,
    required this.status,
    required this.speaking,
    required this.onOpenVoiceCall,
    required this.onOpenSettings,
    required this.onCheckHealth,
    required this.onStopAudio,
  });

  final String username;
  final BackendStatus status;
  final bool speaking;
  final VoidCallback onOpenVoiceCall;
  final VoidCallback onOpenSettings;
  final VoidCallback onCheckHealth;
  final VoidCallback onStopAudio;

  @override
  Widget build(BuildContext context) {
    final connected = status.state == BackendConnectionState.connected;
    final checking = status.state == BackendConnectionState.checking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: _TranslucentPanel(
              alpha: 0.34,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      connected
                          ? Icons.cloud_done_outlined
                          : checking
                          ? Icons.sync
                          : Icons.cloud_off_outlined,
                      size: 18,
                      color: connected
                          ? const Color(0xFF23745B)
                          : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            tooltip: '检查连接',
            onPressed: onCheckHealth,
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            tooltip: '实时语音通话',
            onPressed: onOpenVoiceCall,
            icon: Icons.call_outlined,
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            tooltip: speaking ? '停止语音' : '暂无语音播放',
            onPressed: speaking ? onStopAudio : null,
            icon: speaking ? Icons.volume_up : Icons.volume_off_outlined,
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            tooltip: '设置',
            onPressed: onOpenSettings,
            icon: Icons.settings_outlined,
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _TranslucentPanel(
      alpha: onPressed == null ? 0.12 : 0.18,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: const Color(0xFF2B2B2B),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.expanded,
    required this.statusText,
    required this.messages,
    required this.controller,
    required this.onToggleExpanded,
    required this.onPlayAudio,
  });

  final bool expanded;
  final String statusText;
  final List<ChatMessage> messages;
  final ScrollController controller;
  final VoidCallback onToggleExpanded;
  final ValueChanged<ChatMessage> onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final latest = messages.isEmpty ? '开始聊天吧' : messages.last.text;
    final panelHeight = expanded
        ? (MediaQuery.sizeOf(context).height * 0.34).clamp(180.0, 310.0)
        : 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: panelHeight,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: _TranslucentPanel(
        alpha: 0.30,
        child: Column(
          children: [
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        expanded ? statusText : latest,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                    Text(
                      '${messages.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('还没有消息'))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(
                            message: messages[index],
                            onPlayAudio: onPlayAudio,
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onPlayAudio});

  final ChatMessage message;
  final ValueChanged<ChatMessage> onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final isSystem = message.role == ChatRole.system;
    final hasAudio =
        message.audioUrl.isNotEmpty ||
        (message.live2d?.character.mouth.audioUrl ?? '').isNotEmpty;
    final imagePath = message.imagePath;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          MessageActions.show(
            context: context,
            message: message,
            onPlayAudio: onPlayAudio,
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isUser ? 0.42 : 0.36),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser
                    ? '你'
                    : isSystem
                    ? '系统'
                    : 'AIAgent',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (imagePath.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(imagePath),
                    width: 280,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 280,
                        height: 80,
                        child: Center(child: Text('图片无法显示')),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(message.text),
              if (message.role == ChatRole.assistant &&
                  message.memoryStatus.visible) ...[
                const SizedBox(height: 8),
                MemoryStatusChip(status: message.memoryStatus),
              ],
              if (hasAudio) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => onPlayAudio(message),
                  icon: const Icon(Icons.volume_up_outlined, size: 16),
                  label: const Text('播放语音'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.recording,
    required this.selectedImagePath,
    required this.onSend,
    required this.onRecord,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onClearImage,
  });

  final TextEditingController controller;
  final bool sending;
  final bool recording;
  final String selectedImagePath;
  final VoidCallback onSend;
  final VoidCallback onRecord;
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _TranslucentPanel(
        alpha: 0.34,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedImagePath.isNotEmpty) ...[
                _SelectedImagePreview(
                  imagePath: selectedImagePath,
                  onClear: onClearImage,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  _InputIconButton(
                    onPressed: sending || recording ? null : onPickImage,
                    icon: Icons.photo_outlined,
                    tooltip: '选择图片',
                  ),
                  const SizedBox(width: 6),
                  _InputIconButton(
                    onPressed: sending || recording ? null : onTakePhoto,
                    icon: Icons.photo_camera_outlined,
                    tooltip: '拍照',
                  ),
                  const SizedBox(width: 6),
                  _InputIconButton(
                    onPressed: sending && !recording ? null : onRecord,
                    icon: recording ? Icons.stop : Icons.mic,
                    tooltip: recording ? '停止录音' : '开始录音',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !recording,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: recording ? '正在录音...' : '输入消息...',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.46),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      onPressed: sending || recording ? null : onSend,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: sending && !recording
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  const _InputIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: tooltip,
      ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.imagePath, required this.onClear});

  final String imagePath;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imagePath),
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('图片已准备好', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            tooltip: '移除图片',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _TranslucentPanel extends StatelessWidget {
  const _TranslucentPanel({required this.child, required this.alpha});

  final Widget child;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
