import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class ApiService {
  static const String _serverUrlKey = 'backend_server_url';
  static const String _favoritesKey = 'favorite_channels';
  
  static const String remoteChannelsUrl = 'https://daddylive.li/api/channels';
  static const String remoteEventsUrl = 'https://daddylive.li/api/events';

  // Default value is 'DIRECT' to fetch directly from daddylive.li serverlessly
  static String get defaultServerUrl => 'DIRECT';

  // Get current server configuration
  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? defaultServerUrl;
  }

  // Set current server configuration
  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String formattedUrl = url.trim();
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }
    await prefs.setString(_serverUrlKey, formattedUrl);
  }

  // Local client-side channel list normalization
  static List<Channel> _normalizeChannels(List<dynamic> payload) {
    return payload
        .where((item) =>
            item != null &&
            item is Map &&
            item['channel_name'] != null &&
            item['channel_id'] != null)
        .map((item) {
          final name = item['channel_name'].toString();
          final id = item['channel_id'].toString();
          final url = item['url']?.toString() ??
              'https://daddylive.li/embed/embed.php?id=$id&player=1&source=tv.json';
          return Channel(
            channelName: name,
            channelId: id,
            url: url,
          );
        })
        .toList()
      ..sort((a, b) => a.channelName.toLowerCase().compareTo(b.channelName.toLowerCase()));
  }

  // Fetch all channels
  static Future<List<Channel>> fetchChannels() async {
    try {
      final configUrl = await getServerUrl();

      if (configUrl == 'DIRECT' || configUrl.isEmpty) {
        // Serverless direct fetch
        final response = await http.get(Uri.parse(remoteChannelsUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data is List) {
            return _normalizeChannels(data);
          }
        }
        throw Exception('Server returned status: ${response.statusCode}');
      } else {
        // Proxy fetch
        final url = Uri.parse('$configUrl/api/channels');
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final list = data['channels'] as List?;
          if (list != null) {
            return list.map((e) => Channel.fromJson(e)).toList();
          }
        }
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load channels: $e');
    }
  }

  // Fetch channel detail (not used directly since we compute embedUrl client-side, but kept for compatibility)
  static Future<Channel> fetchChannelDetail(String channelId) async {
    try {
      final configUrl = await getServerUrl();

      if (configUrl == 'DIRECT' || configUrl.isEmpty) {
        // Serverless direct fetch & client-side build
        final channels = await fetchChannels();
        final channel = channels.firstWhere(
          (entry) => entry.channelId == channelId,
          orElse: () => throw Exception('Channel not found'),
        );
        return channel;
      } else {
        // Proxy fetch
        final url = Uri.parse('$configUrl/api/channel/$channelId');
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final channelData = data['channel'];
          if (channelData != null) {
            return Channel.fromJson(channelData);
          }
        }
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load channel detail: $e');
    }
  }

  // Fetch all events
  static Future<List<EventDay>> fetchEvents() async {
    try {
      final configUrl = await getServerUrl();

      if (configUrl == 'DIRECT' || configUrl.isEmpty) {
        // Serverless direct fetch
        final response = await http.get(Uri.parse(remoteEventsUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data is List) {
            return data.map((e) => EventDay.fromJson(e)).toList();
          }
        }
        throw Exception('Server returned status: ${response.statusCode}');
      } else {
        // Proxy fetch
        final url = Uri.parse('$configUrl/api/events');
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final list = data['events'] as List?;
          if (list != null) {
            return list.map((e) => EventDay.fromJson(e)).toList();
          }
        }
        throw Exception('Server returned status: ${response.statusCode}');
      }
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
