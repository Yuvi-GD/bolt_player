import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/player_state_provider.dart';

class TitleBar extends ConsumerWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final currentView = state.currentView;

    String titleText = 'Bolt Player';
    if (currentView == PlayerView.settings) {
      titleText = 'Bolt Player - Settings';
    } else if (currentView == PlayerView.shortcuts) {
      titleText = 'Bolt Player - Shortcuts';
    } else if (currentView != PlayerView.home && state.currentTitle != null) {
      titleText = state.currentTitle!;
    }

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // Logo (Home)
          InkWell(
            onTap: () async {
              ref.read(playerStateProvider.notifier).setView(PlayerView.home);
            },
            hoverColor: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Image.asset(
                'assets/logo/Bolt_Player.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.bolt,
                    size: 20,
                    color: Color(0xFF00E5FF),
                  );
                },
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onDoubleTap: () {
                if (currentView == PlayerView.settings ||
                    currentView == PlayerView.shortcuts) {
                  ref.read(playerStateProvider.notifier).back();
                } else if (currentView == PlayerView.home &&
                    state.currentFilePath != null) {
                  ref
                      .read(playerStateProvider.notifier)
                      .setView(PlayerView.player);
                } else {
                  windowManager.maximize();
                }
              },
              child: DragToMoveArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),

          // Quick Play/Pause & Volume (Only show if media is loaded and NOT on player screen)
          if (currentView != PlayerView.player &&
              state.currentFilePath != null) ...[
            // Volume Icon with Scroll Support
            Tooltip(
              message: 'Volume: ${state.volume.toInt()}%',
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final delta = pointerSignal.scrollDelta.dy;
                    final notifier = ref.read(playerStateProvider.notifier);
                    final newVol = (state.volume - (delta / 5)).clamp(
                      0.0,
                      200.0,
                    );
                    notifier.setVolume(newVol);
                  }
                },
                child: _WindowButton(
                  icon: state.volume == 0
                      ? Icons.volume_off_rounded
                      : state.volume < 50
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
                  onPressed: () =>
                      ref.read(playerStateProvider.notifier).toggleMute(),
                ),
              ),
            ),

            _PlayButtonWithHoverCard(state: state),
          ],

          _WindowButton(
            icon: Icons.settings_rounded,
            onPressed: () => ref
                .read(playerStateProvider.notifier)
                .setView(PlayerView.settings),
          ),
          _WindowButton(
            icon: state.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: state.isLocked ? const Color(0xFF00E5FF) : null,
            onPressed: () =>
                ref.read(playerStateProvider.notifier).toggleLock(),
          ),
          _WindowButton(
            icon: state.isAlwaysOnTop
                ? Icons.push_pin
                : Icons.push_pin_outlined,
            color: state.isAlwaysOnTop ? const Color(0xFF00E5FF) : null,
            onPressed: () =>
                ref.read(playerStateProvider.notifier).toggleAlwaysOnTop(),
          ),

          const SizedBox(width: 24),
          _WindowButtons(),
        ],
      ),
    );
  }
}

class _WindowButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowButton(
          icon: Icons.remove,
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: Icons.check_box_outline_blank,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              if (ref.read(playerStateProvider).isAlwaysOnTop) {
                await ref
                    .read(playerStateProvider.notifier)
                    .toggleAlwaysOnTop();
              }
              windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: Icons.close,
          onPressed: () => windowManager.close(),
          isClose: true,
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onDoubleTap;
  final bool isClose;
  final Color? color;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.onDoubleTap,
    this.isClose = false,
    this.color,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 46,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isClose ? Colors.red : Colors.white10)
                : Colors.transparent,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.isClose
                  ? Colors.white
                  : (widget.color ??
                        (_isHovered ? Colors.white : Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButtonWithHoverCard extends ConsumerStatefulWidget {
  final PlayerState state;
  const _PlayButtonWithHoverCard({required this.state});

  @override
  ConsumerState<_PlayButtonWithHoverCard> createState() =>
      __PlayButtonWithHoverCardState();
}

class __PlayButtonWithHoverCardState
    extends ConsumerState<_PlayButtonWithHoverCard> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-240, 40),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.state.currentThumbnailUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.state.currentThumbnailUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 140,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    widget.state.currentTitle ?? 'Unknown Title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  StreamBuilder<Duration>(
                    stream: ref.watch(playerProvider).stream.position,
                    initialData: ref.read(playerProvider).state.position,
                    builder: (context, posSnap) {
                      return StreamBuilder<Duration>(
                        stream: ref.watch(playerProvider).stream.duration,
                        initialData: ref.read(playerProvider).state.duration,
                        builder: (context, durSnap) {
                          final position = posSnap.data ?? Duration.zero;
                          final duration = durSnap.data ?? Duration.zero;
                          final progress = duration.inMilliseconds > 0
                              ? position.inMilliseconds /
                                    duration.inMilliseconds
                              : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor: Colors.white10,
                                  color: const Color(0xFF00E5FF),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _showOverlay(),
        onExit: (_) => _hideOverlay(),
        child: StreamBuilder<bool>(
          stream: ref.watch(playerProvider).stream.playing,
          initialData: ref.read(playerProvider).state.playing,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? false;
            return _WindowButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: const Color(0xFF00E5FF),
              onPressed: () => ref.read(playerProvider).playOrPause(),
              onDoubleTap: () {
                _hideOverlay();
                ref
                    .read(playerStateProvider.notifier)
                    .setView(PlayerView.player);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }
}
