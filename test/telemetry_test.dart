import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_client/core/telemetry.dart';

Future<void> _record(TelemetryService service) {
  return service.recordTurn(
    clientMessageId: 'm1',
    latencyMs: 10,
    status: 200,
    degraded: false,
    textLen: 5,
    hasImage: false,
    ttsPlayed: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('flushes buffered events and clears them on success', () async {
    final batches = <List<Map<String, dynamic>>>[];
    final service = TelemetryService(
      sender: (batchId, app, events) async {
        batches.add(events);
      },
      appVersion: 'test',
      platform: 'android',
    );

    await _record(service);
    await _record(service);
    await service.flush();

    expect(batches, hasLength(1));
    expect(batches.first, hasLength(2));
    expect(await TelemetryBuffer().load(), isEmpty);
  });

  test('keeps events when the sender fails', () async {
    final service = TelemetryService(
      sender: (batchId, app, events) async {
        throw Exception('offline');
      },
      appVersion: 'test',
      platform: 'android',
    );

    await _record(service);
    await service.flush();

    expect(await TelemetryBuffer().load(), hasLength(1));
  });

  test('buffer caps at maxEvents', () async {
    final buffer = TelemetryBuffer();
    for (var index = 0; index < TelemetryBuffer.maxEvents + 5; index += 1) {
      await buffer.add({'id': index});
    }
    final events = await buffer.load();
    expect(events, hasLength(TelemetryBuffer.maxEvents));
    expect(events.last['id'], TelemetryBuffer.maxEvents + 4);
  });
}
