import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String version;
  final String url;
  final String notes;
  final bool isPatch;
  final bool isBeta;

  UpdateInfo({
    required this.version,
    required this.url,
    required this.notes,
    this.isPatch = false,
    this.isBeta = false,
  });
}

class UpdateSettings {
  final bool betaEnabled;
  final bool startupCheckEnabled;

  UpdateSettings({
    required this.betaEnabled,
    required this.startupCheckEnabled,
  });

  UpdateSettings copyWith({bool? betaEnabled, bool? startupCheckEnabled}) {
    return UpdateSettings(
      betaEnabled: betaEnabled ?? this.betaEnabled,
      startupCheckEnabled: startupCheckEnabled ?? this.startupCheckEnabled,
    );
  }
}

class UpdateSettingsNotifier extends AsyncNotifier<UpdateSettings> {
  static const String _betaKey = 'join_beta_channel';
  static const String _startupCheckKey = 'check_updates_startup';

  @override
  FutureOr<UpdateSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return UpdateSettings(
      betaEnabled: prefs.getBool(_betaKey) ?? false,
      startupCheckEnabled: prefs.getBool(_startupCheckKey) ?? true,
    );
  }

  Future<void> setBetaEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_betaKey, value);
    final current =
        state.value ??
        UpdateSettings(betaEnabled: false, startupCheckEnabled: true);
    state = AsyncData(current.copyWith(betaEnabled: value));
  }

  Future<void> setStartupCheckEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startupCheckKey, value);
    final current =
        state.value ??
        UpdateSettings(betaEnabled: false, startupCheckEnabled: true);
    state = AsyncData(current.copyWith(startupCheckEnabled: value));
  }
}

final updateSettingsProvider =
    AsyncNotifierProvider<UpdateSettingsNotifier, UpdateSettings>(() {
      return UpdateSettingsNotifier();
    });

final updateProvider = Provider((ref) => UpdateService(ref));

class UpdateService {
  final Ref ref;
  UpdateService(this.ref);

  static const String _ignoreKey = 'ignored_update_version';

  Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoreKey, version);
  }

  Future<UpdateInfo?> checkForUpdates({bool isManual = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(
        'https://api.github.com/repos/Yuvi-GD/bolt_player/releases',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return null;

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) return null;

      final settingsValue = ref.read(updateSettingsProvider);
      final betaEnabled = settingsValue.value?.betaEnabled ?? false;

      dynamic latestRelease;

      if (betaEnabled) {
        // Take the very first release (can be beta/preview)
        latestRelease = releases.first;
      } else {
        // Filter out betas/previews
        latestRelease = releases.firstWhere(
          (r) =>
              !(r['prerelease'] as bool) &&
              !(r['tag_name'] as String).toLowerCase().contains('beta') &&
              !(r['tag_name'] as String).toLowerCase().contains('rc'),
          orElse: () => null,
        );
      }

      if (latestRelease == null) return null;

      final String remoteVersion = (latestRelease['tag_name'] as String)
          .replaceAll('v', '');

      // If we already ignored this version and it's not a manual check, skip
      if (!isManual) {
        final prefs = await SharedPreferences.getInstance();
        final ignored = prefs.getString(_ignoreKey);
        if (ignored == remoteVersion) return null;
      }

      if (_isVersionNewer(currentVersion, remoteVersion)) {
        return UpdateInfo(
          version: remoteVersion,
          url: latestRelease['html_url'],
          notes: latestRelease['body'] ?? 'No release notes provided.',
          isPatch: _isPatch(currentVersion, remoteVersion),
          isBeta: latestRelease['prerelease'] as bool,
        );
      }
    } catch (e) {
      print('Update check failed: $e');
    }
    return null;
  }

  bool _isVersionNewer(String current, String remote) {
    try {
      final currentParts = _getNumericParts(current);
      final remoteParts = _getNumericParts(remote);

      for (var i = 0; i < remoteParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }

      // If numeric parts are equal, check if one is beta and other is not
      // E.g. 1.1.0 vs 1.1.0-beta. Stable is newer than beta.
      // But if remote is beta and current is an older stable, it's still an update.
      // For now, if numeric version is same, we don't trigger "newer" for a beta suffix.
    } catch (_) {}
    return false;
  }

  bool _isPatch(String current, String remote) {
    try {
      final currentParts = _getNumericParts(current);
      final remoteParts = _getNumericParts(remote);

      if (remoteParts.length < 3 || currentParts.length < 3) return false;

      // Patch if Major and Minor are same, but Patch is higher
      return remoteParts[0] == currentParts[0] &&
          remoteParts[1] == currentParts[1] &&
          remoteParts[2] > currentParts[2];
    } catch (_) {}
    return false;
  }

  List<int> _getNumericParts(String version) {
    // Strip everything after - (like -beta or -rc)
    final baseVersion = version.split('-').first;
    // Remove any non-numeric characters except dots
    final cleanVersion = baseVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    return cleanVersion
        .split('.')
        .where((s) => s.isNotEmpty)
        .map(int.parse)
        .toList();
  }
}
