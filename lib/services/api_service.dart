import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class ApiService {
  static const String _favoritesKey = 'favorite_channels';

  static const String _channelsUrl = 'https://daddylive.li/api/channels';
  static const String _eventsUrl = 'https://daddylive.li/api/events';

  // Fetch all channels directly from daddylive.li
  static Future<List<Channel>> fetchChannels() async {
    try {
      final response = await http
          .get(Uri.parse(_channelsUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .where((item) =>
                  item != null &&
                  item is Map &&
                  item['channel_name'] != null &&
                  item['channel_id'] != null)
              .map((item) => Channel(
                    channelName: item['channel_name'].toString(),
                    channelId: item['channel_id'].toString(),
                    url: item['url']?.toString() ??
                        'https://daddylive.li/embed/embed.php?id=${item['channel_id']}&player=1&source=tv.json',
                  ))
              .toList()
            ..sort((a, b) =>
                a.channelName.toLowerCase().compareTo(b.channelName.toLowerCase()));
        }
      }
      throw Exception('Server returned status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load channels: $e');
    }
  }

  // Fetch all events directly from daddylive.li
  static Future<List<EventDay>> fetchEvents() async {
    try {
      final response = await http
          .get(Uri.parse(_eventsUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data.map((e) => EventDay.fromJson(e)).toList();
        }
      }
      throw Exception('Server returned status: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load events: $e');
    }
  }

  // Get list of favorite channel IDs
  static Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey);
    return list?.toSet() ?? {};
  }

  // Add/remove favorite channel ID
  static Future<bool> toggleFavorite(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = (prefs.getStringList(_favoritesKey) ?? []).toSet();

    bool isFavorite;
    if (favorites.contains(channelId)) {
      favorites.remove(channelId);
      isFavorite = false;
    } else {
      favorites.add(channelId);
      isFavorite = true;
    }

    await prefs.setStringList(_favoritesKey, favorites.toList());
    return isFavorite;
  }
}
