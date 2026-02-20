import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

// 1. Native Engine Instances
// These remain as standalone providers for direct access to the native player/controller.
final playerProvider = Provider<Player>((ref) {
  final player = Player();
  ref.onDispose(() => player.dispose());
  return player;
});

// 2. Video Controller Notifier (Allows resetting the controller if it gets stuck)
class VideoControllerNotifier extends Notifier<VideoController> {
  @override
  VideoController build() {
    final player = ref.watch(playerProvider);
    return VideoController(player);
  }

  void reset() {
    final player = ref.read(playerProvider);
    state = VideoController(player);
  }
}

final videoControllerProvider =
    NotifierProvider<VideoControllerNotifier, VideoController>(
      VideoControllerNotifier.new,
    );

// 2. The Unified State Model
enum PlayerView { home, player, settings, shortcuts }

class PlayerState {
  // Navigation/View State
  final PlayerView currentView;
  final PlayerView
  baseView; // Stores the last base view (home or player) to return to from settings
  final String? currentFilePath;
  final String? currentTitle;
  final String? currentThumbnailUrl;
  final bool isFullScreen;
  final bool isMaximized;
  final bool isAlwaysOnTop;
  final bool isLocked;
  final bool isPlaylistVisible;
  final bool isBatchLoading; // To show loading spinner in sidebar

  // Video Adjustments
  final BoxFit videoFit;
  final int videoRotation; // 0, 1, 2, 3 (multiplied by 90 degrees)
  final double brightness; // 0.0 to 1.0 (software overlay)
  final double subtitleFontSize;

  // Audio State
  final double volume; // 0.0 to 200.0 (mpv allows software boosting)
  final double preMuteVolume;

  final bool isPlaylist;
  final int currentPlaylistIndex;
  final int playlistLength;
  final List<String> playlistNames; // Display names for the sidebar
  final List<String> playlistSources; // Categories (e.g. folder names)
  final List<String?> playlistThumbnails; // Thumbnail URLs
  final List<String?> playlistDurations; // Duration strings
  final PlaylistMode playlistMode;

  // Lazy Loading Info
  final String? youtubePlaylistId;
  final int fetchedPlaylistCount;

  PlayerState({
    this.currentView = PlayerView.home,
    this.baseView = PlayerView.home,
    this.currentFilePath,
    this.currentTitle,
    this.currentThumbnailUrl,
    this.isFullScreen = false,
    this.isMaximized = false,
    this.isAlwaysOnTop = false,
    this.isLocked = false,
    this.isPlaylistVisible = false,
    this.isBatchLoading = false,
    this.videoFit = BoxFit.contain,
    this.videoRotation = 0,
    this.brightness = 1.0,
    this.subtitleFontSize = 24.0,
    this.volume = 100.0,
    this.preMuteVolume = 100.0,
    this.isPlaylist = false,
    this.currentPlaylistIndex = 0,
    this.playlistLength = 0,
    this.playlistNames = const [],
    this.playlistSources = const [],
    this.playlistThumbnails = const [],
    this.playlistDurations = const [],
    this.playlistMode = PlaylistMode.none,
    this.youtubePlaylistId,
    this.fetchedPlaylistCount = 0,
  });

  PlayerState copyWith({
    PlayerView? currentView,
    PlayerView? baseView,
    Object? currentFilePath = _sentinel,
    Object? currentTitle = _sentinel,
    Object? currentThumbnailUrl = _sentinel,
    bool? isFullScreen,
    bool? isMaximized,
    bool? isAlwaysOnTop,
    bool? isLocked,
    bool? isPlaylistVisible,
    BoxFit? videoFit,
    int? videoRotation,
    double? brightness,
    double? subtitleFontSize,
    double? volume,
    double? preMuteVolume,
    bool? isPlaylist,
    int? currentPlaylistIndex,
    int? playlistLength,
    List<String>? playlistNames,
    List<String>? playlistSources,
    List<String?>? playlistThumbnails,
    List<String?>? playlistDurations,
    PlaylistMode? playlistMode,
    Object? youtubePlaylistId = _sentinel,
    int? fetchedPlaylistCount,
    bool? isBatchLoading,
  }) {
    return PlayerState(
      currentView: currentView ?? this.currentView,
      baseView: baseView ?? this.baseView,
      currentFilePath: identical(currentFilePath, _sentinel)
          ? this.currentFilePath
          : currentFilePath as String?,
      currentTitle: identical(currentTitle, _sentinel)
          ? this.currentTitle
          : currentTitle as String?,
      currentThumbnailUrl: identical(currentThumbnailUrl, _sentinel)
          ? this.currentThumbnailUrl
          : currentThumbnailUrl as String?,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      isMaximized: isMaximized ?? this.isMaximized,
      isAlwaysOnTop: isAlwaysOnTop ?? this.isAlwaysOnTop,
      isLocked: isLocked ?? this.isLocked,
      isPlaylistVisible: isPlaylistVisible ?? this.isPlaylistVisible,
      videoFit: videoFit ?? this.videoFit,
      videoRotation: videoRotation ?? this.videoRotation,
      brightness: brightness ?? this.brightness,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      volume: volume ?? this.volume,
      preMuteVolume: preMuteVolume ?? this.preMuteVolume,
      isPlaylist: isPlaylist ?? this.isPlaylist,
      currentPlaylistIndex: currentPlaylistIndex ?? this.currentPlaylistIndex,
      playlistLength: playlistLength ?? this.playlistLength,
      playlistNames: playlistNames ?? this.playlistNames,
      playlistSources: playlistSources ?? this.playlistSources,
      playlistThumbnails: playlistThumbnails ?? this.playlistThumbnails,
      playlistDurations: playlistDurations ?? this.playlistDurations,
      playlistMode: playlistMode ?? this.playlistMode,
      youtubePlaylistId: identical(youtubePlaylistId, _sentinel)
          ? this.youtubePlaylistId
          : youtubePlaylistId as String?,
      fetchedPlaylistCount: fetchedPlaylistCount ?? this.fetchedPlaylistCount,
      isBatchLoading: isBatchLoading ?? this.isBatchLoading,
    );
  }
}

const Object _sentinel = Object();

// 3. The Unified Logic Controller (The "Game Instance")
class PlayerStateNotifier extends Notifier<PlayerState> with WindowListener {
  @override
  PlayerState build() {
    windowManager.addListener(this);
    _checkInitialMaximized();

    final player = ref.watch(playerProvider);

    // Sync playlist state (index and item count)
    // This listener handles general playlist changes like length and initial setup.
    final playlistSub = player.stream.playlist.listen((playlist) {
      if (playlist.medias.length != state.playlistLength ||
          playlist.index != state.currentPlaylistIndex) {
        state = state.copyWith(
          isPlaylist: playlist.medias.length > 1,
          playlistLength: playlist.medias.length,
        );
      }
    });

    // Sync index changes specifically (for thumbnails/titles)
    // This listener ensures title/thumbnail updates immediately on index change.
    final indexSub = player.stream.playlist.listen((playlist) {
      final index = playlist.index;
      if (index >= 0 && index < state.playlistNames.length) {
        state = state.copyWith(
          currentPlaylistIndex: index,
          currentTitle: state.playlistNames[index],
          currentThumbnailUrl: index < state.playlistThumbnails.length
              ? state.playlistThumbnails[index]
              : null,
        );
      }
    });

    ref.onDispose(() {
      windowManager.removeListener(this);
      playlistSub.cancel();
      indexSub.cancel();
    });

    return PlayerState();
  }

  // --- Window Handling Logic ---
  Future<void> _checkInitialMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (maximized != state.isMaximized) {
      state = state.copyWith(isMaximized: maximized);
    }
  }

  @override
  void onWindowMaximize() {
    state = state.copyWith(isMaximized: true);
    // Auto-unpin when maximized to prevent windowing glitches
    if (state.isAlwaysOnTop) {
      toggleAlwaysOnTop();
    }
  }

  @override
  void onWindowUnmaximize() => state = state.copyWith(isMaximized: false);

  @override
  void onWindowRestore() => state = state.copyWith(isMaximized: false);

  bool _wasMaximizedBeforeFS = false;

  Future<void> toggleFullScreen() async {
    final newState = !state.isFullScreen;

    if (newState) {
      // ENTERING FULLSCREEN
      _wasMaximizedBeforeFS = await windowManager.isMaximized();
      if (!_wasMaximizedBeforeFS) await windowManager.maximize();
      await windowManager.setFullScreen(true);
    } else {
      // EXITING FULLSCREEN
      await windowManager.setFullScreen(false);
      if (!_wasMaximizedBeforeFS) await windowManager.unmaximize();
    }

    state = state.copyWith(isFullScreen: newState);
  }

  Future<void> toggleAlwaysOnTop() async {
    final newState = !state.isAlwaysOnTop;
    await windowManager.setAlwaysOnTop(newState);

    if (newState) {
      await windowManager.focus();
      // FORCE REPAINT HACK: Toggle opacity to fix "Black Screen" on some Windows drivers
      await windowManager.setOpacity(0.99);
      await Future.delayed(const Duration(milliseconds: 50));
      await windowManager.setOpacity(1.0);
    }

    state = state.copyWith(isAlwaysOnTop: newState);
  }

  // --- Navigation & Flow ---
  void setView(PlayerView view) {
    var newState = state.copyWith(currentView: view);

    // If switching to a Base View (Home/Player), update the return anchor
    if (view == PlayerView.home || view == PlayerView.player) {
      newState = newState.copyWith(baseView: view);
    }

    state = newState;
  }

  void back() {
    final current = state.currentView;

    if (current == PlayerView.shortcuts) {
      // Shortcuts always goes back to Settings
      state = state.copyWith(currentView: PlayerView.settings);
    } else if (current == PlayerView.settings) {
      // Settings returns to the last Base View (Home or Player)
      state = state.copyWith(currentView: state.baseView);
    } else {
      state = state.copyWith(currentView: PlayerView.home);
    }
  }

  void setFilePath(
    String? path, {
    Object? title = _sentinel,
    Object? thumbnail = _sentinel,
  }) => state = state.copyWith(
    currentFilePath: path,
    currentTitle: title,
    currentThumbnailUrl: thumbnail,
  );

  // --- Video Adjustments ---
  void setBrightness(double value) {
    state = state.copyWith(brightness: value.clamp(0.0, 1.0));
  }

  void cycleVideoFit() {
    final current = state.videoFit;
    BoxFit next;
    if (current == BoxFit.contain) {
      next = BoxFit.cover;
    } else if (current == BoxFit.cover) {
      next = BoxFit.fill;
    } else {
      next = BoxFit.contain;
    }
    state = state.copyWith(videoFit: next);
  }

  void rotateVideo() {
    state = state.copyWith(videoRotation: (state.videoRotation + 1) % 4);
  }

  void setSubtitleFontSize(double size) {
    state = state.copyWith(subtitleFontSize: size);
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
  }

  void togglePlaylist() {
    state = state.copyWith(isPlaylistVisible: !state.isPlaylistVisible);
  }

  /// Fully reset the player state to a fresh app-open state.
  /// Clears file path, title, thumbnail, playlist info, and video adjustments.
  void resetPlayer() {
    final player = ref.read(playerProvider);
    player.stop();

    state = PlayerState(
      // Preserve window state
      isFullScreen: state.isFullScreen,
      isMaximized: state.isMaximized,
      isAlwaysOnTop: state.isAlwaysOnTop,
      volume: state.volume,
      preMuteVolume: state.preMuteVolume,
      subtitleFontSize: state.subtitleFontSize,
    );
  }

  // --- Audio Control ---
  void setVolume(double value, {bool syncToPlayer = true}) {
    final clamped = value.clamp(0.0, 200.0);
    state = state.copyWith(volume: clamped);

    if (syncToPlayer) {
      final player = ref.read(playerProvider);
      player.setVolume(clamped.clamp(0.0, 100.0));
      if (clamped > 100) {
        try {
          (player.platform as dynamic).setProperty(
            'volume',
            clamped.toString(),
          );
        } catch (_) {}
      }
    }
  }

  void toggleMute() {
    if (state.volume > 0) {
      final prev = state.volume;
      state = state.copyWith(preMuteVolume: prev);
      setVolume(0);
    } else {
      final newVol = state.preMuteVolume > 0 ? state.preMuteVolume : 30.0;
      setVolume(newVol);
    }
  }

  // --- Playlist Management ---
  void setPlaylistInfo({
    required bool isPlaylist,
    required int length,
    required List<String> names,
    List<String>? sources,
    List<String?>? thumbnails,
    List<String?>? durations,
    int index = 0,
    String? ytPlaylistId,
    int? fetchedCount,
    bool isBatchLoading = false,
  }) {
    state = state.copyWith(
      isPlaylist: isPlaylist,
      playlistLength: length,
      playlistNames: names,
      playlistSources: sources ?? List.filled(names.length, 'Default'),
      playlistThumbnails: thumbnails ?? List.filled(names.length, null),
      playlistDurations: durations ?? List.filled(names.length, null),
      currentPlaylistIndex: index,
      youtubePlaylistId: ytPlaylistId,
      fetchedPlaylistCount: fetchedCount,
      isBatchLoading: isBatchLoading,
    );
  }

  void updatePlaylistIndex(int index) {
    state = state.copyWith(currentPlaylistIndex: index);
  }

  void setBatchLoading(bool loading) {
    state = state.copyWith(isBatchLoading: loading);
  }

  Future<void> next() async {
    if (state.isPlaylist) {
      final player = ref.read(playerProvider);
      await player.next();
    }
  }

  Future<void> previous() async {
    if (state.isPlaylist) {
      final player = ref.read(playerProvider);
      await player.previous();
    }
  }

  void cyclePlaylistMode() {
    final player = ref.read(playerProvider);
    PlaylistMode next;
    switch (state.playlistMode) {
      case PlaylistMode.none:
        next = PlaylistMode.single;
        break;
      case PlaylistMode.single:
        next = PlaylistMode.loop;
        break;
      case PlaylistMode.loop:
        next = PlaylistMode.none;
        break;
    }
    player.setPlaylistMode(next);
    state = state.copyWith(playlistMode: next);
  }
}

// 4. The Main Provider
final playerStateProvider = NotifierProvider<PlayerStateNotifier, PlayerState>(
  PlayerStateNotifier.new,
);
