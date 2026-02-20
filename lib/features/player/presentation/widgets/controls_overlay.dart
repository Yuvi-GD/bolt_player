import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_state_provider.dart';
import '../../providers/notification_provider.dart';
import '../widgets/playlist_sidebar.dart';
import 'player_menu.dart';
import 'bottom_controls.dart';

class ControlsOverlay extends ConsumerStatefulWidget {
  const ControlsOverlay({super.key});

  @override
  ConsumerState<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends ConsumerState<ControlsOverlay> {
  bool _isVisible = false;
  Timer? _hideTimer;
  OverlayEntry? _overlayEntry;

  // Volume & Brightness HUD State
  bool _showVolume = false;
  Timer? _volumeHideTimer;
  bool _showBrightness = false;
  Timer? _brightnessHideTimer;

  // Center Icon State
  IconData _centerIcon = Icons.play_arrow_rounded;
  bool _showCenterIcon = false;
  Timer? _centerIconTimer;

  // Speed Up State (Mouse)
  Timer? _mouseSpeedUpTimer;
  bool _isMouseSpeedUp = false;
  bool _wasLongPress = false;

  @override
  void initState() {
    super.initState();
    final player = ref.read(playerProvider);

    // Listen to play/pause state for unified center icon
    player.stream.playing.listen((isPlaying) {
      if (mounted) {
        _showActionIcon(
          isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
        );
      }
    });

    // Listen to volume/brightness for HUD automation
    player.stream.volume.listen((v) {
      if (mounted) {
        final state = ref.read(playerStateProvider);
        if (state.volume <= 100 && (v - state.volume).abs() > 0.01) {
          ref.read(playerStateProvider.notifier).setVolume(v);
        }
      }
    });
  }

  void _resetVolumeTimer() {
    _volumeHideTimer?.cancel();
    _volumeHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolume = false);
    });
  }

  void _resetBrightnessTimer() {
    _brightnessHideTimer?.cancel();
    _brightnessHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showBrightness = false);
    });
  }

  // --- SCROLL ACTION DISPATCHER ---
  void _handleScroll(PointerScrollEvent event, double width) {
    final x = event.localPosition.dx;
    if (x < width * 0.25) {
      _onBrightnessScroll(event);
    } else if (x > width * 0.75) {
      _onVolumeScroll(event);
    } else {
      _onSeekScroll(event);
    }
  }

  void _onSeekScroll(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy;
    final player = ref.read(playerProvider);
    final seekDelta = delta > 0 ? -3 : 3;
    player.seek(player.state.position + Duration(seconds: seekDelta));
    ref
        .read(notificationProvider.notifier)
        .show(
          message: seekDelta > 0 ? '+3s' : '-3s',
          icon: seekDelta > 0
              ? Icons.fast_forward_rounded
              : Icons.fast_rewind_rounded,
          isCenter: true,
          duration: const Duration(milliseconds: 500),
        );
  }

  void _onVolumeScroll(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy;
    final change = (delta > 0) ? -5.0 : 5.0;
    _setVolume(
      (ref.read(playerStateProvider).volume + change).clamp(0.0, 200.0),
    );
  }

  void _onBrightnessScroll(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy;
    final change = (delta > 0) ? -0.05 : 0.05;
    _setBrightness(
      (ref.read(playerStateProvider).brightness + change).clamp(0.0, 1.0),
    );
  }

  void _setVolume(double vol) {
    if (vol == ref.read(playerStateProvider).volume) return;
    ref.read(playerStateProvider.notifier).setVolume(vol);
    final player = ref.read(playerProvider);
    player.setVolume(vol.clamp(0.0, 100.0));
    if (vol > 100) {
      try {
        (player.platform as dynamic).setProperty('volume', vol.toString());
      } catch (_) {}
    }
  }

  void _setBrightness(double bri) {
    if (bri == ref.read(playerStateProvider).brightness) return;
    ref.read(playerStateProvider.notifier).setBrightness(bri);
  }

  void _toggleMute() {
    ref.read(playerStateProvider.notifier).toggleMute();
    _setVolume(ref.read(playerStateProvider).volume);
  }

  void _showControls() {
    setState(() => _isVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  void _showActionIcon(IconData icon) {
    if (!mounted) return;
    setState(() {
      _centerIcon = icon;
      _showCenterIcon = true;
    });
    _centerIconTimer?.cancel();
    _centerIconTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showCenterIcon = false);
    });
  }

  void _togglePlayPause() {
    final player = ref.read(playerProvider);
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
    _showControls();
  }

  void _showSettingsMenu() {
    if (_overlayEntry != null) {
      _closeSettingsMenu();
      return;
    }
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeSettingsMenu,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: PlayerMenu(onClose: _closeSettingsMenu),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeSettingsMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _volumeHideTimer?.cancel();
    _brightnessHideTimer?.cancel();
    _centerIconTimer?.cancel();
    _mouseSpeedUpTimer?.cancel();
    _closeSettingsMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final state = ref.watch(playerStateProvider);

    // Auto-show HUDs on state change
    ref.listen(playerStateProvider.select((s) => s.volume), (prev, next) {
      if (prev != next && mounted) {
        setState(() => _showVolume = true);
        _resetVolumeTimer();
      }
    });
    ref.listen(playerStateProvider.select((s) => s.brightness), (prev, next) {
      if (prev != next && mounted) {
        setState(() => _showBrightness = true);
        _resetBrightnessTimer();
      }
    });

    return MouseRegion(
      onHover: (event) {
        final width = MediaQuery.of(context).size.width;
        final height = MediaQuery.of(context).size.height;
        final x = event.localPosition.dx;
        final y = event.localPosition.dy;

        final marginW = width * 0.1;
        final marginH = height * 0.1;

        // 1. BOTTOM SAFE ZONE (Where controls are)
        if (y > height - 160) {
          if (!_isVisible) setState(() => _isVisible = true);
          _showControls();
          return;
        }

        // 2. PEACE MODE (Margins)
        if (x < marginW || x > width - marginW || y < marginH) {
          if (_isVisible) setState(() => _isVisible = false);
          _hideTimer?.cancel();
        } else {
          // Center area
          _showControls();
        }
      },
      onExit: (_) {
        _hideTimer?.cancel();
        setState(() => _isVisible = false);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // --- LAYER 0: Interaction Layer (Top/Middle only) ---
              // Catch all clicks and scrolls ABOVE the controls area.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 160,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _handleScroll(event, constraints.maxWidth);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!_wasLongPress) {
                        _togglePlayPause();
                      }
                    },
                    onTapDown: (_) {
                      _wasLongPress = false;
                      _mouseSpeedUpTimer?.cancel();
                      _mouseSpeedUpTimer = Timer(
                        const Duration(milliseconds: 500),
                        () async {
                          _wasLongPress = true;
                          _isMouseSpeedUp = true;
                          await player.setRate(2.0);
                          ref
                              .read(notificationProvider.notifier)
                              .show(
                                message: '2x Speed',
                                icon: Icons.fast_forward_rounded,
                                isCenter: false,
                              );
                        },
                      );
                    },
                    onTapUp: (_) async {
                      if (_isMouseSpeedUp) {
                        await player.setRate(1.0);
                        setState(() => _isMouseSpeedUp = false);
                        ref
                            .read(notificationProvider.notifier)
                            .show(
                              message: '1x Speed',
                              icon: Icons.play_arrow_rounded,
                              isCenter: false,
                            );
                      }
                      _mouseSpeedUpTimer?.cancel();
                      _mouseSpeedUpTimer = null;
                    },
                    onTapCancel: () async {
                      if (_isMouseSpeedUp) {
                        await player.setRate(1.0);
                        setState(() => _isMouseSpeedUp = false);
                        ref
                            .read(notificationProvider.notifier)
                            .show(
                              message: '1x Speed',
                              icon: Icons.play_arrow_rounded,
                              isCenter: false,
                            );
                      }
                      _mouseSpeedUpTimer?.cancel();
                      _mouseSpeedUpTimer = null;
                    },
                    onDoubleTap: () {
                      _mouseSpeedUpTimer?.cancel();
                      _mouseSpeedUpTimer = null;
                      if (_isMouseSpeedUp) {
                        player.setRate(1.0);
                        setState(() => _isMouseSpeedUp = false);
                      }
                      ref.read(playerStateProvider.notifier).toggleFullScreen();
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              // --- LAYER 1: Indicators & Buffering ---
              _VerticalIndicator(
                isVisible: _showVolume,
                value: state.volume,
                max: 200,
                icon: state.volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                label: '${state.volume.toInt()}%',
                onChanged: _setVolume,
                onIconPressed: _toggleMute,
                alignment: Alignment.bottomRight,
              ),

              _VerticalIndicator(
                isVisible: _showBrightness,
                value: state.brightness,
                max: 1.0,
                icon: state.brightness < 0.3
                    ? Icons.brightness_low_rounded
                    : state.brightness < 0.7
                    ? Icons.brightness_medium_rounded
                    : Icons.brightness_high_rounded,
                label: '${(state.brightness * 100).toInt()}%',
                onChanged: _setBrightness,
                alignment: Alignment.bottomLeft,
              ),

              IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showCenterIcon ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _centerIcon,
                        size: 40,
                        color: const Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ),
              ),

              StreamBuilder<bool>(
                stream: player.stream.buffering,
                builder: (context, snapshot) {
                  if (!(snapshot.data ?? false)) return const SizedBox.shrink();
                  return IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // --- LAYER 2: Bottom Controls (Physically separated) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 160,
                child: IgnorePointer(
                  ignoring: state.isLocked,
                  child: AnimatedOpacity(
                    opacity: state.isLocked ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: BottomControls(
                      isVisible: _isVisible,
                      onShowSettings: _showSettingsMenu,
                    ),
                  ),
                ),
              ),

              // --- LAYER 3: Playlist Sidebar ---
              if (state.isPlaylistVisible)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(playerStateProvider.notifier).togglePlaylist(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.black26),
                  ),
                ),

              PlaylistSidebar(
                isVisible: state.isPlaylistVisible,
                onClose: () =>
                    ref.read(playerStateProvider.notifier).togglePlaylist(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VerticalIndicator extends StatelessWidget {
  final bool isVisible;
  final double value;
  final double max;
  final IconData icon;
  final String label;
  final ValueChanged<double> onChanged;
  final VoidCallback? onIconPressed;
  final Alignment alignment;

  const _VerticalIndicator({
    required this.isVisible,
    required this.value,
    required this.max,
    required this.icon,
    required this.label,
    required this.onChanged,
    this.onIconPressed,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Align(
          alignment: alignment,
          child: Container(
            margin: EdgeInsets.only(
              right: alignment == Alignment.bottomRight ? 32 : 0,
              left: alignment == Alignment.bottomLeft ? 32 : 0,
              bottom: 160,
            ),
            width: 50,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                IconButton(
                  icon: Icon(icon, color: const Color(0xFF00E5FF), size: 24),
                  onPressed: onIconPressed,
                ),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 0,
                        ),
                        trackHeight: 6,
                        activeTrackColor: value > 100
                            ? const Color(0xFFBC13FE)
                            : const Color(0xFF00E5FF),
                        inactiveTrackColor: const Color(
                          0xFF00E5FF,
                        ).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: value,
                        min: 0,
                        max: max,
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
