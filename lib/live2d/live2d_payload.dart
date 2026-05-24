class Live2DPayload {
  const Live2DPayload({required this.character, required this.scene});

  final Live2DCharacterPayload character;
  final Live2DScenePayload scene;

  factory Live2DPayload.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
    final characterRaw = json['character'];
    final sceneRaw = json['scene'];

    return Live2DPayload(
      character: characterRaw is Map
          ? Live2DCharacterPayload.fromJson(
              characterRaw.map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
              apiBaseUrl: apiBaseUrl,
            )
          : Live2DCharacterPayload.empty(),
      scene: sceneRaw is Map
          ? Live2DScenePayload.fromJson(
              sceneRaw.map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : Live2DScenePayload.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'character': character.toJson(), 'scene': scene.toJson()};
  }
}

class Live2DCharacterPayload {
  const Live2DCharacterPayload({
    required this.characterId,
    required this.modelId,
    required this.emotion,
    required this.expression,
    required this.motion,
    required this.motionPriority,
    required this.mouth,
    required this.eye,
  });

  final String characterId;
  final String modelId;
  final String emotion;
  final String expression;
  final String motion;
  final int motionPriority;
  final Live2DMouthPayload mouth;
  final Live2DEyePayload eye;

  factory Live2DCharacterPayload.empty() {
    return Live2DCharacterPayload(
      characterId: '',
      modelId: '',
      emotion: '',
      expression: '',
      motion: '',
      motionPriority: 0,
      mouth: Live2DMouthPayload.empty(),
      eye: Live2DEyePayload.empty(),
    );
  }

  factory Live2DCharacterPayload.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
    final mouthRaw = json['mouth'];
    final eyeRaw = json['eye'];

    return Live2DCharacterPayload(
      characterId: json['character_id']?.toString() ?? '',
      modelId: json['model_id']?.toString() ?? '',
      emotion: json['emotion']?.toString() ?? '',
      expression: json['expression']?.toString() ?? '',
      motion: json['motion']?.toString() ?? '',
      motionPriority: _intValue(json['motion_priority']),
      mouth: mouthRaw is Map
          ? Live2DMouthPayload.fromJson(
              mouthRaw.map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
              apiBaseUrl: apiBaseUrl,
            )
          : Live2DMouthPayload.empty(),
      eye: eyeRaw is Map
          ? Live2DEyePayload.fromJson(
              eyeRaw.map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : Live2DEyePayload.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character_id': characterId,
      'model_id': modelId,
      'emotion': emotion,
      'expression': expression,
      'motion': motion,
      'motion_priority': motionPriority,
      'mouth': mouth.toJson(),
      'eye': eye.toJson(),
    };
  }
}

class Live2DMouthPayload {
  const Live2DMouthPayload({required this.mode, required this.audioUrl});

  final String mode;
  final String audioUrl;

  factory Live2DMouthPayload.empty() {
    return const Live2DMouthPayload(mode: '', audioUrl: '');
  }

  factory Live2DMouthPayload.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
    return Live2DMouthPayload(
      mode: json['mode']?.toString() ?? '',
      audioUrl: _resolveUrl(json['audio_url']?.toString() ?? '', apiBaseUrl),
    );
  }

  Map<String, dynamic> toJson() {
    return {'mode': mode, 'audio_url': audioUrl};
  }
}

class Live2DEyePayload {
  const Live2DEyePayload({required this.blink, required this.lookAt});

  final bool blink;
  final String lookAt;

  factory Live2DEyePayload.empty() {
    return const Live2DEyePayload(blink: true, lookAt: 'user');
  }

  factory Live2DEyePayload.fromJson(Map<String, dynamic> json) {
    return Live2DEyePayload(
      blink: json['blink'] != false,
      lookAt: json['look_at']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {'blink': blink, 'look_at': lookAt};
  }
}

class Live2DScenePayload {
  const Live2DScenePayload({
    required this.backgroundId,
    required this.lighting,
    required this.effect,
  });

  final String backgroundId;
  final String lighting;
  final String effect;

  factory Live2DScenePayload.empty() {
    return const Live2DScenePayload(
      backgroundId: 'room_default',
      lighting: 'normal',
      effect: 'none',
    );
  }

  factory Live2DScenePayload.fromJson(Map<String, dynamic> json) {
    return Live2DScenePayload(
      backgroundId: json['background_id']?.toString() ?? 'room_default',
      lighting: json['lighting']?.toString() ?? 'normal',
      effect: json['effect']?.toString() ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'background_id': backgroundId,
      'lighting': lighting,
      'effect': effect,
    };
  }
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _resolveUrl(String value, String apiBaseUrl) {
  if (value.isEmpty) {
    return '';
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  if (apiBaseUrl.isEmpty) {
    return value;
  }

  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;

  final path = value.startsWith('/') ? value : '/$value';
  return '$base$path';
}
