// lib/widgets/post_thumbnail_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';

class PostThumbnailCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostThumbnailCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasImage =
        post.postImageUrl != null && post.postImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8.0),
          color: theme.colorScheme.surfaceContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage ? _buildImageCard(context) : _buildTextCard(context),
      ),
    );
  }

  /// Kortti postauksille, joissa ON kuva.
  Widget _buildImageCard(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: post.postImageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(color: Theme.of(context).colorScheme.surface),
          errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.image_not_supported_outlined, size: 32)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.9)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.5, 0.7, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 10,
          right: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                // MUUTETTU: Rajoitetaan otsikko yhteen riviin kuvien päällä.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _getShortDate(post.timestamp),
                style: GoogleFonts.lato(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Kortti postauksille, joissa EI OLE kuvaa.
  Widget _buildTextCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              post.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
              // MUUTETTU: Rajoitetaan otsikko kolmeen riviin.
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _getShortDate(post.timestamp),
              style: GoogleFonts.lato(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getShortDate(DateTime dateTime) {
    return DateFormat('d.M.yyyy').format(dateTime);
  }
}
