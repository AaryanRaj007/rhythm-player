import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showDuration;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.showDuration = true,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
  });

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final elevatedColor = isDark ? AppTheme.bgElevated : AppTheme.lightBgElevated;

    return InkWell(
      onTap: isSelectionMode ? onToggleSelection : onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: elevatedColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Animated Checkbox for Selection Mode
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isSelectionMode ? 32 : 0,
              margin: EdgeInsets.only(right: isSelectionMode ? 12 : 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: GestureDetector(
                  onTap: onToggleSelection,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? accent : subColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: isSelected 
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                  ),
                ),
              ),
            ),
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.circular(10),
                  nullArtworkWidget: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: elevatedColor,
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: subColor,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Song title + artist
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: AppTheme.songTitle(color: textColor)
                        .copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist ?? 'Unknown Artist',
                    style: AppTheme.artistName(color: subColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Duration
            if (showDuration)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _formatDuration(song.duration ?? 0),
                  style: AppTheme.smallText(color: subColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
