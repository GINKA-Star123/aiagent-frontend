import 'package:flutter/material.dart';

class Live2DStageEmpty extends StatelessWidget {
  const Live2DStageEmpty({super.key, required this.statusText});

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF3EC), Color(0xFFFFDAD1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.view_in_ar_outlined,
                size: 44,
                color: Color(0xFF9A4C46),
              ),
              const SizedBox(height: 10),
              const Text(
                'Live2D 模型未载入',
                style: TextStyle(
                  color: Color(0xFF6D4642),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '请放入 Cubism Web SDK 与 model3.json 资源。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6D4642), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                statusText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF5A403C), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
