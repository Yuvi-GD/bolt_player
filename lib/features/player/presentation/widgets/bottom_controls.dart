import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../providers/player_state_provider.dart';
import '../../providers/notification_provider.dart';

class BottomControls extends ConsumerStatefulWidget {
  final bool isVisible;
  final VoidCallback onShowSettings;

  const BottomControls({
    super.key,
    required this.isVisible,
    required this.onShowSettings,
  });

  @override
  ConsumerState<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends ConsumerState<BottomControls> {
  bool _showRemaining = false;
  bool _isHoveringVolume = false;
  bool _isDraggingSeek = false;
  double _dragSeekValue = 0.0;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _toggleMute() {
    final notifier = ref.read(playerStateProvider.notifier);
    notifier.toggleMute();
    final afterMute = ref.read(playerStateProvider).volume;

    final player = ref.read(playerProvider);
    player.setVolume(afterMute.clamp(0.0, 100.0));

    ref
        .read(notificationProvider.notifier)
        .show(
          message: afterMute == 0 ? 'Muted' : 'Unmuted',
          icon: afterMute == 0
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
        );
  }

  void _setVolume(double vol) {
    ref.read(playerStateProvider.notifier).setVolume(vol);
    final player = ref.read(playerProvider);
    player.setVolume(vol.clamp(0.0, 100.0));

    if (vol > 100) {
      try {
        (player.platform as dynamic).setProperty('volume', vol.toString());
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final volume = ref.watch(playerStateProvider).volume;

    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap:
            () {}, // Eat taps on the background (Fixes background pause/speedup when clicking bar)
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.8),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Seek Bar
                  StreamBuilder<Duration>(
                    stream: player.stream.position,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = player.state.duration;
                      final sliderValue = _isDraggingSeek
                          ? _dragSeekValue
                          : position.inSeconds.toDouble().clamp(
                              0.0,
                              duration.inSeconds.toDouble(),
                            );
                      final max = duration.inSeconds.toDouble();

                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: const Color(0xFF00E5FF),
                          inactiveTrackColor: const Color(
                            0xFF00E5FF,
                          ).withOpacity(0.2),
                          thumbColor: const Color(0xFF00E5FF),
                          trackShape: const RectangularSliderTrackShape(),
                        ),
                        child: Slider(
                          value: sliderValue,
                          min: 0,
                          max: max > 0 ? max : 1.0,
                          onChangeStart: (value) {
                            setState(() {
                              _isDraggingSeek = true;
                              _dragSeekValue = value;
                            });
                          },
                          onChanged: (value) {
                            setState(() => _dragSeekValue = value);
                          },
                          onChangeEnd: (value) {
                            setState(() => _isDraggingSeek = false);
                            player.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 4),

                  // 2. Control Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LEFT: Time & Volume
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<Duration>(
                            stream: player.stream.position,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = player.state.duration;
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _showRemaining = !_showRemaining,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF00E5FF,
                                      ).withOpacity(0.6),
                                    ),
                                  ),
                                  child: Text(
                                    _showRemaining
                                        ? '${_formatDuration(position)} / -${_formatDuration(duration - position)}'
                                        : '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Listener(
                            onPointerSignal: (event) {
                              if (event is PointerScrollEvent) {
                                final delta = event.scrollDelta.dy;
                                final change = (delta > 0) ? -5.0 : 5.0;
                                _setVolume((volume + change).clamp(0.0, 200.0));
                              }
                            },
                            child: MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _isHoveringVolume = true),
                              onExit: (_) =>
                                  setState(() => _isHoveringVolume = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _isHoveringVolume ? 140 : 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _isHoveringVolume
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        volume == 0
                                            ? Icons.volume_off_rounded
                                            : Icons.volume_up_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        maxWidth: 32,
                                      ),
                                      onPressed: _toggleMute,
                                    ),
                                    if (_isHoveringVolume)
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context)
                                              .copyWith(
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                      enabledThumbRadius: 5,
                                                    ),
                                                trackHeight: 2,
                                                overlayShape:
                                                    SliderComponentShape
                                                        .noOverlay,
                                                activeTrackColor: const Color(
                                                  0xFF00E5FF,
                                                ),
                                                inactiveTrackColor:
                                                    Colors.white24,
                                              ),
                                          child: Slider(
                                            value: volume,
                                            min: 0,
                                            max: 200,
                                            onChanged: _setVolume,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // CENTER: Playback
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            color: Colors.white,
                            onPressed: player.previous,
                          ),
                          const SizedBox(width: 12),
                          StreamBuilder<bool>(
                            stream: player.stream.playing,
                            initialData: player.state.playing,
                            builder: (context, snapshot) {
                              final playing =
                                  snapshot.data ?? player.state.playing;
                              return GestureDetector(
                                onTap: () => player.playOrPause(),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF00E5FF,
                                        ).withOpacity(0.4),
                                        blurRadius: 15,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: const Color(0xFF00E5FF),
                                    size: 36,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            color: Colors.white,
                            onPressed: player.next,
                          ),
                        ],
                      ),

                      // RIGHT: Tools
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<Track>(
                            stream: player.stream.track,
                            initialData: player.state.track,
                            builder: (context, snapshot) {
                              final currentTrack =
                                  snapshot.data ?? player.state.track;
                              final currentSubtitle = currentTrack.subtitle;
                              final isSubtitleActive =
                                  currentSubtitle.id != 'no';
                              return IconButton(
                                icon: const Icon(Icons.subtitles_rounded),
                                color: isSubtitleActive
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white,
                                onPressed: () {
                                  if (isSubtitleActive) {
                                    player.setSubtitleTrack(SubtitleTrack.no());
                                    ref
                                        .read(notificationProvider.notifier)
                                        .show(
                                          message: 'Subtitles Off',
                                          icon: Icons.subtitles_off_rounded,
                                        );
                                  } else {
                                    final subtitles =
                                        player.state.tracks.subtitle;
                                    if (subtitles.isNotEmpty) {
                                      final first = subtitles.firstWhere(
                                        (t) => t.id != 'auto' && t.id != 'no',
                                        orElse: () => SubtitleTrack.no(),
                                      );
                                      if (first.id != 'no') {
                                        player.setSubtitleTrack(first);
                                        ref
                                            .read(notificationProvider.notifier)
                                            .show(
                                              message:
                                                  'Subtitles On (${first.language ?? first.title ?? 'Unknown'})',
                                              icon: Icons.subtitles_rounded,
                                            );
                                      } else {
                                        ref
                                            .read(notificationProvider.notifier)
                                            .show(
                                              message: 'No Subtitles',
                                              icon: Icons.error_outline_rounded,
                                            );
                                      }
                                    }
                                  }
                                },
                              );
                            },
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final mode = ref
                                  .read(playerStateProvider)
                                  .playlistMode;
                              IconData icon;
                              Color color;
                              switch (mode) {
                                case PlaylistMode.single:
                                  icon = Icons.repeat_one_rounded;
                                  color = const Color(0xFF00E5FF);
                                  break;
                                case PlaylistMode.loop:
                                  icon = Icons.repeat_rounded;
                                  color = const Color(0xFF00E5FF);
                                  break;
                                default:
                                  icon = Icons.repeat_rounded;
                                  color = Colors.white;
                              }
                              return IconButton(
                                icon: Icon(icon),
                                color: color,
                                onPressed: () => ref
                                    .read(playerStateProvider.notifier)
                                    .cyclePlaylistMode(),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.playlist_play_rounded),
                            color:
                                ref.watch(playerStateProvider).isPlaylistVisible
                                ? const Color(0xFF00E5FF)
                                : Colors.white,
                            onPressed: () => ref
                                .read(playerStateProvider.notifier)
                                .togglePlaylist(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_rounded),
                            color: Colors.white,
                            onPressed: widget.onShowSettings,
                          ),
                          IconButton(
                            icon: const Icon(Icons.fullscreen_rounded),
                            color: Colors.white,
                            onPressed: () => ref
                                .read(playerStateProvider.notifier)
                                .toggleFullScreen(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
