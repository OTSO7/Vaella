// lib/pages/post_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/post_model.dart';
import '../models/user_profile_model.dart'; // Varmista, että tämä on importattu
import '../widgets/star_rating_display.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  // Tuleva data sisältää sekä postauksen että sen tekijän profiilin
  late Future<(Post?, UserProfile?)> _postAndAuthorFuture;

  @override
  void initState() {
    super.initState();
    _postAndAuthorFuture = _fetchPostAndAuthor();
  }

  // Uusi metodi, joka hakee sekä postauksen että sen tekijän tiedot
  Future<(Post?, UserProfile?)> _fetchPostAndAuthor() async {
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    if (!postDoc.exists) {
      return (null, null); // Postausta ei löytynyt
    }

    final post = Post.fromFirestore(postDoc);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(post.userId)
        .get();
    if (!userDoc.exists) {
      return (post, null); // Käyttäjää ei löytynyt, palautetaan vain postaus
    }

    final author = UserProfile.fromFirestore(userDoc.data()!, userDoc.id);
    return (post, author);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<(Post?, UserProfile?)>(
        future: _postAndAuthorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.$1 == null) {
            return const Center(child: Text('Post not found.'));
          }

          final post = snapshot.data!.$1!;
          final author =
              snapshot.data!.$2; // Voi olla null, jos käyttäjää ei löydy

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, post, author),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildKeyStatsCard(context, post),
                      const SizedBox(height: 16),
                      if (author != null) _buildAuthorCard(context, author),
                      const SizedBox(height: 16),
                      _buildStorySection(context, post),
                      const SizedBox(height: 16),
                      _buildRatingsSection(context, post),
                      const SizedBox(height: 16),
                      if (post.latitude != null && post.longitude != null)
                        _buildMapSection(context, post),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  // --- UUDET UI-RAKENNUSPALIKAT ---

  SliverAppBar _buildSliverAppBar(
      BuildContext context, Post post, UserProfile? author) {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (post.postImageUrl != null)
              Hero(
                tag: 'post_image_${post.id}',
                child: CachedNetworkImage(
                  imageUrl: post.postImageUrl!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                  color: Colors.grey.shade800,
                  child: Icon(Icons.terrain,
                      size: 100, color: Colors.grey.shade700)),
            // Tumma gradientti tekstin luettavuuden parantamiseksi
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(blurRadius: 8, color: Colors.black54)
                      ],
                    ),
                  ),
                  if (author != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: author.photoURL != null
                              ? CachedNetworkImageProvider(author.photoURL!)
                              : null,
                          child: author.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          author.displayName, // KÄYTTÄJÄN OIKEA NIMI
                          style: GoogleFonts.lato(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              const Shadow(blurRadius: 6, color: Colors.black54)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyStatsCard(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoBarItem(context,
                icon: Icon(Icons.hiking_rounded,
                    color: theme.colorScheme.secondary),
                value: post.distanceKm.toStringAsFixed(1),
                unit: 'km'),
            _buildInfoBarItem(context,
                icon: Icon(Icons.night_shelter_outlined,
                    color: theme.colorScheme.secondary),
                value: '${post.nights}',
                unit: post.nights == 1 ? 'night' : 'nights'),
            _buildInfoBarItem(context,
                icon: StarRatingDisplay(
                    rating: post.averageRating, showLabel: false, size: 28),
                value: post.averageRating.toStringAsFixed(1),
                unit: 'Rating'),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorCard(BuildContext context, UserProfile author) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/profile/${author.uid}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: author.photoURL != null
                    ? CachedNetworkImageProvider(author.photoURL!)
                    : null,
                child:
                    author.photoURL == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author.displayName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text("@${author.username}",
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorySection(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Story',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(post.caption.isEmpty ? 'No story shared.' : post.caption,
                style: GoogleFonts.lato(
                    fontSize: 16,
                    height: 1.6,
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSection(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ratings',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildRatingDetailRow(
                'Weather Conditions', post.ratings['weather'] ?? 0),
            const Divider(height: 24),
            _buildRatingDetailRow(
                'Trail Difficulty', post.ratings['difficulty'] ?? 0),
            const Divider(height: 24),
            _buildRatingDetailRow(
                'Overall Experience', post.ratings['experience'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Location',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(post.latitude!, post.longitude!),
                initialZoom: 11.0,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none), // Ei interaktiivinen
              ),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(post.latitude!, post.longitude!),
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin,
                          size: 40, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(post.location,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  // --- APUMETODIT ---

  Widget _buildInfoBarItem(BuildContext context,
      {required Widget icon, required String value, required String unit}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 8),
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(unit,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildRatingDetailRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.lato(fontSize: 16)),
          StarRatingDisplay(rating: rating, showLabel: false, size: 24),
        ],
      ),
    );
  }
}
