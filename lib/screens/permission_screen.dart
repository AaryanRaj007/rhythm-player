import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _showDeniedMessage = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPermission();
  }

  Future<void> _checkExistingPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      PermissionStatus status;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.audio.status;
      } else {
        status = await Permission.storage.status;
      }
      if (status.isGranted && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      PermissionStatus status;

      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.audio.request();
      } else {
        status = await Permission.storage.request();
      }

      if (!mounted) return;

      if (status.isGranted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (status.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.bgElevated
                : AppTheme.lightBgSurface,
            title: Text('Permission Required',
                style: AppTheme.songTitle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.lightTextPrimary)),
            content: Text(
              'Please enable storage access in your device settings.',
              style: AppTheme.bodyText(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.textSecondary
                      : AppTheme.lightTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: AppTheme.labelText(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textSecondary
                            : AppTheme.lightTextSecondary)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: Text('Open Settings',
                    style: AppTheme.labelText(
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enable storage access in Settings',
              style: AppTheme.labelText(color: Colors.white),
            ),
            backgroundColor: AppTheme.bgElevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.bgPrimary : AppTheme.lightBgPrimary;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final surfaceColor = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Top bar with app name
              Text('Rhythm', style: AppTheme.heroText(color: textColor)),

              const Spacer(),

              // Main content
              if (_showDeniedMessage) ...[
                // Denied state
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.folder_off_rounded, size: 56, color: subColor),
                      const SizedBox(height: 20),
                      Text(
                        "We can't find any songs",
                        style: AppTheme.screenTitle(color: textColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rhythm needs access to your music library to play songs. Please allow access to continue.',
                        style: AppTheme.bodyText(color: subColor, size: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _requestPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Allow Access',
                            style: AppTheme.labelText(color: Colors.white)
                                .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Welcome state
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.headphones_rounded,
                    size: 52,
                    color: accent,
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Welcome to Rhythm',
                  style: AppTheme.heroText(color: textColor),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: 280,
                  child: Text(
                    'Your personal music player.\nAllow access to discover and play your songs.',
                    style: AppTheme.bodyText(color: subColor, size: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(),

              if (!_showDeniedMessage) ...[
                // Allow Access button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(
                      'Allow Access',
                      style: AppTheme.labelText(color: Colors.white)
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Maybe later → shows "can't find songs" message
                GestureDetector(
                  onTap: () {
                    setState(() => _showDeniedMessage = true);
                  },
                  child: Text(
                    'Maybe later',
                    style: AppTheme.bodyText(color: subColor, size: 14),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
