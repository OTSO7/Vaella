// lib/widgets/post_thumbnail_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart'; // Tuo shimmer-paketti
import '../models/post_model.dart';

class PostThumbnailCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostThumbnailCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tyylikäs shimmer-efekti placeholderiksi
    Widget shimmerPlaceholder = Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerLowest.withOpacity(0.8),
      highlightColor: theme.colorScheme.surfaceContainerLowest.withOpacity(0.4),
      child: Container(
        decoration: BoxDecoration(
          color:
              Colors.white, // Shimmer vaatii taustavärin toimiakseen kunnolla
          borderRadius: BorderRadius.circular(6.0),
        ),
      ),
    );

    // Selkeämpi virhewidget
    Widget errorDisplayWidget = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: theme.hintColor.withOpacity(0.5),
          size: 30,
        ),
      ),
    );

    // Widget, joka näytetään, jos postauksella ei ole lainkaan kuva-URL:ää
    Widget noImageAvailableWidget = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        // borderRadius: BorderRadius.circular(6.0), // Ei tarvita, jos ClipRRect hoitaa
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined, // Kuvake, joka viittaa artikkeliin/tekstiin
          color: theme.hintColor.withOpacity(0.5),
          size: 30,
        ),
      ),
    );

    return InkWell(
      onTap: onTap ??
          () {
            // Oletustoiminto, esim. navigoi julkaisun koko näkymään
            // context.push('/post/${post.id}');
          },
      borderRadius: BorderRadius.circular(6.0), // Napautusalueen pyöristys
      child: AspectRatio(
        aspectRatio: 1.0, // Neliönmuotoinen
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.0), // Lisätty pyöristystä
          child: (post.postImageUrl != null && post.postImageUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: post.postImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => shimmerPlaceholder,
                  errorWidget: (context, url, error) {
                    // Voit logata virheen tässä debuggausta varten
                    // print("Error loading image for post ${post.id} from ${post.postImageUrl}: $error");
                    return errorDisplayWidget;
                  },
                )
              : noImageAvailableWidget, // Näytä tämä, jos postImageUrl on null tai tyhjä
        ),
      ),
    );
  }
}
