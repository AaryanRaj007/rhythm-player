import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Playlist {
  String name;
  List<int> songIds;

  Playlist({required this.name, List<int>? songIds})
      : songIds = songIds ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'songIds': songIds,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        name: json['name'] as String,
        songIds: (json['songIds'] as List).map((e) => e as int).toList(),
      );
}

class PlaylistService extends ChangeNotifier {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal();

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _playlists = list.map((e) => Playlist.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_playlists.map((e) => e.toJson()).toList());
    await prefs.setString('playlists', raw);
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    _playlists.add(Playlist(name: name));
    await _save();
  }

  Future<void> renamePlaylist(int index, String newName) async {
    _playlists[index].name = newName;
    await _save();
  }

  Future<void> deletePlaylist(int index) async {
    _playlists.removeAt(index);
    await _save();
  }

  Future<void> addSongToPlaylist(int playlistIndex, int songId) async {
    if (!_playlists[playlistIndex].songIds.contains(songId)) {
      _playlists[playlistIndex].songIds.add(songId);
      await _save();
    }
  }

  Future<void> removeSongFromPlaylist(int playlistIndex, int songId) async {
    _playlists[playlistIndex].songIds.remove(songId);
    await _save();
  }
}
