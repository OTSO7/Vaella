import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_marker_cluster/src/node/marker_node.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/select_visibility_modal.dart';
import '../widgets/star_rating_display.dart';
import '../models/daily_route_model.dart';
import '../utils/map_helpers.dart';

enum HomeView { map, feed }

enum SortOption {
  newest,
  oldest,
  highestRated,
  longest,
  shortest,
}

// Helper-map, joka yhdistää enumin ja käyttäjälle näkyvän tekstin/ikonin
const Map<SortOption, Map<String, dynamic>> sortOptionsData = {
  SortOption.newest: {
    'label': 'Newest first',
    'icon': Icons.new_releases_outlined
  },
  SortOption.oldest: {'label': 'Oldest first', 'icon': Icons.history_outlined},
  SortOption.highestRated: {
    'label': 'Highest rated',
    'icon': Icons.star_outline_rounded
  },
  SortOption.longest: {
    'label': 'Longest distance',
    'icon': Icons.trending_up_rounded
  },
  SortOption.shortest: {
    'label': 'Shortest distance',
    'icon': Icons.trending_down_rounded
  },
};

class PostMarker extends Marker {
  final Post post;

  PostMarker({
    required this.post,
    required Widget child,
    super.width = 50,
    super.height = 60,
  }) : super(
          point: LatLng(post.latitude!, post.longitude!),
          child: child,
        );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  HomeView _currentView = HomeView.map;
  Post? _selectedPost;

  Stream<List<Post>> _postsStream = const Stream.empty();
  Timer? _debounce;

  SortOption _currentSortOption = SortOption.newest;

  final List<Polyline> _selectedRoutePolylines = [];
  final List<Marker> _arrowMarkers = [];

  @override
  void initState() {
    super.initState();
    _updateStream();

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _updateStream();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateStream() {
    setState(() {
      _postsStream =
          _getPublicPostsStream(_searchController.text, _currentSortOption);
    });
  }

  Stream<List<Post>> _getPublicPostsStream(
      String query, SortOption sortOption) {
    Query postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public');

    final searchTerm = query.trim().toLowerCase();
    if (searchTerm.isNotEmpty) {
      postsQuery = postsQuery
          .where('title_lowercase', isGreaterThanOrEqualTo: searchTerm)
          .where('title_lowercase', isLessThanOrEqualTo: '$searchTerm\uf8ff');
    }

    switch (sortOption) {
      case SortOption.newest:
        postsQuery = postsQuery.orderBy(
            searchTerm.isNotEmpty ? 'title_lowercase' : 'timestamp',
            descending: searchTerm.isEmpty);
        break;
      case SortOption.oldest:
        postsQuery = postsQuery.orderBy('timestamp', descending: false);
        break;
      case SortOption.highestRated:
        postsQuery = postsQuery.orderBy('averageRating', descending: true);
        break;
      case SortOption.longest:
        postsQuery = postsQuery.orderBy('distanceKm', descending: true);
        break;
      case SortOption.shortest:
        postsQuery = postsQuery.orderBy('distanceKm', descending: false);
        break;
    }

    if (searchTerm.isNotEmpty && sortOption != SortOption.newest) {
      postsQuery = postsQuery.orderBy('timestamp', descending: true);
    }

    return postsQuery.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Post.fromFirestore(doc))
        .where((post) => post.latitude != null && post.longitude != null)
        .toList());
  }

  void _updateSelectedRoute() {
    _selectedRoutePolylines.clear();
    _arrowMarkers.clear();

    if (_selectedPost != null &&
        _selectedPost!.dailyRoutes != null &&
        _selectedPost!.dailyRoutes!.isNotEmpty) {
      for (final route in _selectedPost!.dailyRoutes!) {
        final polyline = Polyline(
          points: route.points,
          color: Colors.deepOrange.withOpacity(0.8),
          strokeWidth: 5.0,
          borderColor: Colors.black.withOpacity(0.2),
          borderStrokeWidth: 1.0,
        );
        _selectedRoutePolylines.add(polyline);
      }
      _arrowMarkers
          .addAll(generateArrowMarkersForDays(_selectedPost!.dailyRoutes!));
    }
  }

  void _handlePostSelection(Post post) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPost = post;
      _updateSelectedRoute();
    });

    final bool hasRoute =
        post.dailyRoutes != null && post.dailyRoutes!.isNotEmpty;
    if (hasRoute) {
      final allPoints =
          post.dailyRoutes!.expand((route) => route.points).toList();
      if (allPoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(70.0),
          ),
        );
      }
    } else {
      _mapController.move(LatLng(post.latitude!, post.longitude!), 13);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildInteractivePostModal(context, post),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _selectedPost = null;
          _selectedRoutePolylines.clear();
          _arrowMarkers.clear();
        });
      }
    });
  }

  void _showPostSelectionSheet(BuildContext context, List<Post> posts) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (builderContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Posts at this location',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: posts.length,
                  itemBuilder: (ctx, index) {
                    final post = posts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: post.userAvatarUrl.isNotEmpty
                            ? NetworkImage(post.userAvatarUrl)
                            : null,
                        child: post.userAvatarUrl.isEmpty
                            ? const Icon(Icons.person, size: 24)
                            : null,
                      ),
                      title: Text(post.title,
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      subtitle: Text("by @${post.username}"),
                      onTap: () {
                        Navigator.pop(builderContext);
                        _handlePostSelection(post);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UUTTA: Metodi, joka avaa uuden suodatinpaneelin ---
  void _showFilterSheet() async {
    final result = await showModalBottomSheet<SortOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FilterBottomSheet(initialSortOption: _currentSortOption);
      },
    );

    if (result != null && result != _currentSortOption) {
      setState(() {
        _currentSortOption = result;
        _updateStream();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: StreamBuilder<List<Post>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              (!snapshot.hasData || snapshot.data!.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(
                child: Text("Error loading posts. ${snapshot.error}"));
          }

          final allPosts = snapshot.data ?? [];

          return Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _currentView == HomeView.map
                    ? _buildMapView(context, allPosts)
                    : _buildPostFeed(context, allPosts, authProvider),
              ),
              _buildSearchAndFilterBar(theme),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildFloatingViewSwitcher(context),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: authProvider.isLoggedIn
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                showSelectVisibilityModal(context, (selectedVisibility) {
                  context.push('/create-post', extra: {
                    'visibility': selectedVisibility,
                    'plan': null,
                  });
                });
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilterBar(ThemeData theme) {
    bool isFilterActive = _currentSortOption != SortOption.newest;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 15,
      left: 15,
      right: 15,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(15.0),
                border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 15.0),
                  child: Icon(Icons.search),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Search trips or places...",
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 14),
                    ),
                  ),
                ),
                // --- PÄIVITETTY: Nappi avaa nyt modaalipaneelin ---
                IconButton(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: isFilterActive ? theme.colorScheme.secondary : null,
                  ),
                  onPressed: _showFilterSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Jatkuu alla... (loput HomePage-koodista)
  // Kaikki alla olevat metodit pysyvät ennallaan.

  Widget _buildMapView(BuildContext context, List<Post> posts) {
    final postMarkers = posts
        .map((post) => PostMarker(
              post: post,
              child: _buildPostMarkerWidget(context, post),
            ))
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(64.0, 26.0),
        initialZoom: 5.5,
        maxZoom: 18.0,
        minZoom: 4.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.treknoteflutter',
        ),
        PolylineLayer(polylines: _selectedRoutePolylines),
        MarkerLayer(markers: _arrowMarkers),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80,
            size: const Size(50, 50),
            markers: postMarkers,
            polygonOptions: const PolygonOptions(
              borderColor: Colors.blueAccent,
              color: Colors.black12,
              borderStrokeWidth: 3,
            ),
            builder: (context, markers) {
              return _buildClusterMarker(context, markers.length);
            },
            onClusterTap: (cluster) {
              final firstPoint = cluster.markers.first.point;
              final allSameLocation =
                  cluster.markers.every((m) => m.point == firstPoint);

              if (allSameLocation && cluster.markers.length > 1) {
                final postsInCluster = cluster.markers
                    .map((node) =>
                        ((node as MarkerNode).marker as PostMarker).post)
                    .toList();
                _showPostSelectionSheet(context, postsInCluster);
              } else {
                _mapController.fitCamera(
                  CameraFit.bounds(
                      bounds: cluster.bounds,
                      padding: const EdgeInsets.all(50)),
                );
              }
            },
          ),
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () =>
                  launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostFeed(
      BuildContext context, List<Post> posts, AuthProvider authProvider) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? "No posts yet."
              : "No results for '${_searchController.text}'",
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        _searchController.clear();
        setState(() {
          _currentSortOption = SortOption.newest;
          _updateStream();
        });
      },
      child: ListView.builder(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 80,
            left: 8.0,
            right: 8.0,
            bottom: 120.0),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return PostCard(
            key: ValueKey(posts[index].id),
            post: posts[index],
            currentUserId: authProvider.user?.uid,
          );
        },
      ),
    );
  }

  Widget _buildFloatingViewSwitcher(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(30.0),
              border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSwitcherButton(
                  context, HomeView.map, Icons.map_outlined, "Map"),
              const SizedBox(width: 4),
              _buildSwitcherButton(
                  context, HomeView.feed, Icons.view_stream_outlined, "Feed"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitcherButton(
      BuildContext context, HomeView view, IconData icon, String label) {
    final theme = Theme.of(context);
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () {
        if (_currentView != view) {
          HapticFeedback.lightImpact();
          setState(() {
            _currentView = view;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.iconTheme.color,
              size: 20,
            ),
            if (isSelected) const SizedBox(width: 8),
            if (isSelected)
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildPostMarkerWidget(BuildContext context, Post post) {
    final isSelected = _selectedPost?.id == post.id;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _handlePostSelection(post),
      child: Tooltip(
        message: post.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.cardColor,
                border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    width: isSelected ? 3 : 2),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: post.userAvatarUrl.isNotEmpty
                    ? NetworkImage(post.userAvatarUrl)
                    : null,
                child: post.userAvatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
            ),
            ClipPath(
              clipper: _TriangleClipper(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                height: 8,
                width: 16,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildClusterMarker(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.secondary,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 2,
          )
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractivePostModal(BuildContext context, Post post) {
    final theme = Theme.of(context);
    final hasImage = post.postImageUrl != null && post.postImageUrl!.isNotEmpty;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              color: hasImage ? Colors.black : theme.cardColor,
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(post.postImageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4), BlendMode.darken),
                    )
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              const Shadow(
                                  blurRadius: 10, color: Colors.black87)
                            ])),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: post.userAvatarUrl.isNotEmpty
                              ? NetworkImage(post.userAvatarUrl)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "@${post.username}",
                          style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.9)),
                        ),
                        const Spacer(),
                        StarRatingDisplay(
                            rating: post.averageRating,
                            size: 18,
                            showLabel: false,
                            color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            textStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/post/${post.id}');
                        },
                        child: const Text('View Full Post'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// --- UUTTA: Siisti, uudelleenkäytettävä ja tilallinen widget suodatinpaneelille ---
class _FilterBottomSheet extends StatefulWidget {
  final SortOption initialSortOption;

  const _FilterBottomSheet({required this.initialSortOption});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late SortOption _selectedOption;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.initialSortOption;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Vedettävä kahva ja otsikko
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Sort & Filter',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Suodatinvaihtoehdot
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Text('Sort by',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: SortOption.values.map((option) {
                        return ChoiceChip(
                          label: Text(sortOptionsData[option]!['label']),
                          avatar: Icon(
                            sortOptionsData[option]!['icon'],
                            size: 18,
                            color: _selectedOption == option
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          selected: _selectedOption == option,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedOption = option;
                              });
                            }
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _selectedOption == option
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Toimintonapit
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        child: const Text('Reset'),
                        onPressed: () {
                          setState(() {
                            _selectedOption = SortOption.newest;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Apply Filters'),
                        onPressed: () {
                          Navigator.of(context).pop(_selectedOption);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
