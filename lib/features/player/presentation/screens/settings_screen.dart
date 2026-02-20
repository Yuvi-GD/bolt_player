import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/player_state_provider.dart';
import '../../providers/update_provider.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
            // Title Header with Internal Back Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final notifier = ref.read(playerStateProvider.notifier);
                      notifier.back();
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            // Settings Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                children: [
                  // --- GENERAL / CONTROLS SECTION ---
                  _buildSectionHeader('GENERAL'),

                  _buildNavTile(
                    context,
                    ref: ref,
                    icon: Icons.keyboard_command_key_rounded,
                    title: 'Controls & Shortcuts',
                    subtitle: 'View mouse gestures and keyboard mappings',
                    onTap: () {
                      ref
                          .read(playerStateProvider.notifier)
                          .setView(PlayerView.shortcuts);
                    },
                  ),

                  const SizedBox(height: 32),

                  // --- APPEARANCE SECTION ---
                  _buildSectionHeader('APPEARANCE'),
                  _buildSettingTile(
                    icon: Icons.color_lens_rounded,
                    title: 'Neon Theme Color',
                    subtitle: 'Current: Cyan (Default)',
                    onTap: () {
                      _showCustomNotification(
                        context,
                        'THEME SELECTION NEXT UPDATE',
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // --- SYSTEM SECTION ---
                  _buildSectionHeader('SYSTEM'),
                  _buildSettingTile(
                    icon: Icons.cleaning_services_rounded,
                    title: 'Playback Cache',
                    subtitle: 'Manage temporary files',
                    onTap: () {},
                    trailing: TextButton(
                      onPressed: () {
                        _showCustomNotification(
                          context,
                          'CACHE CLEARED',
                          color: Colors.redAccent,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                      ),
                      child: const Text(
                        'Clear Cache',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- UPDATES SECTION ---
                  _buildSectionHeader('UPDATES'),

                  // 1. Manual Check Button (First now)
                  FutureBuilder<String>(
                    future: PackageInfo.fromPlatform().then((p) => p.version),
                    builder: (context, snapshot) {
                      final version = snapshot.data ?? '1.0.0';
                      return _buildSettingTile(
                        icon: Icons.update_rounded,
                        title: 'Check for Updates',
                        subtitle: 'Current Version: v$version',
                        onTap: () {},
                        trailing: TextButton(
                          onPressed: () async {
                            _showCustomNotification(
                              context,
                              'CHECKING FOR UPDATES...',
                            );

                            // Add a small artificial delay so the user can see the "Checking" state
                            await Future.delayed(
                              const Duration(milliseconds: 1500),
                            );

                            final info = await ref
                                .read(updateProvider)
                                .checkForUpdates(isManual: true);

                            if (context.mounted) {
                              if (info != null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => UpdateDialog(
                                    info: info,
                                    onLater: () => ref
                                        .read(updateProvider)
                                        .ignoreVersion(info.version),
                                    onDontShowAgain: () => ref
                                        .read(updateSettingsProvider.notifier)
                                        .setStartupCheckEnabled(false),
                                  ),
                                );
                              } else {
                                _showCustomNotification(
                                  context,
                                  'UP TO DATE',
                                  color: Colors.greenAccent,
                                );
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF00E5FF,
                            ).withOpacity(0.1),
                            foregroundColor: const Color(0xFF00E5FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: const Color(0xFF00E5FF).withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Check Now',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),

                  // 2. Startup Check Toggle
                  Consumer(
                    builder: (context, ref, child) {
                      final settingsValue = ref.watch(updateSettingsProvider);
                      final settings =
                          settingsValue.value ??
                          UpdateSettings(
                            betaEnabled: false,
                            startupCheckEnabled: true,
                          );
                      return _buildSettingTile(
                        icon: Icons.rocket_launch_rounded,
                        title: 'Check Updates on Startup',
                        subtitle: 'Automatically check for fixes when opening',
                        onTap: () => ref
                            .read(updateSettingsProvider.notifier)
                            .setStartupCheckEnabled(
                              !settings.startupCheckEnabled,
                            ),
                        trailing: Switch(
                          value: settings.startupCheckEnabled,
                          activeColor: const Color(0xFF00E5FF),
                          onChanged: (val) => ref
                              .read(updateSettingsProvider.notifier)
                              .setStartupCheckEnabled(val),
                        ),
                      );
                    },
                  ),

                  // 3. Beta Channel Toggle
                  Consumer(
                    builder: (context, ref, child) {
                      final settingsValue = ref.watch(updateSettingsProvider);
                      final settings =
                          settingsValue.value ??
                          UpdateSettings(
                            betaEnabled: false,
                            startupCheckEnabled: true,
                          );
                      return _buildSettingTile(
                        icon: Icons.bug_report_rounded,
                        title: 'Join Beta Channel',
                        subtitle: 'Get early access to experimental features',
                        onTap: () => ref
                            .read(updateSettingsProvider.notifier)
                            .setBetaEnabled(!settings.betaEnabled),
                        trailing: Switch(
                          value: settings.betaEnabled,
                          activeColor: const Color(
                            0xFFBC13FE,
                          ), // Neon Purple for Beta
                          onChanged: (val) => ref
                              .read(updateSettingsProvider.notifier)
                              .setBetaEnabled(val),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF00E5FF).withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(icon, color: const Color(0xFF00E5FF), size: 28),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white24,
          size: 16,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withOpacity(0.08),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  void _showCustomNotification(
    BuildContext context,
    String message, {
    Color color = const Color(0xFF00E5FF),
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value.clamp(0.0, 2.0),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: color.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
