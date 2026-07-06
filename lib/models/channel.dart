class Channel {
  final String channelName;
  final String channelId;
  final String url;
  final String? embedUrl;

  Channel({
    required this.channelName,
    required this.channelId,
    required this.url,
    this.embedUrl,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      channelName: json['channel_name']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      embedUrl: json['embedUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_name': channelName,
      'channel_id': channelId,
      'url': url,
      if (embedUrl != null) 'embedUrl': embedUrl,
    };
  }
}

class LiveEvent {
  final String time;
  final String eventName;
  final List<Channel> channels;
  final String source;

  LiveEvent({
    required this.time,
    required this.eventName,
    required this.channels,
    required this.source,
  });

  factory LiveEvent.fromJson(Map<String, dynamic> json) {
    final channelList = json['channels'] as List?;
    return LiveEvent(
      time: json['time']?.toString() ?? '',
      eventName: json['event']?.toString() ?? '',
      channels: channelList != null
          ? channelList.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      source: json['source']?.toString() ?? '',
    );
  }
}

class EventDay {
  final String day;
  final Map<String, List<LiveEvent>> categories;

  EventDay({
    required this.day,
    required this.categories,
  });

  factory EventDay.fromJson(Map<String, dynamic> json) {
    final dayStr = json['day']?.toString() ?? '';
    final categoriesMap = <String, List<LiveEvent>>{};
    
    final categoriesJson = json['categories'] as Map<String, dynamic>?;
    if (categoriesJson != null) {
      categoriesJson.forEach((categoryName, eventsJson) {
        if (eventsJson is List) {
          categoriesMap[categoryName] = eventsJson
              .map((e) => LiveEvent.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      });
    }

    return EventDay(
      day: dayStr,
      categories: categoriesMap,
    );
  }
}
