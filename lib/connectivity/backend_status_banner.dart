import 'package:flutter/material.dart';

import 'backend_status.dart';

class BackendStatusBanner extends StatelessWidget {
  const BackendStatusBanner({
    super.key,
    required this.status,
    required this.onRetry,
  });

  final BackendStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!status.visible) {
      return const SizedBox.shrink();
    }

    final checking = status.state == BackendConnectionState.checking;
    final color = checking ? const Color(0xFFFFF7E6) : const Color(0xFFFFECE8);
    final borderColor = checking
        ? const Color(0xFFE4B85A)
        : const Color(0xFFD97A6C);
    final icon = checking ? Icons.sync : Icons.cloud_off_outlined;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: checking ? null : onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
