import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player_state_provider.dart';
import 'smtc_service_win.dart';

class SMTCService {
  final Ref ref;
  late final SMTCServiceWin _serviceWin;

  SMTCService(this.ref) {
    _serviceWin = SMTCServiceWin(ref);
  }

  void onStateChanged(PlayerState state) {
    _serviceWin.onStateChanged(state);
  }

  void dispose() {
    _serviceWin.dispose();
  }
}

final smtcServiceProvider = Provider<SMTCService>((ref) {
  final service = SMTCService(ref);

  ref.onDispose(() {
    service.dispose();
  });

  // Listen for changes to title, thumbnail, or playlist index
  ref.listen<PlayerState>(playerStateProvider, (previous, next) {
    if (previous?.currentTitle != next.currentTitle ||
        previous?.currentThumbnailUrl != next.currentThumbnailUrl ||
        previous?.currentPlaylistIndex != next.currentPlaylistIndex) {
      service.onStateChanged(next);
    }
  });

  // Don't push initial state — SMTC activates only when playback starts

  return service;
});
