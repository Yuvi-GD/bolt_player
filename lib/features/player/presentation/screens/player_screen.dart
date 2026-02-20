import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../providers/player_state_provider.dart';
import '../widgets/controls_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // Key based on file path to ensure we reset when changing files
  String? _lastPath;
  int _remountCounter = 0;
  bool _dimensionsDetected = false;

  @override
  Widget build(BuildContext context) {
    // Use the unified providers
    final player = ref.watch(playerProvider);
    final videoController = ref.watch(videoControllerProvider);

    final state = ref.watch(playerStateProvider);
    final subtitleFontSize = state.subtitleFontSize;
    final rotation = state.videoRotation;
    final fit = state.videoFit;

    // Detect file change and reset
    if (_lastPath != state.currentFilePath) {
      _lastPath = state.currentFilePath;
      _remountCounter = 0;
      _dimensionsDetected = false;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video Layer - Always Present
          Positioned.fill(
            child: StreamBuilder<int?>(
              stream: player.stream.width,
              builder: (context, snapshot) {
                // Safely handle width even if it's null
                final rawWidth = snapshot.data ?? player.state.width;
                final width = rawWidth ?? 0;
                final isOpening = width == 0;

                // AUTOMATIC REMOUNT: If width JUST arrived (from 0 to >0),
                // we force ONE rebuild to ensure the texture is bound correctly.
                if (width > 0 && !_dimensionsDetected) {
                  _dimensionsDetected = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _remountCounter++;
                      });
                      debugPrint(
                        "PlayerScreen: Dimensions detected ($width). Remounting Video widget for clean texture.",
                      );
                    }
                  });
                }

                // Build the core video widget
                Widget buildVideo() {
                  return Video(
                    key: ValueKey(
                      'video_${state.currentFilePath}_${_remountCounter}_$rotation',
                    ),
                    controller: videoController,
                    controls: (state) => const SizedBox(),
                    fit: fit,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: TextStyle(
                        height: 1.4,
                        fontSize: subtitleFontSize,
                        letterSpacing: 0.0,
                        wordSpacing: 0.0,
                        color: const Color(0xffffffff),
                        fontWeight: FontWeight.normal,
                        backgroundColor: const Color(0xaa000000),
                      ),
                      textAlign: TextAlign.center,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 150),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // Always render the Video widget so it can negotiate textures.
                    Positioned.fill(
                      child: rotation == 0
                          ? buildVideo()
                          : RotatedBox(
                              quarterTurns: rotation,
                              child: buildVideo(),
                            ),
                    ),

                    // 2. Loading / Empty State Overlay
                    // We only show this if it's actually opening (width == 0)
                    if (isOpening)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Color(0xFF00E5FF),
                                  strokeWidth: 2,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "Initializing Player...",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 3. Software Brightness Overlay
          Consumer(
            builder: (context, ref, child) {
              final brightness = ref.watch(playerStateProvider).brightness;
              if (brightness >= 1.0) return const SizedBox.shrink();

              return IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(
                    (1.0 - brightness).clamp(0.0, 0.9),
                  ),
                ),
              );
            },
          ),
          const ControlsOverlay(),
        ],
      ),
    );
  }
}
