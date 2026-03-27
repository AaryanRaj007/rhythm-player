import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onClose;

  const MiniPlayer({
    super.key,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final audioService = AudioService();
    final accent = Theme.of(context).colorScheme.primary;
    final song = audioService.currentSong;

    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Play/Pause
            StreamBuilder<just_audio.PlayerState>(
              stream: audioService.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return GestureDetector(
                  onTap: () => audioService.togglePlayPause(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppTheme.bgPrimary,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: StreamBuilder<just_audio.SequenceState?>(
                stream: audioService.sequenceStateStream,
                builder: (context, snapshot) {
                  final current = audioService.currentSong;
                  if (current == null) return const SizedBox();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.title,
                        style: AppTheme.labelText(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        current.artist ?? 'Unknown Artist',
                        style: AppTheme.smallText(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
            // Skip next
            IconButton(
              onPressed: () => audioService.skipToNext(),
              icon: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Close
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
