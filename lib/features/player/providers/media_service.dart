import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import 'player_state_provider.dart';
import 'notification_provider.dart';

class MediaService {
  final Ref ref;
  bool _isFetching = false;
  MediaService(this.ref);

  Future<void> openMedia(BuildContext context, String source) async {
    final cleanedSource = source.trim();
    if (cleanedSource.isEmpty) return;

    final player = ref.read(playerProvider);
    final notification = ref.read(notificationProvider.notifier);
    final stateNotifier = ref.read(playerStateProvider.notifier);

    notification.show(
      message: 'Processing Media...',
      icon: Icons.auto_awesome_motion_rounded,
      isCenter: false,
      duration: const Duration(seconds: 45),
    );

    try {
      List<Media> mediaList = [];
      List<String> names = [];
      List<String> sources = [];
      List<String?> thumbnails = [];
      List<String?> durations = [];
      String? initialThumbnail;

      // 1. Check if it's a YouTube Playlist or Mix
      if (cleanedSource.contains('youtube.com') ||
          cleanedSource.contains('youtu.be')) {
        final ytExplode = yt.YoutubeExplode();
        try {
          if (cleanedSource.contains('list=') &&
              !cleanedSource.contains('list=RD')) {
            debugPrint('MediaService: Standard Playlist URL detected.');
            notification.show(
              message: 'Fetching Playlist...',
              icon: Icons.playlist_play_rounded,
              isCenter: false,
            );

            try {
              final playlist = await ytExplode.playlists.get(cleanedSource);
              await for (final video in ytExplode.playlists.getVideos(
                playlist.id,
              )) {
                // LOAD ONLY 1 VIDEO INITIALLY
                if (mediaList.isNotEmpty) break;
                try {
                  final manifest = await ytExplode.videos.streamsClient
                      .getManifest(video.id);
                  final streamInfo = manifest.muxed.withHighestBitrate();
                  mediaList.add(Media(streamInfo.url.toString()));
                  names.add(video.title);
                  sources.add('YouTube Playlist');
                  thumbnails.add(video.thumbnails.standardResUrl);
                  durations.add(_formatYTDuration(video.duration));
                  initialThumbnail = video.thumbnails.standardResUrl;
                } catch (vError) {
                  debugPrint(
                    'MediaService: Skipped video ${video.id} due to error: $vError',
                  );
                }
              }

              // 2. Prepare Player & Open
              ref.read(videoControllerProvider.notifier).reset();
              await player.stop();
              await player.open(Playlist(mediaList), play: true);

              // Set initial batch and start lazy tracker
              stateNotifier.setPlaylistInfo(
                isPlaylist: true,
                length: mediaList.length,
                names: names,
                sources: sources,
                thumbnails: thumbnails,
                durations: durations,
                ytPlaylistId: playlist.id.value,
                fetchedCount: mediaList.length,
              );

              // Update current file path with first video info
              stateNotifier.setFilePath(
                mediaList.first.uri,
                title: names.first,
                thumbnail: thumbnails.first,
              );

              // IMMEDIATELY TRIGGER NEXT 20
              fetchNextBatch(customBatchSize: 20);

              notification.clear();
              stateNotifier.setView(PlayerView.player);
              return; // EARLY RETURN
            } catch (playlistError) {
              debugPrint('MediaService: Playlist fetch failed: $playlistError');
              // Fallback: More robust video ID extraction
              String? videoId;
              try {
                videoId = yt.VideoId.parseVideoId(cleanedSource);
              } catch (_) {
                for (var p in [
                  r'(?:v=|\/)([a-zA-Z0-9_-]{11})(?:\?|&|$)',
                  r'youtu\.be\/([a-zA-Z0-9_-]{11})',
                  r'embed\/([a-zA-Z0-9_-]{11})',
                ]) {
                  final match = RegExp(p).firstMatch(cleanedSource);
                  if (match != null) {
                    videoId = match.group(1);
                    break;
                  }
                }
              }

              if (videoId != null) {
                debugPrint(
                  'MediaService: Falling back to single video ID: $videoId',
                );
                final video = await ytExplode.videos.get(videoId);
                final manifest = await ytExplode.videos.streamsClient
                    .getManifest(video.id);
                final streamInfo = manifest.muxed.withHighestBitrate();
                mediaList.add(Media(streamInfo.url.toString()));
                names.add(video.title);
                sources.add('YouTube');
                notification.show(
                  message: 'Loaded video (Playlist unavailable)',
                  duration: const Duration(seconds: 2),
                );
              } else {
                rethrow;
              }
            }
          } else {
            final video = await ytExplode.videos.get(cleanedSource);
            final manifest = await ytExplode.videos.streamsClient.getManifest(
              video.id,
            );
            final streamInfo = manifest.muxed.withHighestBitrate();
            mediaList.add(Media(streamInfo.url.toString()));
            names.add(video.title);
            sources.add('YouTube');
            initialThumbnail = video.thumbnails.standardResUrl;
          }
        } finally {
          ytExplode.close();
        }
      } else {
        // Local file or direct link
        mediaList.add(Media(cleanedSource));
        names.add(cleanedSource.split(RegExp(r'[\\/]+')).last);
        sources.add(
          File(cleanedSource).parent.path.split(RegExp(r'[\\/]+')).last,
        );
      }

      if (mediaList.isEmpty) throw Exception('No playable media found.');

      // 2. Prepare Player
      debugPrint('MediaService: Resetting VideoController...');
      ref.read(videoControllerProvider.notifier).reset();
      await player.stop();

      String initialTitle = names.isNotEmpty
          ? names.first
          : cleanedSource.split(RegExp(r'[\\/]+')).last;

      // 3. Open as Playlist if multiple items
      if (mediaList.length > 1) {
        await player.open(Playlist(mediaList), play: true);
        stateNotifier.setPlaylistInfo(
          isPlaylist: true,
          length: mediaList.length,
          names: names,
          sources: sources,
          ytPlaylistId:
              (cleanedSource.contains('list=') &&
                  !cleanedSource.contains('list=RD'))
              ? yt.PlaylistId.parsePlaylistId(cleanedSource).toString()
              : null,
          fetchedCount: mediaList.length,
        );
      } else {
        await player.open(mediaList.first, play: true);
        stateNotifier.setPlaylistInfo(
          isPlaylist: false,
          length: 1,
          names: names,
          sources: sources,
          index: 0,
        );
      }

      // ONLY call setFilePath if it wasn't already set by a specific playlist branch
      if (ref.read(playerStateProvider).currentTitle != initialTitle ||
          ref.read(playerStateProvider).currentThumbnailUrl !=
              initialThumbnail) {
        stateNotifier.setFilePath(
          cleanedSource,
          title: initialTitle,
          thumbnail: initialThumbnail,
        );
      }

      // 4. Capture screenshot for local files if no thumbnail
      if (initialThumbnail == null && !cleanedSource.startsWith('http')) {
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            final screenshot = await player.screenshot();
            if (screenshot != null) {
              // We don't save to file to avoid disk junk, just use the bytes if possible
              // but for now, we'll just skip or use a better placeholder.
              // Actually, let's just use a dedicated "Local File" icon for now
              // as screenshots are heavy for state.
            }
          } catch (_) {}
        });
      }
      notification.clear();
      stateNotifier.setView(PlayerView.player);
    } catch (e) {
      debugPrint('MediaService Error: $e');
      notification.show(
        message: 'Error: ${e.toString().split('\n').first}',
        icon: Icons.error_outline_rounded,
        isCenter: false,
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Support for opening multiple local files
  Future<void> openMultipleFiles(List<String> paths) async {
    if (paths.isEmpty) return;

    final player = ref.read(playerProvider);
    final stateNotifier = ref.read(playerStateProvider.notifier);

    ref.read(videoControllerProvider.notifier).reset();
    await player.stop();

    List<Media> mediaList = paths.map((p) => Media(p)).toList();
    List<String> names = paths
        .map((p) => p.split(RegExp(r'[\\/]+')).last)
        .toList();
    List<String> sources = paths.map((p) {
      final parent = File(p).parent.path.split(RegExp(r'[\\/]+')).last;
      return parent.isEmpty ? 'File' : parent;
    }).toList();

    await player.open(Playlist(mediaList), play: true);

    stateNotifier.setPlaylistInfo(
      isPlaylist: true,
      length: mediaList.length,
      names: names,
      sources: sources,
    );
    stateNotifier.setFilePath(paths.first, title: names.first);
    stateNotifier.setView(PlayerView.player);
  }

  // --- Folder Support ---
  Future<void> openFolder(
    String path, {
    bool recursive = true,
    bool append = false,
  }) async {
    await openMultipleFolders([path], recursive: recursive, append: append);
  }

  Future<void> openMultipleFolders(
    List<String> folderPaths, {
    bool recursive = true,
    bool append = false,
  }) async {
    final player = ref.read(playerProvider);
    final stateNotifier = ref.read(playerStateProvider.notifier);
    final notification = ref.read(notificationProvider.notifier);

    notification.show(
      message: 'Scanning Folders...',
      icon: Icons.folder_open_rounded,
    );

    final Set<String> supportedExtensions = {
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

    try {
      List<({String path, String name, String source, bool isRoot})>
      entriesList = [];

      for (var folderPath in folderPaths) {
        final dir = Directory(folderPath);
        if (!await dir.exists()) continue;

        final List<FileSystemEntity> entities = dir.listSync(
          recursive: recursive,
        );
        for (var f in entities) {
          if (f is File) {
            final ext = f.path.split('.').last.toLowerCase();
            if (supportedExtensions.contains(ext)) {
              final fileName = f.path.split(RegExp(r'[\\/]+')).last;
              final parentPath = f.parent.path;
              // Check if the file's parent is the root folder we're scanning
              final isRoot =
                  parentPath.replaceAll('\\', '/') ==
                  folderPath.replaceAll('\\', '/');

              final parentFolder = parentPath.split(RegExp(r'[\\/]+')).last;
              entriesList.add((
                path: f.path,
                name: fileName,
                source: parentFolder.isEmpty ? 'Folder' : parentFolder,
                isRoot: isRoot,
              ));
            }
          }
        }
      }

      if (entriesList.isEmpty) {
        throw Exception('No supported media files found.');
      }

      // Sort: Roots first, then by Source (Folder), then by Name
      if (!append) {
        entriesList.sort((a, b) {
          if (a.isRoot != b.isRoot) return a.isRoot ? -1 : 1;
          final sourceComp = a.source.toLowerCase().compareTo(
            b.source.toLowerCase(),
          );
          if (sourceComp != 0) return sourceComp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }

      List<String> paths = entriesList.map((e) => e.path).toList();
      List<String> names = entriesList.map((e) => e.name).toList();
      List<String> sources = entriesList.map((e) => e.source).toList();

      List<Media> mediaList = paths.map((p) => Media(p)).toList();

      final currentState = ref.read(playerStateProvider);
      if (append && currentState.isPlaylist) {
        // Appending to current native playlist
        List<String> combinedNames = List.from(currentState.playlistNames)
          ..addAll(names);
        List<String> combinedSources = List.from(currentState.playlistSources)
          ..addAll(sources);

        for (var m in mediaList) {
          await player.add(m);
        }

        stateNotifier.setPlaylistInfo(
          isPlaylist: true,
          length: combinedNames.length,
          names: combinedNames,
          sources: combinedSources,
          index: currentState.currentPlaylistIndex,
        );
      } else {
        // New playlist
        ref.read(videoControllerProvider.notifier).reset();
        await player.stop();
        await player.open(Playlist(mediaList), play: true);

        stateNotifier.setPlaylistInfo(
          isPlaylist: true,
          length: mediaList.length,
          names: names,
          sources: sources,
        );
        stateNotifier.setFilePath(folderPaths.first, title: names.first);
        stateNotifier.setView(PlayerView.player);
      }

      notification.clear();
    } catch (e) {
      notification.show(
        message: 'Error: ${e.toString().split('\n').first}',
        icon: Icons.error_outline_rounded,
        duration: const Duration(seconds: 4),
      );
    }
  }

  // --- Lazy Loading ---
  Future<void> fetchNextBatch({int customBatchSize = 20}) async {
    if (_isFetching) return;

    final state = ref.read(playerStateProvider);
    final playlistId = state.youtubePlaylistId;
    if (playlistId == null) return;

    _isFetching = true;
    final ytExplode = yt.YoutubeExplode();
    final player = ref.read(playerProvider);
    final stateNotifier = ref.read(playerStateProvider.notifier);

    stateNotifier.setBatchLoading(true);
    try {
      debugPrint(
        'MediaService: Fetching next batch ($customBatchSize) for $playlistId...',
      );
      int count = 0;
      int batchAdded = 0;

      await for (final video in ytExplode.playlists.getVideos(playlistId)) {
        // BREAK IF PLAYLIST CHANGED (User switched to local or different YT)
        if (ref.read(playerStateProvider).youtubePlaylistId != playlistId) {
          debugPrint(
            'MediaService: Playlist ID changed. Stopping batch fetch.',
          );
          break;
        }

        count++;
        // Skip already fetched
        if (count <= state.fetchedPlaylistCount) continue;
        if (batchAdded >= customBatchSize) break;

        try {
          final manifest = await ytExplode.videos.streamsClient.getManifest(
            video.id,
          );

          // RE-CHECK ID BEFORE ADDING TO PLAYER
          if (ref.read(playerStateProvider).youtubePlaylistId != playlistId) {
            break;
          }

          final streamInfo = manifest.muxed.withHighestBitrate();
          final media = Media(streamInfo.url.toString());

          await player.add(media);

          final currentState = ref.read(playerStateProvider);
          List<String> updatedNames = List.from(currentState.playlistNames)
            ..add(video.title);
          List<String> updatedSources = List.from(currentState.playlistSources)
            ..add('YouTube Playlist');
          List<String?> updatedThumbs = List.from(
            currentState.playlistThumbnails,
          )..add(video.thumbnails.mediumResUrl);
          List<String?> updatedDurations = List.from(
            currentState.playlistDurations,
          )..add(_formatYTDuration(video.duration));

          stateNotifier.setPlaylistInfo(
            isPlaylist: true,
            length: updatedNames.length,
            names: updatedNames,
            sources: updatedSources,
            thumbnails: updatedThumbs,
            durations: updatedDurations,
            index: currentState.currentPlaylistIndex,
            ytPlaylistId: playlistId,
            fetchedCount: updatedNames.length,
            isBatchLoading: false,
          );
          batchAdded++;
        } catch (e) {
          debugPrint('MediaService (Lazy): Error loading video $count: $e');
        }
      }
    } finally {
      ytExplode.close();
      _isFetching = false;
      stateNotifier.setBatchLoading(false);
      debugPrint('MediaService: Batch fetch complete.');
    }
  }

  String _formatYTDuration(Duration? d) {
    if (d == null) return '--:--';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds';
  }
}

final mediaServiceProvider = Provider<MediaService>((ref) {
  final service = MediaService(ref);
  final player = ref.watch(playerProvider);

  // Use a proper stream listener for lazy loading
  final playlistSub = player.stream.playlist.listen((playlist) {
    final state = ref.read(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    // 1. Update Index
    if (playlist.index != state.currentPlaylistIndex) {
      notifier.updatePlaylistIndex(playlist.index);

      // 2. Sync Metadata for Hover Card / Title
      if (state.isPlaylist && playlist.index < state.playlistNames.length) {
        // Partial update: don't pass 'path' so it remains unchanged via the sentinel
        notifier.setFilePath(
          state.currentFilePath,
          title: state.playlistNames[playlist.index],
          thumbnail: playlist.index < state.playlistThumbnails.length
              ? state.playlistThumbnails[playlist.index]
              : null,
        );
      }
    }

    // 3. Lazy Loading check
    if (state.youtubePlaylistId != null) {
      if (playlist.index >= state.fetchedPlaylistCount - 3) {
        service.fetchNextBatch(customBatchSize: 20);
      }
    }
  });

  // Use a proper stream listener for volume sync
  final volumeSub = player.stream.volume.listen((vol) {
    final notifier = ref.read(playerStateProvider.notifier);
    final currentState = ref.read(playerStateProvider);

    // CRITICAL: Ignore fallback to 100% if we are currently boosted (> 100%)
    // The engine emits 100.0 when we use setProperty for boost.
    if ((vol - 100.0).abs() < 0.001 && currentState.volume > 100.0) return;

    if (vol <= 100 && (vol - currentState.volume).abs() > 0.5) {
      notifier.setVolume(vol, syncToPlayer: false);
    }
  });

  ref.onDispose(() {
    playlistSub.cancel();
    volumeSub.cancel();
  });

  return service;
});
