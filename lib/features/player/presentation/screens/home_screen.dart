import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../../../main.dart';
import '../../providers/player_state_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/media_service.dart';
import '../widgets/title_bar.dart';
import '../widgets/player_keyboard_handler.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'controls_and_shortcuts_screen.dart';
import '../../providers/update_provider.dart';
import '../widgets/update_dialog.dart';
import '../../providers/smtc_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Handle initial CLI argument if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ref.read(cliArgsProvider);
      if (args.isNotEmpty) {
        final path = args.first;
        if (path.isNotEmpty) {
          _openMedia(path);
        }
      }

      _checkUpdates();
    });
  }

  Future<void> _checkUpdates() async {
    final settings = await ref.read(updateSettingsProvider.future);
    if (!settings.startupCheckEnabled) return;

    final info = await ref.read(updateProvider).checkForUpdates();
    if (info != null && mounted) {
      if (info.isPatch) {
        setState(() => _patchUpdate = info);
      } else {
        // For major/minor, show dialog
        _showUpdateDialog(info);
      }
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (context) => UpdateDialog(
        info: info,
        onLater: () => ref.read(updateProvider).ignoreVersion(info.version),
        onDontShowAgain: () => ref
            .read(updateSettingsProvider.notifier)
            .setStartupCheckEnabled(false),
      ),
    );
  }

  Widget _buildTopUpdateBanner(UpdateInfo info) {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF00E5FF),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Small fix available (v${info.version})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(height: 24, width: 1, color: Colors.white10),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() => _patchUpdate = null);
                          _showUpdateDialog(info);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'VIEW',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white24,
                        ),
                        onPressed: () => setState(() => _patchUpdate = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openMedia(String path) async {
    await ref.read(mediaServiceProvider).openMedia(context, path);
    if (mounted) {
      ref.read(playerStateProvider.notifier).setView(PlayerView.player);
    }
  }

  Future<void> _pickFile() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        final paths = result.paths.whereType<String>().toList();
        if (context.mounted) {
          if (paths.length > 1) {
            await ref.read(mediaServiceProvider).openMultipleFiles(paths);
          } else {
            await _openMedia(paths.first);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFolder() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null && context.mounted) {
        await ref
            .read(mediaServiceProvider)
            .openFolder(path, recursive: _isRecursive, append: _isAppendMode);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final Set<String> _supportedExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'flv',
    'webm',
    'mp3',
    'wav',
    'm4a',
  };

  bool _isDragging = false;
  bool _isRecursive = true;
  bool _isAppendMode = false;
  bool _isLoading = false;
  UpdateInfo? _patchUpdate;

  @override
  Widget build(BuildContext context) {
    ref.watch(smtcServiceProvider);
    final appState = ref.watch(playerStateProvider);
    final currentView = appState.currentView;
    final isFullScreen = appState.isFullScreen;

    return PlayerKeyboardHandler(
      child: DropTarget(
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        onDragDone: (details) async {
          setState(() => _isDragging = false);
          if (details.files.isNotEmpty) {
            List<String> filePaths = [];
            List<String> folderPaths = [];

            for (var xfile in details.files) {
              final path = xfile.path;
              if (await Directory(path).exists()) {
                folderPaths.add(path);
              } else {
                final ext = path.split('.').last.toLowerCase();
                if (_supportedExtensions.contains(ext)) {
                  filePaths.add(path);
                }
              }
            }

            if (folderPaths.isNotEmpty) {
              await ref
                  .read(mediaServiceProvider)
                  .openMultipleFolders(
                    folderPaths,
                    recursive: _isRecursive,
                    append: _isAppendMode,
                  );
            } else if (filePaths.length > 1) {
              await ref.read(mediaServiceProvider).openMultipleFiles(filePaths);
            } else if (filePaths.length == 1) {
              await _openMedia(filePaths.first);
            } else {
              ref
                  .read(notificationProvider.notifier)
                  .show(
                    message: 'No supported media found',
                    icon: Icons.error_outline,
                  );
            }
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Background Gradient
              if (currentView == PlayerView.home)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [const Color(0xFF1E1E1E), Colors.black],
                      ),
                    ),
                  ),
                ),

              Column(
                children: [
                  if (!isFullScreen) const TitleBar(),
                  Expanded(child: _buildCurrentView(currentView)),
                ],
              ),

              // Drag & Drop Overlay
              if (_isDragging)
                Container(
                  color: Colors.black.withOpacity(0.9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.file_download_outlined,
                          size: 100,
                          color: Color(0xFF00E5FF),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'DROP TO PLAY',
                          style: TextStyle(
                            color: const Color(0xFF00E5FF),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const GlobalNotificationOverlay(),

              if (_patchUpdate != null) _buildTopUpdateBanner(_patchUpdate!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(PlayerView view) {
    switch (view) {
      case PlayerView.home:
        return _buildGamerHome();
      case PlayerView.player:
        return const PlayerScreen();
      case PlayerView.settings:
        return const SettingsScreen();
      case PlayerView.shortcuts:
        return const ControlsAndShortcutsScreen();
    }
  }

  Widget _buildContinueBar(PlayerState state) {
    return Container(
      width: 600,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFF00E5FF),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  state.currentTitle ?? 'Unknown Media',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => ref
                .read(playerStateProvider.notifier)
                .setView(PlayerView.player),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CONTINUE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamerHome() {
    final playerState = ref.watch(playerStateProvider);
    final hasPlayingMedia = playerState.currentFilePath != null;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasPlayingMedia) ...[
              _buildContinueBar(playerState),
              const SizedBox(height: 48),
            ],
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/logo/Bolt_Player.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.bolt,
                    size: 100,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            ),
            const Text(
              'BOLT PLAYER',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GamerActionCard(
                  icon: Icons.folder_open_rounded,
                  label: 'OPEN FILE',
                  onTap: _pickFile,
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 24),
                _GamerActionCard(
                  icon: Icons.create_new_folder_rounded,
                  label: 'OPEN FOLDER',
                  onTap: _pickFolder,
                  color: const Color(0xFFFFD600), // Distinct color for folders
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FolderOption(
                  label: 'Subfolders',
                  value: _isRecursive,
                  onChanged: (v) => setState(() => _isRecursive = v),
                ),
                const SizedBox(width: 24),
                _FolderOption(
                  label: 'Append Mode',
                  value: _isAppendMode,
                  onChanged: (v) => setState(() => _isAppendMode = v),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _UrlInputSection(
              isLoading: _isLoading,
              onSubmitted: (url) async {
                if (_isLoading) return;
                setState(() => _isLoading = true);
                try {
                  await _openMedia(url);
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'YouTube . M3U8 . MP4 . Direct Links',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GamerActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _GamerActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  State<_GamerActionCard> createState() => _GamerActionCardState();
}

class _GamerActionCardState extends State<_GamerActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.1)
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.color : Colors.white10,
              width: 2,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 40,
                color: _isHovered ? widget.color : Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered ? widget.color : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlInputSection extends StatefulWidget {
  final ValueChanged<String> onSubmitted;
  final bool isLoading;

  const _UrlInputSection({required this.onSubmitted, this.isLoading = false});

  @override
  _UrlInputSectionState createState() => _UrlInputSectionState();
}

class _UrlInputSectionState extends State<_UrlInputSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSubmitted(_controller.text.trim());
      _controller.clear();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.link, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !widget.isLoading,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Paste Video URL...',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow_rounded),
                    color: const Color(0xFF00E5FF),
                    iconSize: 32,
                    onPressed: _submit,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FolderOption extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FolderOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: const Color(0xFF00E5FF),
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.white24, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
