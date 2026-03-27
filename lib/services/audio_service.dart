import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  // Android audio effects
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();

  late final AudioPlayer _player;

  AudioService._internal() {
    // Create player with audio pipeline that includes EQ + bass boost
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer, _loudnessEnhancer],
      ),
    );

    // Listen to changes in the current index (when song finishes or user uses notification skip buttons)
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        _currentSong = _queue[index];
      }
    });
  }

  // Expose EQ and loudness enhancer for the UI
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  // Currently playing song info
  SongModel? _currentSong;
  List<SongModel> _queue = [];
  int _currentIndex = -1;

  SongModel? get currentSong => _currentSong;
  List<SongModel> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get shuffle => _player.shuffleModeEnabled;
  LoopMode get loopMode => _player.loopMode;
  bool get playing => _player.playing;

  // Current state streams
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  /// Build a ConcatenatingAudioSource from a list of SongModels
  ConcatenatingAudioSource _buildPlaylist(List<SongModel> songs) {
    return ConcatenatingAudioSource(
      children: songs.map((song) {
        return AudioSource.uri(
          Uri.parse(song.data),
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? 'Unknown Album',
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
          ),
        );
      }).toList(),
    );
  }

  // Play a song by file path, optionally loading an entire playlist for notification controls
  Future<void> playSong(SongModel song, {List<SongModel>? songList, int? index}) async {
    try {
      // If a songList is provided, we load the whole list as a ConcatenatingAudioSource
      // This is crucial for Android to show Next/Previous buttons in the notification
      if (songList != null && songList.isNotEmpty && index != null) {
        // Only rebuild and set the queue if it's a completely new list, to avoid interrupting playback if they just tapped another song in the SAME queue
        bool isNewQueue = _queue.isEmpty || _queue.length != songList.length || _queue.first.id != songList.first.id;
        
        if (isNewQueue || _player.audioSource == null) {
          _queue = songList;
          final playlist = _buildPlaylist(_queue);
          // Set the playlist and start at the requested index
          await _player.setAudioSource(playlist, initialIndex: index, initialPosition: Duration.zero);
        } else {
          // It's the same queue, just seek to that index
          await _player.seek(Duration.zero, index: index);
        }
      } else {
        // Fallback for standalone playback (e.g. manual file picker where there's no queue)
        _queue = [song];
        _currentIndex = 0;
        final source = _buildPlaylist(_queue);
        await _player.setAudioSource(source, initialIndex: 0);
      }
      
      await _player.play();
    } catch (e) {
      debugPrint('Error playing song: $e');
    }
  }

  // Controls
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();
  Future<void> stop() async {
    await _player.stop();
    _currentSong = null;
    _currentIndex = -1;
  }

  Future<void> seekTo(Duration position) => _player.seek(position);

  Future<void> skipForward(int seconds) => _player.seek(
        _player.position + Duration(seconds: seconds),
      );

  Future<void> skipBackward(int seconds) {
    final newPos = _player.position - Duration(seconds: seconds);
    return _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  // Use just_audio's native queue navigation
  Future<void> skipToNext() async => _player.seekToNext();
  Future<void> skipToPrevious() async => _player.seekToPrevious();

  void toggleShuffle() async {
    final enabled = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(enabled);
  }

  void cycleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await _player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await _player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  void dispose() => _player.dispose();
}
