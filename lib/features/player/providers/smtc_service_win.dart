import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player_state_provider.dart';

/// Dart bridge to the native C++ SMTC handler via Method Channel.
/// This communicates with `smtc_handler.cpp` in the Windows runner.
class SMTCServiceWin {
  static const _channel = MethodChannel('bolt_player/smtc');
  final Ref ref;
  bool _hasActivated = false;

  SMTCServiceWin(this.ref) {
    _initialize();
  }

  void _initialize() {
    // Listen for button presses from the native SMTC handler
    _channel.setMethodCallHandler(_handleNativeCall);

    final player = ref.read(playerProvider);

    // Listen for playback state changes
    player.stream.playing.listen((playing) {
      if (playing && !_hasActivated) {
        // First time playing — activate SMTC
        _hasActivated = true;
        _channel.invokeMethod('setEnabled', true);
      }

      _updatePlaybackStatus(playing);

      // Re-push metadata when playback starts
      if (playing) {
        final currentState = ref.read(playerStateProvider);
        _updateMetadata(currentState);
      }
    });
  }

  /// Handle method calls coming FROM native C++ (button presses)
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'buttonPressed') {
      final button = call.arguments as String;
      final player = ref.read(playerProvider);
      final notifier = ref.read(playerStateProvider.notifier);

      switch (button) {
        case 'play':
          player.play();
          break;
        case 'pause':
          player.pause();
          break;
        case 'next':
          notifier.next();
          break;
        case 'previous':
          notifier.previous();
          break;
        case 'stop':
          // Full reset — clears everything and goes back to home
          notifier.resetPlayer();
          _updatePlaybackStatus(false);
          _channel.invokeMethod('setEnabled', false);
          _hasActivated = false;
          break;
      }
    }
  }

  /// Send metadata TO native C++ SMTC handler
  void onStateChanged(PlayerState state) {
    _updateMetadata(state);
  }

  void _updateMetadata(PlayerState state) {
    try {
      _channel.invokeMethod('updateMetadata', {
        'title': state.currentTitle ?? 'Bolt Player',
        'artist': state.isPlaylist
            ? 'Playlist (${state.currentPlaylistIndex + 1}/${state.playlistLength})'
            : 'Bolt Player',
        'album': '',
        'thumbnail': state.currentThumbnailUrl ?? '',
      });
    } catch (e) {
      // SMTC not available - silently ignore
    }
  }

  void _updatePlaybackStatus(bool isPlaying) {
    try {
      _channel.invokeMethod('updatePlaybackStatus', isPlaying);
    } catch (e) {
      // SMTC not available - silently ignore
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    try {
      _channel.invokeMethod('setEnabled', false);
    } catch (_) {}
  }
}
