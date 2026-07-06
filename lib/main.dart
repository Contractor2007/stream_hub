import 'package:flutter/material.dart';
import 'models/channel.dart';
import 'services/api_service.dart';
import 'player/player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF14141D),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F2230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2E3243), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111117),
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  // Tabs navigation
  int _currentTab = 0;

  // Data states
  List<Channel> _channels = [];
  List<EventDay> _eventDays = [];
  Set<String> _favorites = {};

  bool _isLoadingChannels = false;
  bool _isLoadingEvents = false;
  String? _channelsError;
  String? _eventsError;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyFavorites = false;

  // Active channel selected for desktop/tablet layout
  Channel? _selectedChannel = Channel(
    channelName: 'Channel 419 (Default)',
    channelId: '419',
    url: 'https://daddylive.li/embed/embed.php?id=419&player=1&source=tv.json',
    embedUrl: 'https://daddylive.li/embed/embed.php?id=419&player=1&source=tv.json&autoplay=1&muted=0&mute=0&volume=1',
  );

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {}); // Rebuild lists based on search text
  }

  Future<void> _loadAllData() async {
    await _loadFavorites();
    await Future.wait([_loadChannels(), _loadEvents()]);
  }

  Future<void> _loadFavorites() async {
    try {
      final favs = await ApiService.getFavorites();
      setState(() {
        _favorites = favs;
      });
    } catch (_) {}
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoadingChannels = true;
      _channelsError = null;
    });
    try {
      final channels = await ApiService.fetchChannels();
      setState(() {
        _channels = channels;
        _isLoadingChannels = false;
        // Auto-select channel 419 in desktop/tablet view if available, otherwise first channel
        if (channels.isNotEmpty) {
          final defaultChannel = channels.firstWhere(
            (c) => c.channelId == '419',
            orElse: () => channels.first,
          );
          _selectedChannel = defaultChannel;
        }
      });
    } catch (e) {
      setState(() {
        _channelsError = e.toString().replaceAll('Exception: ', '');
        _isLoadingChannels = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
    });
    try {
      final events = await ApiService.fetchEvents();
      setState(() {
        _eventDays = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      setState(() {
        _eventsError = e.toString().replaceAll('Exception: ', '');
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _toggleFavorite(String channelId) async {
    try {
      final isFav = await ApiService.toggleFavorite(channelId);
      setState(() {
        if (isFav) {
          _favorites.add(channelId);
        } else {
          _favorites.remove(channelId);
        }
      });
    } catch (_) {}
  }

  // Returns embedUrl for channel (either direct or computed)
  String _getEmbedUrl(Channel channel) {
    if (channel.embedUrl != null && channel.embedUrl!.isNotEmpty) {
      String url = channel.embedUrl!;
      if (url.contains('player=')) {
        // Replace any player parameter value with player=1
        url = url.replaceAll(RegExp(r'player=\d+'), 'player=1');
      } else {
        final separator = url.contains('?') ? '&' : '?';
        url = '$url${separator}player=1';
      }
      return url;
    }
    // Compute URL format locally if embedUrl isn't loaded:
    final rawUrl = channel.url;
    if (rawUrl.isEmpty) return '';

    try {
      final uri = Uri.parse(rawUrl);
      final params = Map<String, String>.from(uri.queryParameters);
      params['player'] = '1';
      params['autoplay'] = '1';
      params['muted'] = '0';
      params['mute'] = '0';
      params['volume'] = '1';
      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      final separator = rawUrl.contains('?') ? '&' : '?';
      return '$rawUrl${separator}player=1&autoplay=1&muted=0&mute=0&volume=1';
    }
  }

  void _playChannel(Channel channel) {
    setState(() {
      _selectedChannel = channel;
    });

    // Check width to decide layout.
    // If mobile, push a full screen player page.
    final double width = MediaQuery.of(context).size.width;
    if (width < 800) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MobilePlayerPage(
            channel: channel,
            embedUrl: _getEmbedUrl(channel),
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;

    // Header actions
    final List<Widget> appBarActions = [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.grey),
        tooltip: 'Refresh Data',
        onPressed: _loadAllData,
      ),
    ];

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.stream, color: Colors.blueAccent, size: 28),
              const SizedBox(width: 10),
              const Text(
                'STREAM HUB',
                style: TextStyle(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              _buildLiveBadge(),
            ],
          ),
          actions: appBarActions,
        ),
        body: Row(
          children: [
            // Left sidebar: lists (channels & events)
            SizedBox(
              width: 380,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF14141D),
                  border: Border(
                    right: BorderSide(color: Color(0xFF2A2A35), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Tabs switcher inside sidebar
                    Container(
                      color: const Color(0xFF111117),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _currentTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTab == 0
                                          ? Colors.blueAccent
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.tv,
                                      color: _currentTab == 0
                                          ? Colors.blueAccent
                                          : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Channels',
                                      style: TextStyle(
                                        color: _currentTab == 0
                                            ? Colors.white
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _currentTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTab == 1
                                          ? Colors.blueAccent
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sports_soccer,
                                      color: _currentTab == 1
                                          ? Colors.blueAccent
                                          : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sports Events',
                                      style: TextStyle(
                                        color: _currentTab == 1
                                            ? Colors.white
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _currentTab == 0
                          ? _buildChannelsList()
                          : _buildEventsList(),
                    ),
                  ],
                ),
              ),
            ),
            // Right main view: Stream Player
            Expanded(
              child: _selectedChannel == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 80,
                            color: Color(0xFF2E3243),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Select a channel to start streaming',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          color: const Color(0xFF111117),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tv,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedChannel!.channelName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _favorites.contains(
                                        _selectedChannel!.channelId,
                                      )
                                      ? Icons.star
                                      : Icons.star_border,
                                  color:
                                      _favorites.contains(
                                        _selectedChannel!.channelId,
                                      )
                                      ? Colors.amber
                                      : Colors.grey,
                                ),
                                onPressed: () => _toggleFavorite(
                                  _selectedChannel!.channelId,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.black,
                            child: buildPlayer(
                              context,
                              _getEmbedUrl(_selectedChannel!),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    } else {
      // Mobile View: Bottom navigation tabs
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.stream, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text(
                'STREAM HUB',
                style: TextStyle(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              _buildLiveBadge(),
            ],
          ),
          actions: appBarActions,
        ),
        body: _currentTab == 0 ? _buildChannelsList() : _buildEventsList(),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF2A2A35), width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: (index) => setState(() => _currentTab = index),
            backgroundColor: const Color(0xFF111117),
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Channels'),
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_soccer),
                label: 'Sports Events',
              ),
            ],
          ),
        ),
      );
    }
  }

  // Render Live pulse badge
  Widget _buildLiveBadge() {
    return const BlinkingLiveBadge();
  }

  // Build channels tab list
  Widget _buildChannelsList() {
    if (_isLoadingChannels) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    if (_channelsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading channels:\n$_channelsError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadChannels,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filter channels based on search & favorites
    final query = _searchController.text.trim().toLowerCase();
    final filteredChannels = _channels.where((c) {
      final matchesSearch = c.channelName.toLowerCase().contains(query);
      final matchesFav =
          !_showOnlyFavorites || _favorites.contains(c.channelId);
      return matchesSearch && matchesFav;
    }).toList();

    return Column(
      children: [
        // Search & favorites filter area
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F111B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E3243)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search channels...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 18,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.grey,
                                size: 16,
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Favorites filter button
              IconButton(
                icon: Icon(
                  _showOnlyFavorites ? Icons.star : Icons.star_border,
                  color: _showOnlyFavorites ? Colors.amber : Colors.grey,
                ),
                tooltip: _showOnlyFavorites
                    ? 'Show All Channels'
                    : 'Show Favorites Only',
                onPressed: () {
                  setState(() {
                    _showOnlyFavorites = !_showOnlyFavorites;
                  });
                },
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: filteredChannels.isEmpty
              ? Center(
                  child: Text(
                    _showOnlyFavorites && _favorites.isEmpty
                        ? 'No favorites starred yet'
                        : 'No channels match your search',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChannels,
                  color: Colors.blueAccent,
                  backgroundColor: const Color(0xFF14141D),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredChannels.length,
                    itemBuilder: (context, index) {
                      final channel = filteredChannels[index];
                      final isSelected =
                          _selectedChannel?.channelId == channel.channelId;
                      final isFav = _favorites.contains(channel.channelId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () => _playChannel(channel),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2C3552)
                                  : const Color(0xFF1F2230),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : const Color(0xFF333647),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tv,
                                  color: isSelected
                                      ? Colors.cyanAccent
                                      : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    channel.channelName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? Colors.amber : Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      _toggleFavorite(channel.channelId),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // Build events tab list
  Widget _buildEventsList() {
    if (_isLoadingEvents) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    if (_eventsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading sports schedule:\n$_eventsError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_eventDays.isEmpty) {
      return const Center(
        child: Text(
          'No scheduled events available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF14141D),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _eventDays.length,
        itemBuilder: (context, dayIndex) {
          final eventDay = _eventDays[dayIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF14141D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111117),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eventDay.day,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories
                ...eventDay.categories.entries.map((entry) {
                  final String categoryName = entry.key;
                  final List<LiveEvent> events = entry.value;

                  return ExpansionTile(
                    title: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    leading: _getCategoryIcon(categoryName),
                    collapsedIconColor: Colors.grey,
                    iconColor: Colors.blueAccent,
                    childrenPadding: const EdgeInsets.all(8),
                    shape: const Border(), // No borders around tile when open
                    children: events.map((event) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: event.time.toLowerCase() == 'live'
                                          ? Colors.redAccent
                                          : const Color(0xFF2E3243),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      event.time,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      event.eventName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(
                                color: Color(0xFF2E3243),
                                height: 1,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Available Links:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: event.channels.map((link) {
                                  return ElevatedButton.icon(
                                    onPressed: () => _playChannel(link),
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 14,
                                    ),
                                    label: Text(
                                      link.channelName,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E3243),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // Get matching icon based on sports category title
  Widget _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    IconData iconData = Icons.sports;
    Color color = Colors.grey;

    if (lower.contains('soccer') ||
        lower.contains('football') ||
        lower.contains('⚽')) {
      iconData = Icons.sports_soccer;
      color = Colors.greenAccent;
    } else if (lower.contains('tennis') || lower.contains('🎾')) {
      iconData = Icons.sports_tennis;
      color = Colors.lightGreenAccent;
    } else if (lower.contains('basketball') || lower.contains('🏀')) {
      iconData = Icons.sports_basketball;
      color = Colors.orangeAccent;
    } else if (lower.contains('motor') ||
        lower.contains('f1') ||
        lower.contains('race') ||
        lower.contains('🏎️')) {
      iconData = Icons.sports_motorsports;
      color = Colors.redAccent;
    } else if (lower.contains('card') ||
        lower.contains('wsop') ||
        lower.contains('poker') ||
        lower.contains('🃏')) {
      iconData = Icons.grid_view;
      color = Colors.purpleAccent;
    } else if (lower.contains('popular') || lower.contains('live')) {
      iconData = Icons.offline_bolt;
      color = Colors.amberAccent;
    }

    return Icon(iconData, color: color, size: 18);
  }
}

// Blinking LIVE Badge Widget
class BlinkingLiveBadge extends StatefulWidget {
  const BlinkingLiveBadge({super.key});

  @override
  State<BlinkingLiveBadge> createState() => _BlinkingLiveBadgeState();
}

class _BlinkingLiveBadgeState extends State<BlinkingLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF221115),
        border: Border.all(color: const Color(0xFF661122), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _animationController,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Full Screen player page for Mobile view layout
class MobilePlayerPage extends StatelessWidget {
  final Channel channel;
  final String embedUrl;

  const MobilePlayerPage({
    super.key,
    required this.channel,
    required this.embedUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          channel.channelName,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        color: Colors.black,
        child: buildPlayer(context, embedUrl),
      ),
    );
  }
}
