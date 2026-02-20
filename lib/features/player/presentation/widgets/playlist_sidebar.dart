import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_state_provider.dart';

class PlaylistSidebar extends ConsumerWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const PlaylistSidebar({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final playlistNames = state.playlistNames;
    final currentIndex = state.currentPlaylistIndex;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: isVisible ? 0 : -320,
      top: 0,
      bottom: 0,
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F).withOpacity(0.95),
          border: const Border(
            left: BorderSide(color: Colors.white10, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 30,
              offset: const Offset(-10, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: playlistNames.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount:
                          playlistNames.length + (state.isBatchLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == playlistNames.length) {
                          return _buildBatchLoader();
                        }

                        final sources = state.playlistSources;
                        final thumbnails = state.playlistThumbnails;
                        final durations = state.playlistDurations;
                        final showSourceHeader =
                            index == 0 ||
                            (index < sources.length &&
                                index > 0 &&
                                sources[index] != sources[index - 1]);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showSourceHeader && index < sources.length)
                              _buildSourceHeader(sources[index]),
                            _buildPlaylistItem(
                              context,
                              ref,
                              index,
                              playlistNames[index],
                              index < thumbnails.length
                                  ? thumbnails[index]
                                  : null,
                              index < durations.length
                                  ? durations[index]
                                  : null,
                              index == currentIndex,
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.playlist_play_rounded,
              color: Color(0xFF00E5FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'PLAYLIST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38),
            onPressed: onClose,
            hoverColor: Colors.white10,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_remove_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Items in Playlist',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceHeader(String source) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Icon(
            source == 'YouTube' || source == 'YouTube Playlist'
                ? Icons.subscriptions_rounded
                : Icons.folder_rounded,
            size: 14,
            color: const Color(0xFF00E5FF).withOpacity(0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              source.toUpperCase(),
              style: TextStyle(
                color: const Color(0xFF00E5FF).withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchLoader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'LOADING NEXT BATCH...',
              style: TextStyle(
                color: const Color(0xFF00E5FF).withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    String name,
    String? thumbnailUrl,
    String? duration,
    bool isCurrent,
  ) {
    return InkWell(
      onTap: () {
        ref.read(playerProvider).jump(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF00E5FF).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF00E5FF).withOpacity(0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Index (Outside Thumbnail)
            Container(
              width: 32,
              alignment: Alignment.centerLeft,
              child: Text(
                '${index + 1}.',
                style: TextStyle(
                  color: isCurrent ? const Color(0xFF00E5FF) : Colors.white24,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 56,
                    color: Colors.white.withOpacity(0.05),
                    child: thumbnailUrl != null
                        ? Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 1,
                                  color: Colors.white24,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white24,
                                    size: 20,
                                  ),
                                ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.video_library_rounded,
                              color: Colors.white10,
                              size: 20,
                            ),
                          ),
                  ),
                ),
                if (isCurrent)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF00E5FF),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                // Duration Badge (Bottom Right)
                if (duration != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 4),
                    Text(
                      'PLAYING NOW',
                      style: TextStyle(
                        color: const Color(0xFF00E5FF).withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
