import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const List<String> _bandLabels = [
    '60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz',
  ];

  static const List<String> _presets = [
    'Flat', 'Bass Boost', 'Treble Boost', 'Rock', 'Pop', 'Jazz', 'Classical', 'Custom',
  ];

  static const Map<String, List<double>> _presetValues = {
    'Flat': [0, 0, 0, 0, 0],
    'Bass Boost': [5, 3, 0, 0, 0],
    'Treble Boost': [0, 0, 0, 3, 5],
    'Rock': [4, 2, -1, 3, 4],
    'Pop': [1, 3, 4, 2, -1],
    'Jazz': [3, 1, -1, 1, 3],
    'Classical': [-1, 0, 0, 2, 4],
  };

  final AudioService _audioService = AudioService();
  List<double> _bandValues = [0, 0, 0, 0, 0];
  final List<double> _customBandValues = [0, 0, 0, 0, 0]; // Store user's bespoke settings
  
  double _bassBoost = 0;
  double _customBassBoost = 0; // Store user's bespoke bass
  
  String _selectedPreset = 'Flat';
  bool _enabled = true;

  // Real EQ parameters from the device
  AndroidEqualizerParameters? _eqParams;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    // Enable the equalizer
    await _audioService.equalizer.setEnabled(_enabled);
    // Get the real parameters once the EQ is initialized
    try {
      final params = await _audioService.equalizer.parameters;
      setState(() => _eqParams = params);
    } catch (e) {
      debugPrint('Could not get EQ params: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPreset = prefs.getString('eq_preset') ?? 'Flat';
      _bassBoost = prefs.getDouble('eq_bass_boost') ?? 0;
      _customBassBoost = prefs.getDouble('eq_custom_bass_boost') ?? 0;
      _enabled = prefs.getBool('eq_enabled') ?? true;
      for (int i = 0; i < 5; i++) {
        _bandValues[i] = prefs.getDouble('eq_band_$i') ?? 0;
        _customBandValues[i] = prefs.getDouble('eq_custom_band_$i') ?? 0;
      }
    });
    // Apply saved settings to the real EQ
    _applyToRealEQ();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eq_preset', _selectedPreset);
    await prefs.setDouble('eq_bass_boost', _bassBoost);
    await prefs.setDouble('eq_custom_bass_boost', _customBassBoost);
    await prefs.setBool('eq_enabled', _enabled);
    for (int i = 0; i < 5; i++) {
      await prefs.setDouble('eq_band_$i', _bandValues[i]);
      await prefs.setDouble('eq_custom_band_$i', _customBandValues[i]);
    }
  }

  /// Apply current band values and bass boost to the real Android EQ
  Future<void> _applyToRealEQ() async {
    try {
      await _audioService.equalizer.setEnabled(_enabled);

      if (_enabled && _eqParams != null) {
        final bands = _eqParams!.bands;
        for (int i = 0; i < bands.length && i < _bandValues.length; i++) {
          // Map our -6..+6 range to the device's min..max range
          final minLevel = _eqParams!.minDecibels;
          final maxLevel = _eqParams!.maxDecibels;
          final range = maxLevel - minLevel;
          // Our range is -6 to +6 (total 12), map proportionally
          final gain = minLevel + ((_bandValues[i] + 6) / 12) * range;
          bands[i].setGain(gain);
        }
      }

      // Apply bass boost via loudness enhancer (0-100% mapped to 0-1000 mB)
      final targetGain = _enabled ? (_bassBoost / 100.0 * 1000.0) : 0.0;
      await _audioService.loudnessEnhancer.setTargetGain(targetGain);
    } catch (e) {
      debugPrint('Error applying EQ: $e');
    }
  }

  void _applyPreset(String preset) {
    if (preset == 'Custom') {
      setState(() {
        _selectedPreset = 'Custom';
        _bandValues = List.from(_customBandValues);
        _bassBoost = _customBassBoost;
      });
      _applyToRealEQ();
      _saveSettings();
      return;
    }
    final values = _presetValues[preset];
    if (values != null) {
      setState(() {
        _selectedPreset = preset;
        _bandValues = List.from(values);
      });
      _applyToRealEQ();
      _saveSettings();
    }
  }

  void _resetAll() {
    setState(() {
      _selectedPreset = 'Flat';
      _bandValues = [0, 0, 0, 0, 0];
      _bassBoost = 0;
    });
    _applyToRealEQ();
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final surfaceColor = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;

    return Scaffold(
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
                  Text('Equalizer',
                      style: AppTheme.screenTitle(color: textColor)),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetAll,
                    child: Text('Reset',
                        style: AppTheme.labelText(color: accent)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),

                  // On/Off toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.equalizer_rounded,
                            color: _enabled ? accent : subColor, size: 24),
                        const SizedBox(width: 12),
                        Text('Equalizer',
                            style: AppTheme.bodyText(
                                color: textColor, size: 16)),
                        const Spacer(),
                        Switch(
                          value: _enabled,
                          onChanged: (v) {
                            setState(() => _enabled = v);
                            _applyToRealEQ();
                            _saveSettings();
                          },
                          activeThumbColor: accent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Preset selector
                  Text('PRESET', style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presets.map((preset) {
                        final isSelected = _selectedPreset == preset;
                        return GestureDetector(
                          onTap: _enabled
                              ? () => _applyPreset(preset)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : (isDark
                                      ? AppTheme.bgElevated
                                      : AppTheme.lightBgElevated),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              preset,
                              style: AppTheme.labelText(
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : textColor,
                              ).copyWith(fontSize: 13),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // EQ Bands
                  Text('BANDS', style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (i) {
                        return _buildBandSlider(
                            i, accent, textColor, subColor);
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bass Boost
                  Text('BASS BOOST', style: AppTheme.sectionLabel(accent)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.speaker_rounded,
                                    color: subColor, size: 20),
                                const SizedBox(width: 10),
                                Text('Level',
                                    style: AppTheme.bodyText(
                                        color: textColor, size: 15)),
                              ],
                            ),
                            Text(
                              _bassBoost == 0
                                  ? 'Off'
                                  : '${_bassBoost.toStringAsFixed(0)}%',
                              style: AppTheme.bodyText(
                                  color: accent, size: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                            activeTrackColor:
                                _enabled ? accent : subColor,
                            inactiveTrackColor: isDark
                                ? AppTheme.bgElevated
                                : AppTheme.lightBgElevated,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _bassBoost,
                            min: 0,
                            max: 100,
                            onChanged: _enabled
                                ? (val) {
                                    setState(() {
                                      _bassBoost = val;
                                      _customBassBoost = val;
                                      _selectedPreset = 'Custom';
                                    });
                                    _applyToRealEQ();
                                    _saveSettings();
                                  }
                                : null,
                          ),
                        ),
                      ],
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

  Widget _buildBandSlider(
      int index, Color accent, Color textColor, Color subColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          _bandValues[index] > 0
              ? '+${_bandValues[index].toStringAsFixed(0)}'
              : _bandValues[index].toStringAsFixed(0),
          style: AppTheme.smallText(color: _enabled ? accent : subColor),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 160,
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7),
                activeTrackColor: _enabled ? accent : subColor,
                inactiveTrackColor: isDark
                    ? AppTheme.bgElevated
                    : AppTheme.lightBgElevated,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _bandValues[index],
                min: -6,
                max: 6,
                onChanged: _enabled
                    ? (val) {
                        setState(() {
                          _bandValues[index] = val.roundToDouble();
                          _customBandValues[index] = _bandValues[index];
                          _selectedPreset = 'Custom';
                        });
                        _applyToRealEQ();
                        _saveSettings();
                      }
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(_bandLabels[index], style: AppTheme.smallText(color: subColor)),
      ],
    );
  }
}
