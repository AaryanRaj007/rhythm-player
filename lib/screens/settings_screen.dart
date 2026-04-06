import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/color_swatch.dart' as cs;
import 'equalizer_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onRefresh;

  const SettingsScreen({super.key, this.onRefresh});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _skipDuration = '5 seconds';
  bool _crossfade = false;
  bool _gapless = true;
  bool _showDuration = true;
  String _audioQuality = 'High';
  String _sleepTimer = 'Off';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _skipDuration = prefs.getString('skipDuration') ?? '5 seconds';
      _crossfade = prefs.getBool('crossfade') ?? false;
      _gapless = prefs.getBool('gapless') ?? true;
      _showDuration = prefs.getBool('showDuration') ?? true;
      _audioQuality = prefs.getString('audioQuality') ?? 'High';
      _sleepTimer = prefs.getString('sleepTimer') ?? 'Off';
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _pickAndSaveFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true, // Let them pick multiple!
      );

      if (result != null && result.paths.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        List<String> existing = prefs.getStringList('imported_songs') ?? [];
        
        int added = 0;
        for (final path in result.paths) {
          if (path != null && !existing.contains(path)) {
            existing.add(path);
            added++;
          }
        }
        
        if (added > 0) {
          await prefs.setStringList('imported_songs', existing);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully imported $added song(s)!',
                    style: AppTheme.labelText(color: Colors.white)),
                backgroundColor: AppTheme.bgElevated,
                duration: const Duration(seconds: 3),
              ),
            );
            // Refresh home screen list
            widget.onRefresh?.call();
          }
        }
      }
    } catch (e) {
      debugPrint("File picking failed: $e");
    }
  }

  void _showOptionSheet(String title, List<String> options,
      String current, Function(String) onSelect) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final sheetBg = isDark ? AppTheme.bgElevated : AppTheme.lightBgSurface;
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title,
                  style: AppTheme.screenTitle(color: textColor)),
            ),
            ...options.map((option) => ListTile(
                  title: Text(option,
                      style: AppTheme.songTitle(
                          color: option == current ? accent : textColor)),
                  trailing: option == current
                      ? Icon(Icons.check_rounded, color: accent)
                      : null,
                  onTap: () {
                    onSelect(option);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String label,
    String? description,
    String? trailing,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: subColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTheme.bodyText(color: textColor, size: 16)),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(description,
                        style: AppTheme.smallText(color: subColor)
                            .copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
            if (trailing != null && trailing.isNotEmpty) ...[
              Text(trailing,
                  style: AppTheme.bodyText(color: subColor, size: 14)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
            ] else if (trailing != null && trailing.isEmpty && onTap != null) ...[
              Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? AppTheme.bgElevated : AppTheme.lightBgElevated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final surfaceColor = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimary : AppTheme.lightBgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textColor, size: 22),
                  ),
                  const Spacer(),
                  Text('Settings',
                      style: AppTheme.screenTitle(color: textColor)),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 16),

                  // ─── LOOK & FEEL ──────────────────────
                  Text('LOOK & FEEL',
                      style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ] : null,
                    ),
                    child: Column(
                      children: [
                        // Theme Color
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.palette_rounded,
                                  color: isDark
                                      ? AppTheme.textSecondary
                                      : AppTheme.lightTextSecondary,
                                  size: 22),
                              const SizedBox(width: 14),
                              Text('Color',
                                  style: AppTheme.bodyText(
                                      color: textColor, size: 16)),
                              const Spacer(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  AppTheme.accentColors.length,
                                  (i) => cs.ColorSwatch(
                                    color: AppTheme.accentColors[i],
                                    isSelected: themeProvider.accentColor ==
                                        AppTheme.accentColors[i],
                                    onTap: () => themeProvider
                                        .setTheme(AppTheme.accentColors[i]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _divider(),
                        // Dark Mode toggle
                        _settingRow(
                          icon: Icons.dark_mode_rounded,
                          label: 'Dark Mode',
                          description: 'Switch between dark and light theme',
                          trailingWidget: Switch(
                            value: themeProvider.isDark,
                            onChanged: (v) => themeProvider.toggleDarkMode(v),
                            activeThumbColor: accent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── PLAYBACK ─────────────────────────
                  Text('PLAYBACK',
                      style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ] : null,
                    ),
                    child: Column(
                      children: [
                        _settingRow(
                          icon: Icons.skip_next_rounded,
                          label: 'Skip Duration',
                          description: 'How far to skip forward/back',
                          trailing: _skipDuration,
                          onTap: () => _showOptionSheet(
                            'Skip Duration',
                            ['5 seconds', '10 seconds', '15 seconds', '30 seconds'],
                            _skipDuration,
                            (val) {
                              setState(() => _skipDuration = val);
                              _savePreference('skipDuration', val);
                            },
                          ),
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.high_quality_rounded,
                          label: 'Audio Quality',
                          description: 'Playback quality level',
                          trailing: _audioQuality,
                          onTap: () => _showOptionSheet(
                            'Audio Quality',
                            ['Normal', 'High'],
                            _audioQuality,
                            (val) {
                              setState(() => _audioQuality = val);
                              _savePreference('audioQuality', val);
                            },
                          ),
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Crossfade',
                          description: 'Smooth transition between songs',
                          trailingWidget: Switch(
                            value: _crossfade,
                            onChanged: (v) {
                              setState(() => _crossfade = v);
                              _savePreference('crossfade', v);
                            },
                            activeThumbColor: accent,
                          ),
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.music_note_rounded,
                          label: 'Gapless',
                          description: 'No gap between songs',
                          trailingWidget: Switch(
                            value: _gapless,
                            onChanged: (v) {
                              setState(() => _gapless = v);
                              _savePreference('gapless', v);
                            },
                            activeThumbColor: accent,
                          ),
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.bedtime_rounded,
                          label: 'Sleep Timer',
                          description: 'Auto-stop after a set time',
                          trailing: _sleepTimer,
                          onTap: () => _showOptionSheet(
                            'Sleep Timer',
                            ['Off', '15 minutes', '30 minutes', '1 hour', '2 hours'],
                            _sleepTimer,
                            (val) {
                              setState(() => _sleepTimer = val);
                              _savePreference('sleepTimer', val);
                            },
                          ),
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.equalizer_rounded,
                          label: 'Equalizer',
                          description: 'Adjust bass, treble & presets',
                          trailing: '',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EqualizerScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── LIBRARY ──────────────────────────
                  Text('LIBRARY',
                      style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ] : null,
                    ),
                    child: Column(
                      children: [
                        // IMPORT AUDIO FILES BUTTON
                        InkWell(
                          onTap: _pickAndSaveFile,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent.withValues(alpha: 0.2), accent.withValues(alpha: 0.05)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.drive_folder_upload_rounded, color: accent, size: 28),
                                ),
                                const SizedBox(height: 12),
                                Text('Import Audio Files',
                                    style: AppTheme.bodyText(color: textColor, size: 16)
                                        .copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Add specific files permanently to your library',
                                    style: AppTheme.smallText(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
                              ],
                            ),
                          ),
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.refresh_rounded,
                          label: 'Scan for Songs',
                          description: 'Re-scan your device for music',
                          trailing: '',
                          onTap: () {
                            widget.onRefresh?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Library refreshed',
                                    style: AppTheme.labelText(
                                        color: Colors.white)),
                                backgroundColor: AppTheme.bgElevated,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        _divider(),
                        _settingRow(
                          icon: Icons.timer_outlined,
                          label: 'Show Duration',
                          description: 'Show song length in list',
                          trailingWidget: Switch(
                            value: _showDuration,
                            onChanged: (v) {
                              setState(() => _showDuration = v);
                              _savePreference('showDuration', v);
                            },
                            activeThumbColor: accent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── ABOUT ────────────────────────────
                  Text('ABOUT',
                      style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text('App Version',
                            style: AppTheme.bodyText(
                                color: textColor, size: 15)),
                        const Spacer(),
                        Text('1.0.0',
                            style: AppTheme.bodyText(
                                color: isDark
                                    ? AppTheme.textSecondary
                                    : AppTheme.lightTextSecondary,
                                size: 14)),
                      ],
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Made with ❤️ for music lovers',
                          style: AppTheme.artistName(
                              color: isDark
                                  ? AppTheme.textSecondary
                                  : AppTheme.lightTextSecondary)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
