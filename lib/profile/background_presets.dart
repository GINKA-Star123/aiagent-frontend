import 'package:flutter/material.dart';

class BackgroundPreset {
  const BackgroundPreset({
    required this.id,
    required this.label,
    required this.colors,
  });

  final String id;
  final String label;
  final List<Color> colors;

  LinearGradient get gradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }
}

const List<BackgroundPreset> backgroundPresets = [
  BackgroundPreset(
    id: 'peach',
    label: '暖阳',
    colors: [Color(0xFFFFE3D6), Color(0xFFFFF6EC)],
  ),
  BackgroundPreset(
    id: 'mint',
    label: '薄荷',
    colors: [Color(0xFFDDF3E8), Color(0xFFF4FBF7)],
  ),
  BackgroundPreset(
    id: 'sky',
    label: '晴空',
    colors: [Color(0xFFDCEBFF), Color(0xFFF4F8FF)],
  ),
  BackgroundPreset(
    id: 'paper',
    label: '纸张',
    colors: [Color(0xFFF1ECE3), Color(0xFFFBF8F3)],
  ),
  BackgroundPreset(
    id: 'night',
    label: '夜色',
    colors: [Color(0xFF2E3A4E), Color(0xFF55617A)],
  ),
];

BackgroundPreset? backgroundPresetById(String id) {
  for (final preset in backgroundPresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return null;
}
