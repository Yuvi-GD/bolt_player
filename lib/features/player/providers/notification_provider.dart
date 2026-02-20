import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Notification Model
class PlayerNotification {
  final String message;
  final IconData? icon;
  final bool isCenter; // True for Center Play/Pause, False for Top-Center
  final Duration duration;

  PlayerNotification({
    required this.message,
    this.icon,
    this.isCenter = false,
    this.duration = const Duration(milliseconds: 1500),
  });
}

// Notifier
class NotificationNotifier extends Notifier<PlayerNotification?> {
  Timer? _timer;

  @override
  PlayerNotification? build() {
    return null;
  }

  void show({
    required String message,
    IconData? icon,
    bool isCenter = false,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    state = PlayerNotification(
      message: message,
      icon: icon,
      isCenter: isCenter,
      duration: duration,
    );

    _timer?.cancel();
    _timer = Timer(duration, () {
      state = null;
    });
  }

  void clear() {
    _timer?.cancel();
    state = null;
  }
}

// Provider
final notificationProvider =
    NotifierProvider<NotificationNotifier, PlayerNotification?>(() {
      return NotificationNotifier();
    });

// --- UI Components ---

class TopNotificationPill extends StatelessWidget {
  final String message;
  final IconData? icon;

  const TopNotificationPill({required this.message, this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: const Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CenterIconFeedback extends StatelessWidget {
  final IconData icon;
  final String? message;

  const CenterIconFeedback({required this.icon, this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(icon.codePoint + (message?.length ?? 0)),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + (value * 0.2),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 60, color: const Color(0xFF00E5FF)),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GlobalNotificationOverlay extends ConsumerWidget {
  const GlobalNotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = ref.watch(notificationProvider);
    if (notification == null) return const SizedBox.shrink();

    return Stack(
      children: [
        if (!notification.isCenter)
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: TopNotificationPill(
                message: notification.message,
                icon: notification.icon,
              ),
            ),
          ),
        if (notification.isCenter)
          Center(
            child: CenterIconFeedback(
              icon: notification.icon ?? Icons.circle,
              message: notification.message.isNotEmpty
                  ? notification.message
                  : null,
            ),
          ),
      ],
    );
  }
}
