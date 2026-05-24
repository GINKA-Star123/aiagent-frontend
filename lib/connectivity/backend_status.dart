enum BackendConnectionState { unknown, checking, connected, disconnected }

class BackendStatus {
  const BackendStatus({required this.state, required this.message});

  final BackendConnectionState state;
  final String message;

  bool get visible => state != BackendConnectionState.connected;

  factory BackendStatus.unknown() {
    return const BackendStatus(
      state: BackendConnectionState.unknown,
      message: '尚未检查连接',
    );
  }

  factory BackendStatus.checking() {
    return const BackendStatus(
      state: BackendConnectionState.checking,
      message: '正在检查连接...',
    );
  }

  factory BackendStatus.connected() {
    return const BackendStatus(
      state: BackendConnectionState.connected,
      message: '已连接',
    );
  }

  factory BackendStatus.disconnected(String message) {
    return BackendStatus(
      state: BackendConnectionState.disconnected,
      message: message,
    );
  }
}
