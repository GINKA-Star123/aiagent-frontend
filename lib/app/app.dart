import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:uuid/uuid.dart';

import '../about/about_page.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_models.dart';
import '../auth/activation_page.dart';
import '../auth/auth_page.dart';
import '../audio/audio_playback_service.dart';
import '../audio/recorder_service.dart';
import '../chat/chat_error.dart';
import '../chat/chat_history_store.dart';
import '../chat/chat_message.dart';
import '../chat/memory_status.dart';
import '../chat/chat_search_page.dart';
import '../chat/draft_store.dart';
import '../chat/message_actions.dart';
import '../connectivity/backend_status.dart';
import '../core/activation.dart';
import '../core/feedback_store.dart';
import '../core/outbox.dart';
import '../core/session_store.dart';
import '../core/telemetry.dart';
import '../identity/identity_store.dart';
import '../identity/user_identity.dart';
import '../memory/memory_page.dart';
import '../profile/avatar_store.dart';
import '../profile/background_store.dart';
import '../profile/profile_page.dart';
import '../session/presence_opening_gate.dart';
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

class _ChatHomePageState extends State<ChatHomePage>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  String _highlightedMessageKey = '';
  Timer? _highlightTimer;
  final ImagePicker _imagePicker = ImagePicker();

  late ApiClient _apiClient;
  late final IdentityStore _identityStore;
  late final ChatHistoryStore _historyStore;
  late final AppPreferences _preferences;
  late final AudioPlaybackService _audioPlaybackService;
  late final RecorderService _recorderService;
  late final PresenceOpeningGate _presenceOpeningGate;
  late final SessionStore _sessionStore;
  late final OutboxStore _outboxStore;
  late final FeedbackStore _feedbackStore;
  Map<String, Map<String, dynamic>> _feedback = {};
  String _myAvatarPath = '';
  String _agentAvatarPath = '';
  String _backgroundPath = '';
  double _backgroundDim = BackgroundStore.defaultDim;
  double _backgroundBlur = BackgroundStore.defaultBlur;
  TelemetryService? _telemetry;

  final Uuid _uuid = const Uuid();
  List<OutboxEntry> _outbox = [];
  bool _online = true;
  bool _flushingOutbox = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _outboxTimer;

  static const bool _authUiEnabled = bool.fromEnvironment(
    'AUTH_UI_ENABLED',
    defaultValue: false,
  );

  StreamSubscription<bool>? _speakingSubscription;

  ApiConfig _apiConfig = ApiConfig.defaults();
  UserIdentity? _identity;
  BackendStatus _backendStatus = BackendStatus.unknown();
  List<ChatMessage> _messages = [];

  bool _apiClientReady = false;
  bool _needsActivation = false;
  bool _loading = true;
  bool _sending = false;
  bool _speaking = false;
  bool _recording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  bool _autoPlayVoice = true;
  double _chatFontSize = AppPreferences.defaultChatFontSize;
  Timer? _draftTimer;
  bool _openingRequested = false;
  bool _showJumpToBottom = false;
  String _playingAudioKey = '';
  ChatMessage? _quotedMessage;
  final FocusNode _composerFocus = FocusNode();
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
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(_onDraftChanged);
    _itemPositionsListener.itemPositions.addListener(_handlePositions);
    _initConnectivity();
    _bootstrap();
  }

  @override
  void dispose() {
    _textController.removeListener(_onDraftChanged);
    _textController.dispose();
    _draftTimer?.cancel();
    _recordingTimer?.cancel();
    _composerFocus.dispose();
    _itemPositionsListener.itemPositions.removeListener(_handlePositions);
    _highlightTimer?.cancel();
    _speakingSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _outboxTimer?.cancel();
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
    _presenceOpeningGate = const PresenceOpeningGate();
    _sessionStore = SessionStore();
    _outboxStore = OutboxStore();
    _feedbackStore = FeedbackStore();
    _preferences = await AppPreferences.load();
    _chatFontSize = _preferences.chatFontSize;

    final storedCode = await _sessionStore.loadActivationCode();
    final envCode = ActivationConfig.rawFromEnvironment();
    final rawCode = (storedCode != null && storedCode.isNotEmpty)
        ? storedCode
        : (envCode.isEmpty ? null : envCode);

    if (rawCode == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _needsActivation = true;
        _statusText = '需要激活';
      });
      return;
    }

    await _applyActivation(rawCode);
  }

  Future<void> _applyActivation(String rawCode) async {
    ActivationConfig config;
    try {
      config = ActivationConfig.decode(rawCode);
    } on ActivationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _needsActivation = true;
        _statusText = error.message;
      });
      return;
    }

    final history = await _historyStore.load();
    final existing = await _identityStore.load();
    final sameUser = existing != null && existing.userId == config.userId;
    final identity = UserIdentity(
      userId: config.userId,
      username: sameUser && existing.username.isNotEmpty
          ? existing.username
          : config.username,
      deviceId:
          existing?.deviceId ??
          'device_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: existing?.createdAt ?? DateTime.now(),
      accessToken: config.token,
      refreshToken: existing?.refreshToken ?? '',
    );
    await _identityStore.save(identity);
    final draft = await DraftStore.load(identity.userId);

    if (!mounted) {
      return;
    }

    final apiConfig = ApiConfig(
      environment: config.primaryBaseUrl.startsWith('https://')
          ? 'cloud'
          : 'dev',
      apiBaseUrl: config.primaryBaseUrl,
      timeoutSeconds: 120,
    );

    final apiClient = ApiClient(
      config: apiConfig,
      token: config.token,
      baseUrls: config.baseUrls,
    );
    _telemetry = TelemetryService(
      sender: (batchId, app, events) => apiClient.sendTelemetryBatch(
        batchId: batchId,
        app: app,
        events: events,
      ),
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '1.3.0',
      ),
      platform: Platform.operatingSystem,
    );
    setState(() {
      _apiConfig = apiConfig;
      _apiClient = apiClient;
      _apiClientReady = true;
      _identity = identity;
      _messages = history;
      _autoPlayVoice = _preferences.autoPlayVoice;
      _chatFontSize = _preferences.chatFontSize;
      if (draft.isNotEmpty) {
        _textController.text = draft;
        _textController.selection = TextSelection.collapsed(
          offset: draft.length,
        );
      }
      _loading = false;
      _needsActivation = false;
      _statusText = '准备好了';
    });

    await _loadAvatars();
    await _restoreOutbox();
    _feedback = await _feedbackStore.load();
    final telemetry = _telemetry;
    if (telemetry != null) {
      unawaited(telemetry.flush());
    }
    await _checkHealth(silentWhenConnected: true);
    await _openPresenceSession();
  }

  Future<void> _handleActivated(String rawCode) async {
    await _sessionStore.saveActivationCode(rawCode);
    await _applyActivation(rawCode);
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
      _openingRequested = false;
    });
    final draft = await DraftStore.load(identity.userId);
    if (mounted && draft.isNotEmpty && _textController.text.isEmpty) {
      _textController.text = draft;
      _textController.selection = TextSelection.collapsed(offset: draft.length);
    }
    await _loadAvatars();
    await _checkHealth(silentWhenConnected: true);
    await _openPresenceSession();
  }

  Future<void> _logout() async {
    final identity = _identity;
    if (identity != null) {
      await DraftStore.clear(identity.userId);
    }
    _textController.clear();
    _draftTimer?.cancel();
    await _audioPlaybackService.stop();
    await _sessionStore.clear();
    await _identityStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _identity = null;
      _needsActivation = true;
      _selectedImagePath = '';
      _quotedMessage = null;
      _myAvatarPath = '';
      _agentAvatarPath = '';
      _backgroundPath = '';
      _sending = false;
      _recording = false;
      _speaking = false;
      _openingRequested = false;
      _statusText = '已退出登录';
    });
  }

  Future<void> _handleSpeakingChanged(bool speaking) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _speaking = speaking;
      if (!speaking) {
        _playingAudioKey = '';
        if (_statusText == '正在播放语音') {
          _statusText = '语音播放结束';
        }
      }
    });
  }

  Future<void> _openPresenceSession({bool force = false}) async {
    final identity = _identity;
    if (identity == null || !_apiClientReady || (!force && _openingRequested)) {
      return;
    }

    _openingRequested = true;

    if (!force) {
      final shouldShow = await _presenceOpeningGate.shouldShow(
        userId: identity.userId,
      );
      if (!shouldShow) {
        return;
      }
    }

    try {
      final opening = await _apiClient.openSession(
        userId: identity.userId,
        username: identity.username,
        recentTopic: _lastUserFacingTopic(),
      );

      if (!mounted || opening.text.trim().isEmpty) {
        return;
      }

      setState(() {
        _statusText = opening.statusText;
      });

      await Future<void>.delayed(
        Duration(milliseconds: opening.suggestedDelayMs),
      );

      if (!mounted || !opening.shouldSpeak) {
        return;
      }

      final message = ChatMessage.assistant(
        text: opening.text,
        emotion: opening.mood,
      );
      final nextMessages = [..._messages, message];

      setState(() {
        _messages = nextMessages;
        _statusText = opening.statusText;
      });

      await _presenceOpeningGate.markShown(userId: identity.userId);
      await _historyStore.save(nextMessages);
      _scrollToBottomLater();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '准备好了';
      });
    }
  }

  String _lastUserFacingTopic() {
    for (final message in _messages.reversed) {
      if (message.role == ChatRole.user && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return '';
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
      final authFailure = ApiClient.isAuthFailure(error);
      setState(() {
        _backendStatus = BackendStatus.disconnected(friendly);
        _statusText = authFailure ? '激活已失效，请重新激活' : friendly;
        if (authFailure) {
          _needsActivation = true;
        }
      });
    }
  }

  void _quoteMessage(ChatMessage message) {
    setState(() {
      _quotedMessage = message;
      _statusText = '引用了一条消息';
    });
    _composerFocus.requestFocus();
  }

  String _composeQuotedText(ChatMessage quote, String body) {
    final sender = quote.role == ChatRole.user ? '我' : 'AIAgent';
    final raw = quote.text.replaceAll('\n', ' ').trim();
    final snippet = raw.length > 60 ? '${raw.substring(0, 60)}…' : raw;
    return '> [$sender] $snippet\n\n$body';
  }

  Future<void> _sendMessage() async {
    final rawText = _textController.text.trim();
    final identity = _identity;
    final imagePath = _selectedImagePath;

    if ((rawText.isEmpty && imagePath.isEmpty) ||
        identity == null ||
        _recording) {
      return;
    }

    final baseText = rawText.isEmpty ? '请看看这张图片。' : rawText;
    final quote = _quotedMessage;
    final text = quote == null ? baseText : _composeQuotedText(quote, baseText);
    final message = ChatMessage.user(
      text: text,
      imagePath: imagePath,
      clientMessageId: _newClientMessageId(),
      status: ChatMessageStatus.sending,
    );

    setState(() {
      _messages = [..._messages, message];
      _textController.clear();
      _selectedImagePath = '';
      _quotedMessage = null;
      _sending = true;
      _statusText = imagePath.isEmpty ? '正在发送...' : '正在发送图片...';
    });
    await DraftStore.clear(identity.userId);
    await _historyStore.save(_messages);
    _scrollToBottomLater();

    await _deliverMessage(message, identity);
  }

  Future<void> _deliverMessage(
    ChatMessage message,
    UserIdentity identity, {
    bool manageSending = true,
    bool voice = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    var httpStatus = 0;
    var degradedOutcome = false;
    var ttsPlayed = false;
    try {
      final response = message.imagePath.isEmpty
          ? await _apiClient.sendChat(
              userId: identity.userId,
              username: identity.username,
              text: message.text,
              clientMessageId: message.clientMessageId,
            )
          : await _apiClient.sendMultimodalChat(
              userId: identity.userId,
              username: identity.username,
              text: message.text,
              imagePath: message.imagePath,
              clientMessageId: message.clientMessageId,
            );

      httpStatus = 200;
      degradedOutcome = response.degraded;
      ttsPlayed = _autoPlayVoice && response.audioUrl.isNotEmpty;
      final status = response.degraded
          ? ChatMessageStatus.degraded
          : ChatMessageStatus.sent;
      _updateMessage(
        message.clientMessageId,
        (item) => item.copyWith(status: status, requestId: response.requestId),
      );
      await _removeFromOutbox(message.clientMessageId);
      await _appendAssistantResponse(response);
    } catch (error) {
      if (ApiClient.isAuthFailure(error)) {
        if (mounted) {
          setState(() {
            _needsActivation = true;
            _statusText = '激活已失效，请重新激活';
          });
        }
        return;
      }
      if (ApiClient.isNetworkFailure(error)) {
        httpStatus = -1;
        await _markQueued(message);
        return;
      }
      httpStatus = -2;
      _updateMessage(
        message.clientMessageId,
        (item) => item.copyWith(
          status: ChatMessageStatus.failed,
          errorText: ChatErrorText.friendly(error),
        ),
      );
      await _appendSystemError(
        ChatErrorText.friendly(error),
        statusText: '发送失败',
      );
    } finally {
      stopwatch.stop();
      _recordTelemetry(
        message,
        status: httpStatus,
        degraded: degradedOutcome,
        latencyMs: stopwatch.elapsedMilliseconds,
        ttsPlayed: ttsPlayed,
        voice: voice,
      );
      if (mounted) {
        if (manageSending) {
          setState(() {
            _sending = false;
          });
        }
        _scrollToBottomLater();
      }
    }
  }

  Future<void> _sendFeedback(
    ChatMessage message,
    int rating,
    List<String> tags,
  ) async {
    final key = message.requestId.isNotEmpty
        ? message.requestId
        : message.clientMessageId;
    if (key.isEmpty) {
      return;
    }
    await _feedbackStore.set(key, rating, tags);
    final updated = await _feedbackStore.load();
    if (mounted) {
      setState(() {
        _feedback = updated;
        _statusText = rating > 0 ? '已记录：有帮助' : '已记录：待改进';
      });
    }
    final telemetry = _telemetry;
    if (telemetry != null) {
      unawaited(
        telemetry
            .recordFeedback(messageId: key, rating: rating, tags: tags)
            .then((_) => telemetry.flush()),
      );
    }
  }

  void _recordTelemetry(
    ChatMessage message, {
    required int status,
    required bool degraded,
    required int latencyMs,
    required bool ttsPlayed,
    required bool voice,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    unawaited(
      telemetry
          .recordTurn(
            clientMessageId: message.clientMessageId,
            latencyMs: latencyMs,
            status: status,
            degraded: degraded,
            textLen: message.text.length,
            hasImage: message.imagePath.isNotEmpty,
            ttsPlayed: ttsPlayed,
            attempts: message.attempts,
            voice: voice,
          )
          .then((_) => telemetry.flush()),
    );
  }

  void _updateMessage(
    String clientMessageId,
    ChatMessage Function(ChatMessage message) update,
  ) {
    if (clientMessageId.isEmpty) {
      return;
    }
    var changed = false;
    final next = _messages.map((message) {
      if (message.clientMessageId != clientMessageId) {
        return message;
      }
      changed = true;
      return update(message);
    }).toList();
    if (changed && mounted) {
      setState(() {
        _messages = next;
      });
    }
  }

  Future<void> _markQueued(ChatMessage message) async {
    final attempts = message.attempts + 1;
    final delay = outboxBackoff(attempts);
    _updateMessage(
      message.clientMessageId,
      (item) => item.copyWith(
        status: ChatMessageStatus.queued,
        attempts: attempts,
        errorText: '网络不稳定',
      ),
    );
    _outbox = [
      ..._outbox.where(
        (entry) => entry.clientMessageId != message.clientMessageId,
      ),
      OutboxEntry(
        clientMessageId: message.clientMessageId,
        text: message.text,
        imagePath: message.imagePath,
        createdAt: message.createdAt,
        attempts: attempts,
        nextAttemptAt: DateTime.now().add(delay),
      ),
    ];
    await _outboxStore.save(_outbox);
    await _historyStore.save(_messages);
    if (mounted) {
      setState(() {
        _online = false;
        _statusText = '网络不稳定，已排队（${delay.inSeconds}s 后自动重试）';
      });
    }
    _scheduleOutboxFlush();
  }

  Future<void> _removeFromOutbox(String clientMessageId) async {
    if (clientMessageId.isEmpty) {
      return;
    }
    if (!_outbox.any((entry) => entry.clientMessageId == clientMessageId)) {
      return;
    }
    _outbox = _outbox
        .where((entry) => entry.clientMessageId != clientMessageId)
        .toList();
    await _outboxStore.save(_outbox);
  }

  Future<void> _restoreOutbox() async {
    _outbox = await _outboxStore.load();
    if (_outbox.isEmpty) {
      return;
    }
    final next = [..._messages];
    for (final entry in _outbox) {
      final exists = next.any(
        (message) => message.clientMessageId == entry.clientMessageId,
      );
      if (!exists) {
        next.add(
          ChatMessage.user(
            text: entry.text,
            imagePath: entry.imagePath,
            clientMessageId: entry.clientMessageId,
            status: ChatMessageStatus.queued,
            attempts: entry.attempts,
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _messages = next;
        _statusText = '有 ${_outbox.length} 条消息待重发';
      });
    }
    _scheduleOutboxFlush();
  }

  Future<void> _flushOutbox() async {
    final identity = _identity;
    if (_flushingOutbox || identity == null || !_online) {
      return;
    }
    final due = _outbox.where((entry) => entry.isDue).toList();
    if (due.isEmpty) {
      _scheduleOutboxFlush();
      return;
    }

    _flushingOutbox = true;
    try {
      for (final entry in due) {
        final existing = _messages
            .where(
              (message) => message.clientMessageId == entry.clientMessageId,
            )
            .toList();
        ChatMessage message;
        if (existing.isEmpty) {
          message = ChatMessage.user(
            text: entry.text,
            imagePath: entry.imagePath,
            clientMessageId: entry.clientMessageId,
            status: ChatMessageStatus.sending,
            attempts: entry.attempts,
          );
          if (mounted) {
            setState(() {
              _messages = [..._messages, message];
            });
          }
        } else {
          message = existing.first.copyWith(status: ChatMessageStatus.sending);
          _updateMessage(entry.clientMessageId, (_) => message);
        }
        await _deliverMessage(message, identity, manageSending: false);
        if (_outbox.any(
          (item) => item.clientMessageId == entry.clientMessageId,
        )) {
          break;
        }
      }
    } finally {
      _flushingOutbox = false;
      _scheduleOutboxFlush();
    }
  }

  void _scheduleOutboxFlush() {
    _outboxTimer?.cancel();
    if (_outbox.isEmpty) {
      return;
    }
    _outboxTimer = Timer(const Duration(seconds: 15), () {
      _flushOutbox();
    });
  }

  Future<void> _retryMessage(ChatMessage message) async {
    final identity = _identity;
    if (identity == null || _sending) {
      return;
    }
    _updateMessage(
      message.clientMessageId,
      (item) => item.copyWith(status: ChatMessageStatus.sending, errorText: ''),
    );
    if (mounted) {
      setState(() {
        _sending = true;
        _statusText = '正在重试...';
      });
    }
    await _removeFromOutbox(message.clientMessageId);
    await _deliverMessage(message, identity);
  }

  String _newClientMessageId() {
    return _uuid.v4();
  }

  Future<void> _initConnectivity() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      _online = !results.contains(ConnectivityResult.none);
      _connectivitySub = connectivity.onConnectivityChanged.listen((changes) {
        final online = !changes.contains(ConnectivityResult.none);
        if (online == _online) {
          return;
        }
        _online = online;
        if (mounted) {
          setState(() {
            _statusText = online ? '网络已恢复' : '网络已断开，消息会先排队';
          });
        }
        if (online) {
          _flushOutbox();
        }
      });
    } catch (_) {
      _online = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flushOutbox();
    }
  }

  Future<void> _appendAssistantResponse(ChatResponse response) async {
    final assistantMessage = ChatMessage.assistant(
      text: response.reply,
      emotion: response.emotion,
      motion: response.motion,
      expression: response.expression,
      audioUrl: response.audioUrl,
      requestId: response.requestId,
      status: response.degraded
          ? ChatMessageStatus.degraded
          : ChatMessageStatus.sent,
      retryAfterSeconds: response.retryAfterSeconds,
      memoryStatus: MemoryWriteStatus.fromMetadata(response.metadata),
    );
    final nextMessages = [..._messages, assistantMessage];

    if (!mounted) {
      return;
    }

    setState(() {
      _messages = nextMessages;
      _statusText = response.degraded
          ? '服务繁忙，已给出降级回复'
          : _memoryStatusText(response.metadata);
    });

    await _historyStore.save(nextMessages);
    if (_autoPlayVoice) {
      await _playResponseAudio(response.audioUrl);
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
        _recordingSeconds = 0;
        _statusText = '正在录音...';
      });
      _startRecordingTimer();
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

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingSeconds += 1;
      });
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    try {
      await _recorderService.cancel();
    } catch (_) {
      // 取消失败也恢复界面状态。
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _recording = false;
      _recordingSeconds = 0;
      _statusText = '已取消录音';
    });
  }

  Future<void> _sendTextToChat({
    required String text,
    required UserIdentity identity,
  }) async {
    await _audioPlaybackService.stop();
    final message = ChatMessage.user(
      text: text,
      clientMessageId: _newClientMessageId(),
      status: ChatMessageStatus.sending,
    );
    if (mounted) {
      setState(() {
        _messages = [..._messages, message];
      });
    }
    await _historyStore.save(_messages);
    await _deliverMessage(message, identity, voice: true);
  }

  Future<void> _stopRecordingAndSend() async {
    _recordingTimer?.cancel();
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
        _recordingSeconds = 0;
      });

      final asrResult = await _apiClient.transcribeAudio(audioPath: audioPath);
      final transcript = asrResult.transcript.trim();
      if (transcript.isEmpty) {
        throw Exception('ASR 没有返回文本。');
      }

      final userMessage = ChatMessage.user(text: '[语音] $transcript');
      setState(() {
        _messages = [..._messages, userMessage];
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
          _recordingSeconds = 0;
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
      _statusText = statusText;
    });
    await _historyStore.save(nextMessages);
  }

  String _messageKey(ChatMessage message) {
    return message.requestId.isNotEmpty
        ? message.requestId
        : message.clientMessageId;
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除消息'),
          content: const Text('只删除本机这条消息，不影响服务器记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final next = [..._messages]..remove(message);
    if (message.clientMessageId.isNotEmpty) {
      await _removeFromOutbox(message.clientMessageId);
    }
    if (_playingAudioKey.isNotEmpty &&
        _playingAudioKey == _messageKey(message)) {
      await _audioPlaybackService.stop();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = next;
      if (_quotedMessage == message) {
        _quotedMessage = null;
      }
      _statusText = '已删除消息';
    });
    await _historyStore.save(next);
  }

  void _openImageViewer(String path) {
    final images = _messages
        .where((message) => message.imagePath.isNotEmpty)
        .map((message) => message.imagePath)
        .toList();
    if (images.isEmpty) {
      return;
    }
    var index = images.indexOf(path);
    if (index < 0) {
      index = 0;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return _ImagePager(imagePaths: images, initialIndex: index);
      },
    );
  }

  Future<void> _playResponseAudio(String responseAudioUrl) async {
    final audioUrl = _apiClient.authorizedAudioUrl(responseAudioUrl);
    if (audioUrl.isEmpty) {
      return;
    }
    try {
      await _audioPlaybackService.playUrl(audioUrl);
    } catch (_) {
      if (!mounted) {
        return;
      }
      // 自动播放失败只提示，不覆盖聊天状态，避免看起来像回复失败。
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('语音播放失败，可点“播放语音”重试')));
    }
  }

  Future<void> _playMessageAudio(ChatMessage message) async {
    final key = _messageKey(message);
    final audioUrl = _apiClient.authorizedAudioUrl(message.audioUrl);
    if (audioUrl.isEmpty) {
      setState(() {
        _statusText = '这条消息没有可播放的语音';
      });
      return;
    }
    if (_playingAudioKey == key && _speaking) {
      await _audioPlaybackService.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _playingAudioKey = '';
        _statusText = '已停止播放';
      });
      return;
    }
    try {
      await _audioPlaybackService.playUrl(audioUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _playingAudioKey = key;
        _statusText = '正在播放语音';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playingAudioKey = '';
        _statusText = '语音播放失败，可稍后重试';
      });
    }
  }

  void _onDraftChanged() {
    final identity = _identity;
    if (identity == null) {
      return;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      DraftStore.save(identity.userId, _textController.text);
    });
  }

  void _handlePositions() {
    if (!mounted) {
      return;
    }
    if (_messages.isEmpty) {
      if (_showJumpToBottom) {
        setState(() {
          _showJumpToBottom = false;
        });
      }
      return;
    }
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) {
      return;
    }
    final lastIndex = _messages.length - 1;
    final lastVisible = positions.any(
      (position) => position.index >= lastIndex,
    );
    final show = !lastVisible;
    if (show == _showJumpToBottom) {
      return;
    }
    setState(() {
      _showJumpToBottom = show;
    });
  }

  int get _typingItemIndex {
    if (_sending &&
        !_recording &&
        _messages.isNotEmpty &&
        _messages.last.role == ChatRole.user) {
      return _messages.length;
    }
    return -1;
  }

  void _jumpToBottom() {
    if (!_itemScrollController.isAttached || _messages.isEmpty) {
      return;
    }
    final typingIndex = _typingItemIndex;
    final index = typingIndex >= 0 ? typingIndex : _messages.length - 1;
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottomLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_itemScrollController.isAttached || _messages.isEmpty) {
        return;
      }
      final typingIndex = _typingItemIndex;
      final index = typingIndex >= 0 ? typingIndex : _messages.length - 1;
      _itemScrollController.scrollTo(
        index: index,
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
      _openingRequested = false;
      _statusText = '服务器已更新';
    });
    await _checkHealth();
    await _openPresenceSession(force: true);
  }

  Future<void> _setChatFontSize(double value) async {
    await _preferences.setChatFontSize(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _chatFontSize = value;
    });
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

  Future<void> _openChatSearch() async {
    final selected = await Navigator.of(context).push<ChatMessage>(
      MaterialPageRoute<ChatMessage>(
        builder: (context) => ChatSearchPage(messages: _messages),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    var index = _messages.indexWhere((message) => identical(message, selected));
    if (index < 0 && selected.clientMessageId.isNotEmpty) {
      index = _messages.indexWhere(
        (message) => message.clientMessageId == selected.clientMessageId,
      );
    }
    if (index < 0) {
      return;
    }
    setState(() {
      _highlightedMessageKey = _messageKey(selected);
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _highlightedMessageKey = '';
      });
    });
    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    }
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return SettingsPage(
            userId: _identity?.userId ?? '',
            myAvatarPath: _myAvatarPath,
            agentAvatarPath: _agentAvatarPath,
            backgroundPath: _backgroundPath,
            backgroundDim: _backgroundDim,
            backgroundBlur: _backgroundBlur,
            onAvatarsChanged: _loadAvatars,
            onBackgroundChanged: _loadAvatars,
            apiBaseUrl: _apiConfig.apiBaseUrl,
            username: _identity?.username ?? '未登录',
            statusText: _statusText,
            autoPlayVoice: _autoPlayVoice,
            chatFontSize: _chatFontSize,
            onChatFontSizeChanged: _setChatFontSize,
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
        requestId: response.requestId,
        memoryStatus: MemoryWriteStatus.fromMetadata(response.chat.metadata),
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _messages = messages;
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
    _outbox = [];
    await _outboxStore.save(_outbox);
    final identity = _identity;
    if (identity != null) {
      await DraftStore.clear(identity.userId);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = [];

      _selectedImagePath = '';
      _quotedMessage = null;
      _statusText = '聊天历史已清空';
    });
  }

  Future<void> _loadAvatars() async {
    final identity = _identity;
    if (identity == null) {
      return;
    }
    final myAvatar = await AvatarStore.load(identity.userId, AvatarOwner.user);
    final agentAvatar = await AvatarStore.load(
      identity.userId,
      AvatarOwner.agent,
    );
    final background = await BackgroundStore.load(identity.userId);
    final dim = await BackgroundStore.loadDim(identity.userId);
    final blur = await BackgroundStore.loadBlur(identity.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _myAvatarPath = myAvatar;
      _agentAvatarPath = agentAvatar;
      _backgroundPath = background;
      _backgroundDim = dim;
      _backgroundBlur = blur;
    });
  }

  String _headerStatusText() {
    if (!_online) {
      return '离线';
    }
    if (_backendStatus.state == BackendConnectionState.checking) {
      return '连接中...';
    }
    if (_backendStatus.state == BackendConnectionState.disconnected) {
      return '后端未连接';
    }
    const quiet = {'', '准备好了', '回复完成', '临时聊天'};
    return quiet.contains(_statusText) ? '在线' : _statusText;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsActivation) {
      return ActivationPage(
        onActivated: _handleActivated,
        errorText: _statusText == '需要激活' ? '' : _statusText,
      );
    }
    if (_identity == null) {
      if (_authUiEnabled) {
        return AuthPage(onLogin: _login, onRegister: _register);
      }
      return ActivationPage(onActivated: _handleActivated);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ChatBackground(
            imagePath: _backgroundPath,
            dim: _backgroundDim,
            blur: _backgroundBlur,
          ),
          SafeArea(
            child: Column(
              children: [
                _ChatHeader(
                  title: 'AIAgent',
                  agentAvatarPath: _agentAvatarPath,
                  onAvatarTap: _openSettingsPage,
                  statusText: _headerStatusText(),
                  online: _online,
                  speaking: _speaking,
                  onOpenVoiceCall: _openVoiceCallPage,
                  onOpenSettings: _openSettingsPage,
                  onSearch: _openChatSearch,
                  onCheckHealth: () => _checkHealth(),
                  onStopAudio: _audioPlaybackService.stop,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      _MessageList(
                        messages: _messages,
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        highlightedMessageKey: _highlightedMessageKey,
                        feedback: _feedback,
                        fontSize: _chatFontSize,
                        myAvatarPath: _myAvatarPath,
                        agentAvatarPath: _agentAvatarPath,
                        typing:
                            _sending &&
                            !_recording &&
                            _messages.isNotEmpty &&
                            _messages.last.role == ChatRole.user,
                        playingAudioKey: _playingAudioKey,
                        onOpenImage: _openImageViewer,
                        onPlayAudio: _playMessageAudio,
                        onDelete: _deleteMessage,
                        onQuote: _quoteMessage,
                        onRetry: _retryMessage,
                        onFeedback: _sendFeedback,
                      ),
                      if (_showJumpToBottom)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            heroTag: null,
                            tooltip: '回到底部',
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF666666),
                            elevation: 2,
                            onPressed: _jumpToBottom,
                            child: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                    ],
                  ),
                ),
                _InputBar(
                  controller: _textController,
                  focusNode: _composerFocus,
                  quotedText: _quotedMessage?.text ?? '',
                  quotedSender: _quotedMessage == null
                      ? ''
                      : (_quotedMessage!.role == ChatRole.user
                            ? '我'
                            : 'AIAgent'),
                  onCancelQuote: () {
                    setState(() {
                      _quotedMessage = null;
                    });
                  },
                  sending: _sending,
                  recording: _recording,
                  recordingSeconds: _recordingSeconds,
                  onCancelRecording: _cancelRecording,
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

class _ImagePager extends StatefulWidget {
  const _ImagePager({required this.imagePaths, required this.initialIndex});

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_ImagePager> createState() => _ImagePagerState();
}

class _ImagePagerState extends State<_ImagePager> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imagePaths.length,
              onPageChanged: (value) {
                setState(() {
                  _index = value;
                });
              },
              itemBuilder: (context, index) {
                final path = widget.imagePaths[index];
                return InteractiveViewer(
                  panEnabled: false,
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          '图片无法显示',
                          style: TextStyle(color: Colors.white70),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 16,
              child: Text(
                '${_index + 1}/${widget.imagePaths.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Positioned(
              top: 0,
              right: 4,
              child: IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground({
    required this.imagePath,
    required this.dim,
    required this.blur,
  });

  final String imagePath;
  final double dim;
  final double blur;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(color: Color(0xFFF2F3F5));
    final path = imagePath.trim();
    if (path.isEmpty || !File(path).existsSync()) {
      return fallback;
    }
    Widget image = Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
    if (blur > 0.1) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: image,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        ColoredBox(color: Colors.white.withValues(alpha: dim.clamp(0.2, 0.9))),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.agentAvatarPath,
    required this.onAvatarTap,
    required this.statusText,
    required this.online,
    required this.speaking,
    required this.onOpenVoiceCall,
    required this.onOpenSettings,
    required this.onSearch,
    required this.onCheckHealth,
    required this.onStopAudio,
  });

  final String title;
  final String agentAvatarPath;
  final VoidCallback onAvatarTap;
  final String statusText;
  final bool online;
  final bool speaking;
  final VoidCallback onOpenVoiceCall;
  final VoidCallback onOpenSettings;
  final VoidCallback onSearch;
  final VoidCallback onCheckHealth;
  final VoidCallback onStopAudio;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6))),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '打开设置',
            child: GestureDetector(
              onTap: onAvatarTap,
              child: _ChatAvatar(
                label: '绫',
                isUser: false,
                size: 36,
                imagePath: agentAvatarPath,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF23A26D)
                            : const Color(0xFFAAAAAA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '搜索聊天',
            onPressed: onSearch,
            icon: const Icon(Icons.search, color: Color(0xFF444444)),
          ),
          IconButton(
            tooltip: '语音通话',
            onPressed: onOpenVoiceCall,
            icon: const Icon(Icons.call_outlined, color: Color(0xFF444444)),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_horiz, color: Color(0xFF444444)),
            onSelected: (value) {
              if (value == 'health') {
                onCheckHealth();
              } else if (value == 'stop') {
                onStopAudio();
              } else if (value == 'settings') {
                onOpenSettings();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'health', child: Text('检查连接')),
              if (speaking)
                const PopupMenuItem<String>(value: 'stop', child: Text('停止语音')),
              const PopupMenuItem<String>(value: 'settings', child: Text('设置')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.label,
    required this.isUser,
    this.size = 36,
    this.imagePath = '',
  });

  final String label;
  final bool isUser;
  final double size;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = isUser ? '我的头像' : 'AIAgent 头像';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? const Color(0xFF5B8CFF) : null,
        gradient: isUser
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF9A8F), Color(0xFFC74444)],
              ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final path = imagePath.trim();
    final Widget avatar = path.isEmpty
        ? fallback
        : SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
          );
    return Semantics(image: true, label: semanticLabel, child: avatar);
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.highlightedMessageKey,
    required this.feedback,
    required this.fontSize,
    required this.myAvatarPath,
    required this.agentAvatarPath,
    required this.typing,
    required this.playingAudioKey,
    required this.onOpenImage,
    required this.onPlayAudio,
    required this.onRetry,
    required this.onFeedback,
    required this.onDelete,
    required this.onQuote,
  });

  final List<ChatMessage> messages;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final String highlightedMessageKey;
  final Map<String, Map<String, dynamic>> feedback;
  final double fontSize;
  final String myAvatarPath;
  final String agentAvatarPath;
  final bool typing;
  final String playingAudioKey;
  final ValueChanged<String> onOpenImage;
  final ValueChanged<ChatMessage> onPlayAudio;
  final ValueChanged<ChatMessage> onRetry;
  final Future<void> Function(ChatMessage, int, List<String>) onFeedback;
  final ValueChanged<ChatMessage> onDelete;
  final ValueChanged<ChatMessage> onQuote;

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _EmptyChatView(agentAvatarPath: agentAvatarPath);
    }
    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: messages.length + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _TypingIndicator(agentAvatarPath: agentAvatarPath);
        }
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final showTime =
            previous == null ||
            message.createdAt.difference(previous.createdAt).inMinutes.abs() >=
                5 ||
            !_sameDay(previous.createdAt, message.createdAt);
        final compact =
            !showTime &&
            previous.role == message.role &&
            message.createdAt.difference(previous.createdAt).inMinutes.abs() <
                3;
        final messageKey = message.requestId.isNotEmpty
            ? message.requestId
            : message.clientMessageId;
        return _MessageBubble(
          message: message,
          showTime: showTime,
          compact: compact,
          highlighted:
              highlightedMessageKey.isNotEmpty &&
              highlightedMessageKey == messageKey,
          feedback: feedback,
          fontSize: fontSize,
          myAvatarPath: myAvatarPath,
          agentAvatarPath: agentAvatarPath,
          playingAudioKey: playingAudioKey,
          onOpenImage: onOpenImage,
          onPlayAudio: onPlayAudio,
          onRetry: onRetry,
          onFeedback: onFeedback,
          onDelete: onDelete,
          onQuote: onQuote,
        );
      },
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({required this.agentAvatarPath});

  final String agentAvatarPath;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatAvatar(
            label: '绫',
            isUser: false,
            size: 64,
            imagePath: agentAvatarPath,
          ),
          const SizedBox(height: 16),
          const Text(
            '开始和 AIAgent 聊天吧',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '发送消息、图片或语音，阿绫会在这里回复你',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.agentAvatarPath});

  final String agentAvatarPath;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'AIAgent 正在输入',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChatAvatar(
                label: '绫',
                isUser: false,
                size: 36,
                imagePath: widget.agentAvatarPath,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          if (index > 0) const SizedBox(width: 5),
                          Opacity(
                            opacity: _dotOpacity(index),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF999999),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        const Text(
                          '正在输入',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value + index * 0.18) % 1.0;
    return 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showTime,
    required this.compact,
    required this.highlighted,
    required this.feedback,
    required this.fontSize,
    required this.myAvatarPath,
    required this.agentAvatarPath,
    required this.playingAudioKey,
    required this.onOpenImage,
    required this.onPlayAudio,
    required this.onRetry,
    required this.onFeedback,
    required this.onDelete,
    required this.onQuote,
  });

  final ChatMessage message;
  final bool showTime;
  final bool compact;
  final bool highlighted;
  final Map<String, Map<String, dynamic>> feedback;
  final double fontSize;
  final String myAvatarPath;
  final String agentAvatarPath;
  final String playingAudioKey;
  final ValueChanged<String> onOpenImage;
  final ValueChanged<ChatMessage> onPlayAudio;
  final ValueChanged<ChatMessage> onRetry;
  final Future<void> Function(ChatMessage, int, List<String>) onFeedback;
  final ValueChanged<ChatMessage> onDelete;
  final ValueChanged<ChatMessage> onQuote;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final isSystem = message.role == ChatRole.system;
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message.text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
            ),
          ),
        ),
      );
    }

    final hasAudio = message.audioUrl.isNotEmpty;
    final needsRetry =
        message.role == ChatRole.user &&
        (message.status == ChatMessageStatus.queued ||
            message.status == ChatMessageStatus.failed);
    final imagePath = message.imagePath;
    final quoted = _splitQuote(message.text);
    final bodyText = quoted?.body ?? message.text;
    final feedbackKey = message.requestId.isNotEmpty
        ? message.requestId
        : message.clientMessageId;
    final feedbackEntry =
        message.role == ChatRole.assistant && feedbackKey.isNotEmpty
        ? feedback[feedbackKey]
        : null;
    final currentRating = feedbackEntry?['rating'];

    final bubble = GestureDetector(
      onTap: needsRetry ? () => onRetry(message) : null,
      onLongPress: () {
        MessageActions.show(
          context: context,
          message: message,
          playing: playingAudioKey == feedbackKey,
          onPlayAudio: onPlayAudio,
          onRetry: onRetry,
          onDelete: onDelete,
          onQuote: onQuote,
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.68,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFC74444) : Colors.white,
          border: highlighted
              ? Border.all(color: const Color(0xFFFFB300), width: 1.5)
              : null,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 14 : 4),
            topRight: Radius.circular(isUser ? 4 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quoted != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: BorderSide(
                      color: isUser ? Colors.white70 : const Color(0xFFC74444),
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  quoted.quote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (fontSize - 3).clamp(11, 17).toDouble(),
                    height: 1.35,
                    color: isUser
                        ? Colors.white.withValues(alpha: 0.82)
                        : Colors.black54,
                  ),
                ),
              ),
              if (imagePath.isNotEmpty || bodyText.trim().isNotEmpty)
                const SizedBox(height: 6),
            ],
            if (imagePath.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => onOpenImage(imagePath),
                  child: Image.file(
                    File(imagePath),
                    width: 220,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 220,
                        height: 80,
                        alignment: Alignment.center,
                        color: const Color(0xFFF2F2F2),
                        child: const Text('图片无法显示'),
                      );
                    },
                  ),
                ),
              ),
              if (bodyText.trim().isNotEmpty) const SizedBox(height: 6),
            ],
            if (bodyText.trim().isNotEmpty)
              Text(
                bodyText,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.42,
                  color: isUser ? Colors.white : const Color(0xFF222222),
                ),
              ),
          ],
        ),
      ),
    );

    final semanticParts = <String>[
      isUser ? '我说：' : 'AIAgent 说：',
      bodyText.trim().isEmpty ? '图片' : bodyText.trim(),
    ];
    if (quoted != null) {
      semanticParts.add('引用：${quoted.quote}');
    }
    if (imagePath.isNotEmpty) {
      semanticParts.add('包含图片');
    }
    if (message.status == ChatMessageStatus.failed) {
      semanticParts.add('发送失败');
    } else if (message.status == ChatMessageStatus.queued) {
      semanticParts.add('待发送');
    }
    if (message.isDegraded) {
      semanticParts.add('降级回复');
    }
    final accessibleBubble = Semantics(
      container: true,
      button: needsRetry,
      label: semanticParts.join('。'),
      onTap: needsRetry ? () => onRetry(message) : null,
      child: ExcludeSemantics(child: bubble),
    );

    final extras = <Widget>[
      if (needsRetry) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              message.status == ChatMessageStatus.failed
                  ? Icons.error_outline
                  : Icons.schedule,
              size: 13,
              color: const Color(0xFF8A6D3B),
            ),
            const SizedBox(width: 4),
            Text(
              message.status == ChatMessageStatus.failed
                  ? '发送失败，点击重试'
                  : '待发送，点击重试',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A6D3B)),
            ),
          ],
        ),
      ],
      if (message.role == ChatRole.assistant && message.isDegraded) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '服务繁忙 · 降级回复',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      if (message.role == ChatRole.assistant &&
          message.memoryStatus.visible) ...[
        const SizedBox(height: 4),
        MemoryStatusChip(status: message.memoryStatus),
      ],
      if (hasAudio) ...[
        const SizedBox(height: 2),
        TextButton.icon(
          onPressed: () => onPlayAudio(message),
          style: TextButton.styleFrom(
            foregroundColor: playingAudioKey == feedbackKey
                ? const Color(0xFFC74444)
                : const Color(0xFF666666),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(
            playingAudioKey == feedbackKey
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined,
            size: 16,
          ),
          label: Text(
            playingAudioKey == feedbackKey ? '停止播放' : '播放语音',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
      if (message.role == ChatRole.assistant && feedbackKey.isNotEmpty) ...[
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '有帮助',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              iconSize: 16,
              color: currentRating == 1
                  ? const Color(0xFF23A26D)
                  : Colors.black38,
              icon: Icon(
                currentRating == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
              ),
              onPressed: () => onFeedback(message, 1, const []),
            ),
            IconButton(
              tooltip: '没有帮助',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              iconSize: 16,
              color: currentRating == -1
                  ? const Color(0xFFB3261E)
                  : Colors.black38,
              icon: Icon(
                currentRating == -1
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
              ),
              onPressed: () => _showFeedbackTags(context),
            ),
            if (currentRating == -1 && feedbackEntry?['tags'] is List)
              Text(
                (feedbackEntry!['tags'] as List).join(' / '),
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
          ],
        ),
      ],
    ];

    return Padding(
      padding: EdgeInsets.only(
        top: showTime ? 10 : (compact ? 2 : 4),
        bottom: compact ? 2 : 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTime) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _ChatAvatar(
                  label: '绫',
                  isUser: false,
                  size: 36,
                  imagePath: agentAvatarPath,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [accessibleBubble, ...extras],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                _ChatAvatar(
                  label: '我',
                  isUser: true,
                  size: 36,
                  imagePath: myAvatarPath,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  ({String quote, String body})? _splitQuote(String text) {
    final lines = text.split('\n');
    if (lines.isEmpty || !lines.first.startsWith('> ')) {
      return null;
    }
    final quoteLines = <String>[];
    var index = 0;
    while (index < lines.length && lines[index].startsWith('> ')) {
      quoteLines.add(lines[index].substring(2));
      index += 1;
    }
    while (index < lines.length && lines[index].trim().isEmpty) {
      index += 1;
    }
    return (quote: quoteLines.join('\n'), body: lines.skip(index).join('\n'));
  }

  String _formatTime(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final hm =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '今天 $hm';
    }
    if (diff == 1) {
      return '昨天 $hm';
    }
    if (value.year == now.year) {
      return '${value.month}月${value.day}日 $hm';
    }
    return '${value.year}年${value.month}月${value.day}日 $hm';
  }

  Future<void> _showFeedbackTags(BuildContext context) async {
    const tags = ['答非所问', '太慢', '太短', '语气不对', '其他'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '哪里不满意？',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final tag in tags)
                ListTile(
                  title: Text(tag),
                  onTap: () => Navigator.of(sheetContext).pop(tag),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await onFeedback(message, -1, [selected]);
    }
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.quotedText,
    required this.quotedSender,
    required this.onCancelQuote,
    required this.sending,
    required this.recording,
    required this.recordingSeconds,
    required this.onCancelRecording,
    required this.selectedImagePath,
    required this.onSend,
    required this.onRecord,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onClearImage,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String quotedText;
  final String quotedSender;
  final VoidCallback onCancelQuote;
  final bool sending;
  final bool recording;
  final int recordingSeconds;
  final VoidCallback onCancelRecording;
  final String selectedImagePath;
  final VoidCallback onSend;
  final VoidCallback onRecord;
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quotedText.isNotEmpty) ...[
                _QuotedPreview(
                  sender: quotedSender,
                  text: quotedText,
                  onCancel: onCancelQuote,
                ),
                const SizedBox(height: 8),
              ],
              if (recording) ...[
                _RecordingBanner(
                  seconds: recordingSeconds,
                  onCancel: onCancelRecording,
                  onSend: onRecord,
                ),
                const SizedBox(height: 8),
              ],
              if (!recording && selectedImagePath.isNotEmpty) ...[
                _SelectedImagePreview(
                  imagePath: selectedImagePath,
                  onClear: onClearImage,
                ),
                const SizedBox(height: 8),
              ],
              if (!recording)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: '发送图片',
                      enabled: !sending && !recording,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF666666),
                      ),
                      onSelected: (value) {
                        if (value == 'gallery') {
                          onPickImage();
                        } else if (value == 'camera') {
                          onTakePhoto();
                        }
                      },
                      itemBuilder: (context) => const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'gallery',
                          child: Text('从相册选择'),
                        ),
                        PopupMenuItem<String>(
                          value: 'camera',
                          child: Text('拍照'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !recording,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: recording ? '正在录音...' : '输入消息...',
                          filled: true,
                          fillColor: const Color(0xFFF2F3F5),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: sending && !recording ? null : onRecord,
                      icon: Icon(
                        recording ? Icons.stop_circle : Icons.mic_none,
                      ),
                      color: recording
                          ? const Color(0xFFC74444)
                          : const Color(0xFF666666),
                      tooltip: recording ? '停止录音' : '语音输入',
                    ),
                    const SizedBox(width: 2),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, child) {
                        final hasContent =
                            value.text.trim().isNotEmpty ||
                            selectedImagePath.isNotEmpty;
                        final canSend = hasContent && !sending && !recording;
                        return SizedBox(
                          width: 40,
                          height: 40,
                          child: Tooltip(
                            message: '发送',
                            child: FilledButton(
                              onPressed: canSend ? onSend : null,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                                backgroundColor: const Color(0xFFC74444),
                                disabledBackgroundColor: const Color(
                                  0xFFE0E0E0,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF9E9E9E,
                                ),
                              ),
                              child: sending && !recording
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 20),
                            ),
                          ),
                        );
                      },
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

class _RecordingBanner extends StatefulWidget {
  const _RecordingBanner({
    required this.seconds,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  State<_RecordingBanner> createState() => _RecordingBannerState();
}

class _RecordingBannerState extends State<_RecordingBanner> {
  double _dragDy = 0;
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final label = _armed ? '松手取消' : '正在录音  ${_formatDuration(widget.seconds)}';
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragDy = (_dragDy + details.delta.dy).clamp(-80.0, 0.0).toDouble();
          _armed = _dragDy < -50;
        });
      },
      onVerticalDragEnd: (_) {
        final shouldCancel = _armed;
        setState(() {
          _dragDy = 0;
          _armed = false;
        });
        if (shouldCancel) {
          widget.onCancel();
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragDy),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: _armed ? '松手取消录音' : '正在录音',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _armed ? const Color(0xFFFFE0DD) : const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _armed
                    ? const Color(0xFFC74444)
                    : const Color(0xFFF3C8C2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC74444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A2E2A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _armed ? '松开手指取消' : '上滑取消',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB07A75),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: widget.onCancel, child: const Text('取消')),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: widget.onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC74444),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('发送'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int value) {
    final minutes = (value ~/ 60).toString().padLeft(2, '0');
    final seconds = (value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({
    required this.sender,
    required this.text,
    required this.onCancel,
  });

  final String sender;
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final singleLine = text.replaceAll('\n', ' ').trim();
    return Container(
      padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6, right: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(left: BorderSide(color: Color(0xFFC74444), width: 3)),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC74444),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  singleLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '取消引用',
            onPressed: onCancel,
            iconSize: 18,
            icon: const Icon(Icons.close),
          ),
        ],
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
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(imagePath),
              width: 52,
              height: 52,
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
