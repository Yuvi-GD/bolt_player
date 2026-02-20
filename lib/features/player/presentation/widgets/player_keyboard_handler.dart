import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_state_provider.dart';
import '../../providers/notification_provider.dart';

class PlayerKeyboardHandler extends ConsumerStatefulWidget {
  final Widget child;
  const PlayerKeyboardHandler({super.key, required this.child});

  @override
  ConsumerState<PlayerKeyboardHandler> createState() =>
      _PlayerKeyboardHandlerState();
}

class _PlayerKeyboardHandlerState extends ConsumerState<PlayerKeyboardHandler> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'PlayerKeyboardHandler');
  bool _isSpeedUp = false;
  Timer? _speedUpTimer;

  @override
  void initState() {
    super.initState();
    _requestDelayedFocus();
  }

  void _requestDelayedFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _speedUpTimer?.cancel();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      return _onKeyDown(event);
    } else if (event is KeyUpEvent) {
      return _onKeyUp(event);
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onKeyDown(KeyDownEvent event) {
    final player = ref.read(playerProvider);
    final appState = ref.read(playerStateProvider);
    final isPlayerView = appState.currentView == PlayerView.player;

    // --- UNIVERSAL SHORTCUTS (Work Everywhere) ---

    // 1. Fullscreen (F or F11)
    if (event.logicalKey == LogicalKeyboardKey.keyF ||
        event.logicalKey == LogicalKeyboardKey.f11) {
      ref.read(playerStateProvider.notifier).toggleFullScreen();
      return KeyEventResult.handled;
    }

    // 2. Mute (M)
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      final notifier = ref.read(playerStateProvider.notifier);
      notifier.toggleMute();
      player.setVolume(ref.read(playerStateProvider).volume.clamp(0.0, 100.0));
      return KeyEventResult.handled;
    }

    // 3. Always On Top (T)
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      ref.read(playerStateProvider.notifier).toggleAlwaysOnTop();
      return KeyEventResult.handled;
    }

    // 4. Lock / Unlock (L)
    if (event.logicalKey == LogicalKeyboardKey.keyL) {
      ref.read(playerStateProvider.notifier).toggleLock();
      return KeyEventResult.handled;
    }

    // 5. Escape to go back/close menu
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else if (appState.currentView != PlayerView.home) {
        ref.read(playerStateProvider.notifier).back();
      }
      return KeyEventResult.handled;
    }

    // --- PLAYER-SPECIFIC SHORTCUTS (Only in PlayerView) ---
    if (!isPlayerView) return KeyEventResult.ignored;

    // 4. Modifier-based Shortcuts (Ctrl)
    final isControl = HardwareKeyboard.instance.isControlPressed;
    if (isControl) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        player.next();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        player.previous();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (!_isSpeedUp && _speedUpTimer == null) {
        _speedUpTimer = Timer(const Duration(milliseconds: 250), () async {
          _isSpeedUp = true;
          await player.setRate(2.0);
          ref
              .read(notificationProvider.notifier)
              .show(
                message: '2x Speed',
                icon: Icons.fast_forward_rounded,
                isCenter: false,
              );
        });
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _adjustVolume(5);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _adjustVolume(-5);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      player.seek(player.state.position + const Duration(seconds: 10));
      _showSeekFeedback('+10s', true);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      player.seek(player.state.position - const Duration(seconds: 10));
      _showSeekFeedback('-10s', false);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      _toggleSubtitles();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _adjustVolume(double delta) {
    final player = ref.read(playerProvider);
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final notifier = ref.read(playerStateProvider.notifier);
    if (isControl) {
      final currentBri = ref.read(playerStateProvider).brightness;
      notifier.setBrightness(currentBri + (delta > 0 ? 0.05 : -0.05));
    } else {
      final vol = ref.read(playerStateProvider).volume;
      final newVol = (vol + delta).clamp(0.0, 200.0);
      notifier.setVolume(newVol);
      player.setVolume(newVol.clamp(0.0, 100.0));
      if (newVol > 100) {
        try {
          (player.platform as dynamic).setProperty('volume', newVol.toString());
        } catch (_) {}
      }
    }
  }

  void _toggleSubtitles() {
    final player = ref.read(playerProvider);
    final subtitles = player.state.tracks.subtitle;
    if (subtitles.isNotEmpty) {
      final currentSub = player.state.track.subtitle;
      final currentIndex = subtitles.indexOf(currentSub);
      player.setSubtitleTrack(subtitles[(currentIndex + 1) % subtitles.length]);
    }
  }

  KeyEventResult _onKeyUp(KeyUpEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      final player = ref.read(playerProvider);
      if (_speedUpTimer != null && _speedUpTimer!.isActive) {
        _speedUpTimer?.cancel();
        _speedUpTimer = null;
        player.playOrPause();
      } else if (_isSpeedUp) {
        player.setRate(1.0);
        _isSpeedUp = false;
        _speedUpTimer = null;
        ref
            .read(notificationProvider.notifier)
            .show(
              message: '1x Speed',
              icon: Icons.play_arrow_rounded,
              isCenter: false,
            );
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showSeekFeedback(String message, bool isForward) {
    ref
        .read(notificationProvider.notifier)
        .show(
          message: message,
          icon: isForward
              ? Icons.fast_forward_rounded
              : Icons.fast_rewind_rounded,
          isCenter: true,
          duration: const Duration(milliseconds: 500),
        );
  }

  @override
  Widget build(BuildContext context) {
    // Reclaim focus when entering player
    ref.listen(playerStateProvider.select((s) => s.currentView), (prev, next) {
      if (next == PlayerView.player && mounted) {
        _requestDelayedFocus();
        // Fallback scope request
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) FocusScope.of(context).requestFocus(_focusNode);
        });
      }
    });

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
