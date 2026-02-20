import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../providers/player_state_provider.dart';

class PlayerMenu extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const PlayerMenu({super.key, required this.onClose});

  @override
  ConsumerState<PlayerMenu> createState() => _PlayerMenuState();
}

class _PlayerMenuState extends ConsumerState<PlayerMenu> {
  String? _currentSubmenu;

  String _getTrackDisplayName(dynamic track) {
    if (track == null) return 'Unknown';

    String? displayName;

    // Get title or language
    if (track.title != null &&
        track.title.isNotEmpty &&
        track.title != 'null') {
      displayName = track.title;
    } else if (track.language != null &&
        track.language.isNotEmpty &&
        track.language != 'null') {
      displayName = track.language;
    } else {
      displayName = track.id;
    }

    // Map common language codes
    if (displayName == 'eng') return 'English';
    if (displayName == 'spa') return 'Spanish';
    if (displayName == 'fre' || displayName == 'fra') return 'French';
    if (displayName == 'ger' || displayName == 'deu') return 'German';
    if (displayName == 'jpn') return 'Japanese';
    if (displayName == 'kor') return 'Korean';
    if (displayName == 'chi' || displayName == 'zho') return 'Chinese';
    if (displayName == 'hin') return 'Hindi';
    if (displayName == 'por') return 'Portuguese';
    if (displayName == 'ita') return 'Italian';
    if (displayName == 'rus') return 'Russian';
    if (displayName == 'ara') return 'Arabic';

    return displayName ?? 'Track';
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.end, // Align bottoms to prevent jumping
      children: [
        // Submenu (appears LEFT of main menu)
        if (_currentSubmenu != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 0), // Base alignment
            child: _MenuContainer(child: _buildSubmenu(player)),
          ),
          const SizedBox(width: 8),
        ],

        // Main Menu
        _MenuContainer(child: _buildMainMenu(player)),
      ],
    );
  }

  Widget _buildMainMenu(Player player) {
    final tracks = player.state.tracks;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const Divider(color: Colors.white10, height: 1),

        // Playback Speed
        _buildSpeedSection(player),

        const Divider(color: Colors.white10, height: 1),

        // Subtitle Track Selection
        if (tracks.subtitle.isNotEmpty)
          _MenuItem(
            icon: Icons.closed_caption,
            label: 'Subtitle Track',
            trailing: Icon(
              Icons.chevron_left,
              color: _currentSubmenu == 'subtitles'
                  ? const Color(0xFF00E5FF)
                  : Colors.white54,
              size: 18,
            ),
            isHighlighted: _currentSubmenu == 'subtitles',
            onTap: () {
              setState(() {
                _currentSubmenu = _currentSubmenu == 'subtitles'
                    ? null
                    : 'subtitles';
              });
            },
          ),

        // Audio Tracks
        if (tracks.audio.length > 1)
          _MenuItem(
            icon: Icons.audiotrack,
            label: 'Audio Track',
            trailing: Icon(
              Icons.chevron_left,
              color: _currentSubmenu == 'audio'
                  ? const Color(0xFF00E5FF)
                  : Colors.white54,
              size: 18,
            ),
            isHighlighted: _currentSubmenu == 'audio',
            onTap: () {
              setState(() {
                _currentSubmenu = _currentSubmenu == 'audio' ? null : 'audio';
              });
            },
          ),

        // Audio Output
        if (player.state.audioDevices.isNotEmpty)
          _MenuItem(
            icon: Icons.speaker_group_outlined,
            label: 'Audio Output',
            trailing: Icon(
              Icons.chevron_left,
              color: _currentSubmenu == 'audio_output'
                  ? const Color(0xFF00E5FF)
                  : Colors.white54,
              size: 18,
            ),
            isHighlighted: _currentSubmenu == 'audio_output',
            onTap: () {
              setState(() {
                _currentSubmenu = _currentSubmenu == 'audio_output'
                    ? null
                    : 'audio_output';
              });
            },
          ),

        const Divider(color: Colors.white10, height: 1),

        // Video Adjustments
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IconButton(
                icon: Icons.aspect_ratio,
                tooltip: 'Aspect Ratio',
                onPressed: () =>
                    ref.read(playerStateProvider.notifier).cycleVideoFit(),
              ),
              _IconButton(
                icon: Icons.rotate_right,
                tooltip: 'Rotate',
                onPressed: () =>
                    ref.read(playerStateProvider.notifier).rotateVideo(),
              ),
              _IconButton(
                icon: Icons.camera_alt_outlined,
                tooltip: 'Screenshot',
                onPressed: () async {
                  final bytes = await player.screenshot();
                  if (bytes != null && context.mounted) {
                    try {
                      Directory targetDir;

                      if (Platform.isWindows) {
                        final home = Platform.environment['USERPROFILE'];
                        targetDir = Directory('$home/Pictures/Bolt Player');
                      } else {
                        final base = await getApplicationDocumentsDirectory();
                        targetDir = Directory('${base.path}/Screenshots');
                      }

                      if (!await targetDir.exists()) {
                        await targetDir.create(recursive: true);
                      }

                      // Create filename
                      final now = DateTime.now();
                      final formatter = DateFormat('yyyyMMdd_HHmmss');
                      final fileName =
                          'bolt_player_${formatter.format(now)}.png';
                      final file = File('${targetDir.path}/$fileName');

                      // Save file
                      await file.writeAsBytes(bytes);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.black.withOpacity(0.9),
                            content: Text(
                              'Saved to ${targetDir.path}',
                              style: const TextStyle(color: Color(0xFF00E5FF)),
                            ),
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: 'Open',
                              textColor: const Color(0xFF00E5FF),
                              onPressed: () {
                                if (Platform.isWindows) {
                                  Process.run('explorer.exe', [
                                    targetDir.path.replaceAll('/', '\\'),
                                  ]);
                                }
                              },
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.black.withOpacity(0.9),
                            content: Text(
                              'Error saving screenshot: $e',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedSection(Player player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 16, color: Colors.white70),
              const SizedBox(width: 10),
              const Text(
                'Speed',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<double>(
            stream: player.stream.rate,
            initialData: player.state.rate,
            builder: (context, snapshot) {
              final rate = snapshot.data ?? player.state.rate;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SpeedButton(
                    text: '0.5x',
                    isSelected: rate == 0.5,
                    onTap: () => player.setRate(0.5),
                  ),
                  _SpeedButton(
                    text: '1x',
                    isSelected: rate == 1.0,
                    onTap: () => player.setRate(1.0),
                  ),
                  _SpeedButton(
                    text: '1.5x',
                    isSelected: rate == 1.5,
                    onTap: () => player.setRate(1.5),
                  ),
                  _SpeedButton(
                    text: '2x',
                    isSelected: rate == 2.0,
                    onTap: () => player.setRate(2.0),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmenu(Player player) {
    switch (_currentSubmenu) {
      case 'subtitles':
        return _buildSubtitlesSubmenu(player);
      case 'audio':
        return _buildAudioTracksSubmenu(player);
      case 'audio_output':
        return _buildAudioOutputSubmenu(player);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSubtitlesSubmenu(Player player) {
    return StreamBuilder<Track>(
      stream: player.stream.track,
      builder: (context, snapshot) {
        final subtitles = player.state.tracks.subtitle;
        final currentSub =
            snapshot.data?.subtitle ?? player.state.track.subtitle;

        return _MenuContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Subtitle Track',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // Font Size Slider
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Font Size',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          '${ref.watch(playerStateProvider).subtitleFontSize.toInt()}px',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: const Color(0xFF00E5FF),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFF00E5FF),
                        trackHeight: 2,
                      ),
                      child: Slider(
                        value: ref.watch(playerStateProvider).subtitleFontSize,
                        min: 12.0,
                        max: 48.0,
                        divisions: 12, // Steps of 3px (approx)
                        onChanged: (value) {
                          ref
                              .read(playerStateProvider.notifier)
                              .setSubtitleFontSize(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // Auto option (default)
              _SubMenuItem(
                label: 'Auto',
                isSelected: currentSub.id == 'auto',
                onTap: () => player.setSubtitleTrack(SubtitleTrack.auto()),
              ),

              _SubMenuItem(
                label: 'Disabled',
                isSelected: currentSub.id == 'no',
                onTap: () => player.setSubtitleTrack(SubtitleTrack.no()),
              ),

              ...subtitles.where((t) => t.id != 'no' && t.id != 'auto').map((
                track,
              ) {
                return _SubMenuItem(
                  label: _getTrackDisplayName(track),
                  isSelected: track.id == currentSub.id,
                  onTap: () => player.setSubtitleTrack(track),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioTracksSubmenu(Player player) {
    return StreamBuilder<Track>(
      stream: player.stream.track,
      builder: (context, snapshot) {
        final audioTracks = player.state.tracks.audio;
        final currentAudio = snapshot.data?.audio ?? player.state.track.audio;

        return _MenuContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Audio Track',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // Auto option (default)
              _SubMenuItem(
                label: 'Auto',
                isSelected: currentAudio.id == 'auto',
                onTap: () => player.setAudioTrack(AudioTrack.auto()),
              ),

              ...audioTracks.where((t) => t.id != 'no' && t.id != 'auto').map((
                track,
              ) {
                return _SubMenuItem(
                  label: _getTrackDisplayName(track),
                  isSelected: track.id == currentAudio.id,
                  onTap: () => player.setAudioTrack(track),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioOutputSubmenu(Player player) {
    return StreamBuilder<AudioDevice>(
      stream: player.stream.audioDevice,
      builder: (context, snapshot) {
        final devices = player.state.audioDevices;
        final currentDevice = snapshot.data ?? player.state.audioDevice;

        return _MenuContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Audio Output',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              ...devices.map((device) {
                return _SubMenuItem(
                  label: device.description.isNotEmpty
                      ? device.description
                      : 'Default Device',
                  isSelected: device.name == currentDevice.name,
                  onTap: () => player.setAudioDevice(device),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _MenuContainer extends StatelessWidget {
  final Widget child;
  const _MenuContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter, // Anchor to bottom
        child: Container(
          width: 250,
          // Removed fixed height
          constraints: const BoxConstraints(
            maxHeight: 400, // Relaxed max height
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics:
                const ClampingScrollPhysics(), // Prevent bounce which looks weird in small menus
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: widget.isHighlighted
              ? Colors.blueAccent.withOpacity(0.12)
              : _isHovered
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SubMenuItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SubMenuItem> createState() => _SubMenuItemState();
}

class _SubMenuItemState extends State<_SubMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: widget.isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : _isHovered
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: widget.isSelected ? Colors.blueAccent : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? const Color(0xFF00E5FF)
                        : Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: Colors.white,
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(),
        onPressed: onPressed,
      ),
    );
  }
}
