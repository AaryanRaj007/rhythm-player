import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/playlist_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioService _audioService = AudioService();
  final PlaylistService _playlistService = PlaylistService();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  int _currentNavIndex = 0;
  bool _showMiniPlayer = false;

  // Selection Mode
  bool _isSelectionMode = false;
  final Set<int> _selectedSongIds = {};

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _playlistService.load();
    _audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _showMiniPlayer = _audioService.currentSong != null && state.playing;
        });
      }
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      final excludePaths = [
        'recording', 'voice', 'ringtone', 'notification',
        'alarm', 'call', 'telegram', 'record',
      ];
      final filtered = songs.where((s) {
        final duration = s.duration ?? 0;
        if (duration < 50000) return false; // skip < 50 seconds
        final path = (s.data).toLowerCase();
        for (final ex in excludePaths) {
          if (path.contains(ex)) return false;
        }
        return true;
      }).toList();
      // Load persistent imported songs
      final prefs = await SharedPreferences.getInstance();
      final importedPaths = prefs.getStringList('imported_songs') ?? [];
      
      for (final iPath in importedPaths) {
        String title = iPath.split('/').last;
        if (title.contains('.')) {
          title = title.substring(0, title.lastIndexOf('.'));
        }
        
        final importedSong = SongModel({
          '_id': iPath.hashCode,
          'title': title,
          'artist': 'Imported',
          'album': 'Manual Library',
          '_data': iPath,
          'duration': 0, // We don't have metadata immediately
        });
        
        // Prevent duplicates
        if (!filtered.any((s) => s.data == iPath)) {
          filtered.add(importedSong);
        }
      }

      // Sort again after merging
      filtered.sort((a, b) => a.title.compareTo(b.title));

      if (mounted) {
        setState(() {
          _songs = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSongTap(SongModel song, int index) {
    if (_isSelectionMode) {
      _toggleSelection(song.id);
      return;
    }
    _audioService.playSong(song, songList: _songs, index: index);
    setState(() => _showMiniPlayer = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          song: song, songList: _songs, currentIndex: index,
        ),
      ),
    );
  }

  void _onSongLongPress(SongModel song) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedSongIds.add(song.id);
      });
      return;
    }
    // If already in selection mode, just toggle like a normal tap
    _toggleSelection(song.id);
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedSongIds.contains(id)) {
        _selectedSongIds.remove(id);
        if (_selectedSongIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedSongIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedSongs() async {
    final toDelete = _songs.where((s) => _selectedSongIds.contains(s.id)).toList();
    if (toDelete.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> importedPaths = prefs.getStringList('imported_songs') ?? [];

    int successCount = 0;
    for (final song in toDelete) {
      if (song.artist == 'Imported' && song.album == 'Manual Library') {
        // It's a manually imported file
        importedPaths.remove(song.data);
        successCount++;
      } else {
        // It's a device scanned file, attempt native deletion
        try {
          final file = File(song.data);
          if (file.existsSync()) {
            file.deleteSync();
            successCount++;
          }
        } catch (e) {
          debugPrint('Failed to delete native file: $e');
        }
      }
    }

    // Save updated imports
    await prefs.setStringList('imported_songs', importedPaths);

    // Refresh UI
    setState(() {
      _isSelectionMode = false;
      _selectedSongIds.clear();
    });
    
    _loadSongs(); // Reload the list
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $successCount song(s)', 
              style: AppTheme.labelText(color: Colors.white)),
          backgroundColor: AppTheme.bgElevated,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }



  void _showAddToPlaylistDialog(SongModel song) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? AppTheme.bgElevated : AppTheme.lightBgSurface;
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to Playlist',
                    style: AppTheme.screenTitle(color: textColor)),
                const SizedBox(height: 16),
                // Create new playlist
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreatePlaylistDialog(songToAdd: song);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: accent, size: 24),
                        const SizedBox(width: 12),
                        Text('Create New Playlist',
                            style: AppTheme.songTitle(color: accent)),
                      ],
                    ),
                  ),
                ),
                // Existing playlists
                if (_playlistService.playlists.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...List.generate(_playlistService.playlists.length, (i) {
                    final pl = _playlistService.playlists[i];
                    final alreadyIn = pl.songIds.contains(song.id);
                    return InkWell(
                      onTap: alreadyIn
                          ? null
                          : () {
                              _playlistService.addSongToPlaylist(i, song.id);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Added to "${pl.name}"',
                                      style: AppTheme.labelText(
                                          color: Colors.white)),
                                  backgroundColor: AppTheme.bgElevated,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              setState(() {});
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.queue_music_rounded,
                                color: subColor, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(pl.name,
                                  style: AppTheme.songTitle(color: textColor)),
                            ),
                            Text('${pl.songIds.length} songs',
                                style: AppTheme.smallText(color: subColor)),
                            if (alreadyIn) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_rounded,
                                  color: accent, size: 18),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog({SongModel? songToAdd}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.bgElevated : AppTheme.lightBgSurface,
        title: Text('New Playlist',
            style: AppTheme.screenTitle(
                color: isDark ? Colors.white : AppTheme.lightTextPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTheme.songTitle(
              color: isDark ? Colors.white : AppTheme.lightTextPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: AppTheme.bodyText(
                color: isDark
                    ? AppTheme.textSecondary
                    : AppTheme.lightTextSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.labelText(
                    color: isDark
                        ? AppTheme.textSecondary
                        : AppTheme.lightTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _playlistService.createPlaylist(name);
                if (songToAdd != null) {
                  await _playlistService.addSongToPlaylist(
                      _playlistService.playlists.length - 1, songToAdd.id);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playlist "$name" created',
                          style: AppTheme.labelText(color: Colors.white)),
                      backgroundColor: AppTheme.bgElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: Text('Create',
                style: AppTheme.labelText(color: accent)),
          ),
        ],
      ),
    );
  }

  void _closeMiniPlayer() {
    _audioService.stop();
    setState(() => _showMiniPlayer = false);
  }

  void _openPlayer() {
    final song = _audioService.currentSong;
    if (song != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            song: song,
            songList: _audioService.queue,
            currentIndex: _audioService.currentIndex,
          ),
        ),
      );
    }
  }

  List<SongModel> get _filteredSongs {
    if (_searchQuery.isEmpty) return _songs;
    return _songs
        .where((s) =>
            s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (s.artist ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ─── HOME TAB ─────────────────────────────────
  Widget _buildSongList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final accent = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded, size: 56, color: subColor),
            const SizedBox(height: 16),
            Text('No songs found', style: AppTheme.bodyText(color: subColor)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Song count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${_songs.length} songs',
            style: AppTheme.smallText(color: subColor),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _songs.length,
            padding: EdgeInsets.only(bottom: _showMiniPlayer ? 140 : 80),
            itemBuilder: (context, index) {
              final song = _songs[index];
              return SongTile(
                song: song,
                onTap: () => _onSongTap(song, index),
                onLongPress: () => _onSongLongPress(song),
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedSongIds.contains(song.id),
                onToggleSelection: () => _toggleSelection(song.id),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── SEARCH TAB ───────────────────────────────
  Widget _buildSearchTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final surfaceColor = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;
    final results = _filteredSongs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            style: AppTheme.songTitle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Search songs or artists...',
              hintStyle: AppTheme.bodyText(color: subColor),
              prefixIcon: Icon(Icons.search_rounded, color: subColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: Icon(Icons.close_rounded, color: subColor, size: 20),
                    )
                  : null,
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        if (_searchQuery.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 48, color: subColor),
                  const SizedBox(height: 12),
                  Text('Search for songs or artists',
                      style: AppTheme.bodyText(color: subColor)),
                  const SizedBox(height: 4),
                  Text('${_songs.length} songs available',
                      style: AppTheme.smallText(color: subColor)),
                ],
              ),
            ),
          )
        else if (results.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: subColor),
                  const SizedBox(height: 12),
                  Text('No results found',
                      style: AppTheme.bodyText(color: subColor)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Text('${results.length} results',
                      style: AppTheme.smallText(color: subColor)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    padding: EdgeInsets.only(
                        bottom: _showMiniPlayer ? 140 : 80),
                    itemBuilder: (context, index) {
                      final song = results[index];
                      final originalIndex = _songs.indexOf(song);
                      return SongTile(
                        song: song,
                        onTap: () => _onSongTap(song, originalIndex),
                        onLongPress: () => _onSongLongPress(song),
                        isSelectionMode: _isSelectionMode,
                        isSelected: _selectedSongIds.contains(song.id),
                        onToggleSelection: () => _toggleSelection(song.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── PLAYLISTS TAB ────────────────────────────
  Widget _buildPlaylistsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final surfaceColor = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;
    final playlists = _playlistService.playlists;

    return ListView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: _showMiniPlayer ? 140 : 80,
      ),
      children: [
        // Create playlist button
        GestureDetector(
          onTap: () => _showCreatePlaylistDialog(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded, color: accent, size: 28),
                ),
                const SizedBox(width: 14),
                Text('Create Playlist',
                    style: AppTheme.songTitle(color: accent)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (playlists.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.queue_music_rounded, size: 48, color: subColor),
                const SizedBox(height: 12),
                Text('No playlists yet',
                    style: AppTheme.bodyText(color: subColor)),
                const SizedBox(height: 4),
                Text('Long-press a song to add it to a playlist',
                    style: AppTheme.smallText(color: subColor),
                    textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ...List.generate(playlists.length, (i) {
            final pl = playlists[i];
            return GestureDetector(
              onTap: () => _openPlaylistDetail(i),
              onLongPress: () => _showPlaylistOptions(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.queue_music_rounded,
                          color: accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pl.name,
                              style: AppTheme.songTitle(color: textColor),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${pl.songIds.length} ${pl.songIds.length == 1 ? 'song' : 'songs'}',
                            style: AppTheme.smallText(color: subColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: subColor, size: 22),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _openPlaylistDetail(int playlistIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final pl = _playlistService.playlists[playlistIndex];
    final playlistSongs =
        _songs.where((s) => pl.songIds.contains(s.id)).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: isDark ? AppTheme.bgPrimary : AppTheme.lightBgPrimary,
          body: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                            size: 22),
                      ),
                      const Spacer(),
                      Text(pl.name,
                          style: AppTheme.screenTitle(
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.lightTextPrimary)),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Song count
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${playlistSongs.length} songs',
                        style: AppTheme.smallText(
                            color: isDark
                                ? AppTheme.textSecondary
                                : AppTheme.lightTextSecondary),
                      ),
                      const Spacer(),
                      if (playlistSongs.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            if (playlistSongs.isNotEmpty) {
                              _audioService.playSong(
                                playlistSongs[0],
                                songList: playlistSongs,
                                index: 0,
                              );
                              setState(() => _showMiniPlayer = true);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    song: playlistSongs[0],
                                    songList: playlistSongs,
                                    currentIndex: 0,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.play_arrow_rounded,
                              color: accent, size: 20),
                          label: Text('Play All',
                              style: AppTheme.labelText(color: accent)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: playlistSongs.isEmpty
                      ? Center(
                          child: Text('No songs in this playlist',
                              style: AppTheme.bodyText(
                                  color: isDark
                                      ? AppTheme.textSecondary
                                      : AppTheme.lightTextSecondary)),
                        )
                      : ListView.builder(
                          itemCount: playlistSongs.length,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemBuilder: (context, index) {
                            final song = playlistSongs[index];
                            return SongTile(
                              song: song,
                              onTap: () {
                                _audioService.playSong(
                                  song,
                                  songList: playlistSongs,
                                  index: index,
                                );
                                setState(() => _showMiniPlayer = true);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      song: song,
                                      songList: playlistSongs,
                                      currentIndex: index,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () {
                                _onSongLongPress(song);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaylistOptions(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final pl = _playlistService.playlists[index];
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(pl.name,
                  style: AppTheme.screenTitle(color: textColor)),
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: accent),
              title: Text('Rename',
                  style: AppTheme.songTitle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenamePlaylistDialog(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: Text('Delete',
                  style: AppTheme.songTitle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                await _playlistService.deletePlaylist(index);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenamePlaylistDialog(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final pl = _playlistService.playlists[index];
    final controller = TextEditingController(text: pl.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.bgElevated : AppTheme.lightBgSurface,
        title: Text('Rename Playlist',
            style: AppTheme.screenTitle(
                color: isDark ? Colors.white : AppTheme.lightTextPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTheme.songTitle(
              color: isDark ? Colors.white : AppTheme.lightTextPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: AppTheme.bodyText(
                color: isDark
                    ? AppTheme.textSecondary
                    : AppTheme.lightTextSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.labelText(
                    color: isDark
                        ? AppTheme.textSecondary
                        : AppTheme.lightTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _playlistService.renamePlaylist(index, name);
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              }
            },
            child: Text('Rename',
                style: AppTheme.labelText(color: accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final navBg = isDark ? AppTheme.bgSurface : AppTheme.lightBgSurface;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text('Rhythm',
                          style: AppTheme.heroText(color: textColor)),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SettingsScreen(
                                      onRefresh: _loadSongs,
                                    )),
                          );
                        },
                        icon: Icon(Icons.settings_rounded,
                            color: textColor, size: 24),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentNavIndex,
                    children: [
                      _buildSongList(),
                      _buildSearchTab(),
                      _buildPlaylistsTab(),
                    ],
                  ),
                ),
              ],
            ),
            if (_showMiniPlayer)
              Positioned(
                left: 0, right: 0, bottom: 70,
                child: MiniPlayer(
                  onTap: _openPlayer,
                  onClose: _closeMiniPlayer,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton(
              onPressed: () {
                if (_selectedSongIds.isNotEmpty) {
                  _deleteSelectedSongs();
                } else {
                  setState(() => _isSelectionMode = false);
                }
              },
              backgroundColor: const Color(0xFFEF4444), // iOS Red
              child: Icon(
                _selectedSongIds.isEmpty ? Icons.close_rounded : Icons.delete_rounded,
                color: Colors.white,
              ),
            )
          : null,
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(color: navBg),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (i) => setState(() {
            _currentNavIndex = i;
            if (i != 1) {
              _searchQuery = '';
              _searchController.clear();
            }
          }),
          backgroundColor: navBg,
          selectedItemColor: accent,
          unselectedItemColor: subColor,
          selectedLabelStyle: AppTheme.smallText(color: accent)
              .copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTheme.smallText(color: subColor),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'SEARCH',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music_rounded),
              label: 'PLAYLISTS',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
