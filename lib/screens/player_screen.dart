import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import 'equalizer_screen.dart';

class PlayerScreen extends StatefulWidget {
  final SongModel song;
  final List<SongModel> songList;
  final int currentIndex;

  const PlayerScreen({
    super.key,
    required this.song,
    required this.songList,
    required this.currentIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioService _audioService = AudioService();
  late SongModel _currentSong;
  late int _currentIndex;
  bool _shuffle = false;
  int _repeatMode = 0; // 0=off, 1=all, 2=one

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
    _currentIndex = widget.currentIndex;
    _shuffle = _audioService.shuffle;
    _repeatMode = _audioService.loopMode == LoopMode.off
        ? 0
        : _audioService.loopMode == LoopMode.all
            ? 1
            : 2;

    // Listen for state changes
    _audioService.sequenceStateStream.listen((sequenceState) {
      if (!mounted) return;
      if (_audioService.currentSong != null &&
          _audioService.currentSong!.id != _currentSong.id) {
        setState(() {
          _currentSong = _audioService.currentSong!;
          _currentIndex = _audioService.currentIndex;
        });
      }
    });

    // We no longer need this as just_audio ConcatenatingAudioSource handles auto-advance
    // _audioService.playerStateStream.listen((state) { ... });
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleShuffle() {
    _audioService.toggleShuffle();
    setState(() => _shuffle = _audioService.shuffle);
  }

  void _cycleRepeat() {
    _audioService.cycleLoopMode();
    setState(() {
      _repeatMode = _audioService.loopMode == LoopMode.off
          ? 0
          : _audioService.loopMode == LoopMode.all
              ? 1
              : 2;
    });
  }

  void _showUpNextSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.bgElevated : AppTheme.lightBgSurface;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Up Next',
                  style: AppTheme.screenTitle(color: textColor)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: min(widget.songList.length - _currentIndex - 1, 10),
                itemBuilder: (_, i) {
                  // Make sure we don't go out of bounds if the queue changes
                  if (_currentIndex + 1 + i >= _audioService.queue.length) return const SizedBox();
                  final song = _audioService.queue[_currentIndex + 1 + i];
                  return ListTile(
                    title: Text(song.title,
                        style: AppTheme.songTitle(color: textColor),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(song.artist ?? 'Unknown',
                        style: AppTheme.artistName(color: subColor)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final elevatedColor = isDark ? AppTheme.bgElevated : AppTheme.lightBgElevated;
    final surfaceColor = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = screenWidth - 60;

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
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: elevatedColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textColor,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'NOW PLAYING',
                    style: AppTheme.smallText(color: subColor).copyWith(
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: elevatedColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.equalizer_rounded,
                        color: textColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Album Art — static, no rotation
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: artSize > 300 ? 300 : artSize,
                  height: artSize > 300 ? 300 : artSize,
                  child: QueryArtworkWidget(
                    id: _currentSong.id,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    artworkBorder: BorderRadius.circular(24),
                    artworkWidth: artSize > 300 ? 300 : artSize.toInt().toDouble(),
                    artworkHeight: artSize > 300 ? 300 : artSize.toInt().toDouble(),
                    nullArtworkWidget: Container(
                      width: artSize > 300 ? 300 : artSize,
                      height: artSize > 300 ? 300 : artSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: elevatedColor,
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 80,
                        color: subColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Song Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Song title
                  SizedBox(
                    height: 32,
                    child: _currentSong.title.length > 25
                        ? Marquee(
                            text: _currentSong.title,
                            style: AppTheme.screenTitle(color: textColor),
                            scrollAxis: Axis.horizontal,
                            blankSpace: 60,
                            velocity: 30,
                            pauseAfterRound: const Duration(seconds: 2),
                          )
                        : Text(
                            _currentSong.title,
                            style: AppTheme.screenTitle(color: textColor),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentSong.artist ?? 'Unknown Artist',
                    style: AppTheme.bodyText(
                        color: subColor, size: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Seek Bar
            StreamBuilder<Duration?>(
              stream: _audioService.positionStream,
              builder: (context, posSnapshot) {
                return StreamBuilder<Duration?>(
                  stream: _audioService.durationStream,
                  builder: (context, durSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final duration =
                        durSnapshot.data ?? const Duration(seconds: 1);
                    final maxVal = duration.inMilliseconds.toDouble();
                    final curVal = position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, maxVal);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              activeTrackColor: accent,
                              inactiveTrackColor: elevatedColor,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: curVal,
                              max: maxVal,
                              onChanged: (val) {
                                _audioService.seekTo(
                                    Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position),
                                    style: AppTheme.smallText(color: subColor)),
                                Text(_formatDuration(duration),
                                    style: AppTheme.smallText(color: subColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Playback Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Previous
                  IconButton(
                    onPressed: () async {
                      await _audioService.skipToPrevious();
                      setState(() {
                        _currentSong = _audioService.currentSong ?? _currentSong;
                        _currentIndex = _audioService.currentIndex;
                      });
                    },
                    icon: Icon(Icons.skip_previous_rounded,
                        size: 32, color: textColor),
                  ),
                  // -5 seconds
                  IconButton(
                    onPressed: () => _audioService.skipBackward(5),
                    icon: Icon(Icons.replay_5_rounded,
                        size: 28, color: subColor),
                  ),
                  // Play/Pause
                  StreamBuilder<PlayerState>(
                    stream: _audioService.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return GestureDetector(
                        onTap: () => _audioService.togglePlayPause(),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(playing),
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // +5 seconds
                  IconButton(
                    onPressed: () => _audioService.skipForward(5),
                    icon: Icon(Icons.forward_5_rounded,
                        size: 28, color: subColor),
                  ),
                  // Next
                  IconButton(
                    onPressed: () async {
                      await _audioService.skipToNext();
                      setState(() {
                        _currentSong = _audioService.currentSong ?? _currentSong;
                        _currentIndex = _audioService.currentIndex;
                      });
                    },
                    icon: Icon(Icons.skip_next_rounded,
                        size: 32, color: textColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shuffle
                  IconButton(
                    onPressed: _toggleShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: _shuffle ? accent : subColor,
                      size: 24,
                    ),
                  ),
                  // Up Next pill
                  GestureDetector(
                    onTap: _showUpNextSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded,
                              size: 16, color: subColor),
                          const SizedBox(width: 6),
                          Text(
                            'UP NEXT',
                            style: AppTheme.smallText(color: subColor).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Repeat
                  IconButton(
                    onPressed: _cycleRepeat,
                    icon: Icon(
                      _repeatMode == 2
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color:
                          _repeatMode > 0 ? accent : subColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
