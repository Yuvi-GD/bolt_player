import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_state_provider.dart';

class ControlsAndShortcutsScreen extends ConsumerWidget {
  const ControlsAndShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1E1E1E), Colors.black],
          ),
        ),
        child: Column(
          children: [
            // Title Header with Back Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        ref.read(playerStateProvider.notifier).back(),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'CONTROLS & SHORTCUTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('MOUSE & GESTURES', Icons.mouse_rounded),
                    const SizedBox(height: 16),
                    _buildControlRow('Center Click', 'Play / Pause', ''),
                    _buildControlRow('Long Press', '2X Playback Speed', ''),
                    _buildControlRow(
                      'Center Double-Click',
                      'Toggle Fullscreen',
                      '',
                    ),
                    _buildControlRow(
                      'Left Column Scroll',
                      'Brightness Control',
                      'Hides bottom bar',
                    ),
                    _buildControlRow(
                      'Center Scroll',
                      'Seek Video',
                      'Precise +/- 1 sec',
                    ),
                    _buildControlRow(
                      'Right Column Scroll',
                      'Volume Control',
                      'Hides bottom bar',
                    ),

                    const SizedBox(height: 48),

                    _buildSectionTitle(
                      'KEYBOARD SHORTCUTS',
                      Icons.keyboard_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildControlRow('Spacebar', 'Play / Pause', ''),
                    _buildControlRow('F / F11', 'Toggle Fullscreen', ''),
                    _buildControlRow('C', 'Subtitle', ''),
                    _buildControlRow('L', 'Lock / Unlock', ''),
                    _buildControlRow('Esc', 'Go Back / Exit', ''),
                    _buildControlRow('M', 'Mute / Unmute', ''),
                    _buildControlRow('T', 'Pin Screen', ''),
                    _buildControlRow('Left / Right Arrows', 'Seek +/- 5s', ''),
                    _buildControlRow('Up / Down Arrows', 'Volume +/- 10%', ''),
                    _buildControlRow(
                      'Ctrl + Up / Down',
                      'Brightness +/- 10%',
                      '',
                    ),
                    _buildControlRow(
                      'Ctrl + Left / Right',
                      'Next / Previous',
                      '',
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildControlRow(String input, String action, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Input (Key/Action)
          SizedBox(
            width: 200,
            child: Text(
              input,
              style: const TextStyle(
                color: Color(0xFF00E5FF), // Neon accent for inputs
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Arrow divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.arrow_right_alt_rounded, color: Colors.white24),
          ),
          // Action
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
