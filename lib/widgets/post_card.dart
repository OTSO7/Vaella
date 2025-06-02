// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/post_model.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Varmista, että tämä on lisätty pubspec.yaml-tiedostoon

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  // Muutettu TickerProviderStateMixiniksi useille animaatioille
  late AnimationController _entryAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Lisätään tilamuuttujat tykkäykselle ja kommentoinnille (demo)
  bool _isLiked =
      false; // TODO: Hae todellinen tila Firebasesta / käyttäjän tiedoista
  int _likeCount = 0; // TODO: Hae todellinen tila Firebasesta

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fi_FI', null).then((_) {
      if (mounted) setState(() {});
    });

    _likeCount = widget.post.likes.length; // Alusta tykkäysmäärä

    _entryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entryAnimationController,
      curve: Curves.elasticOut, // Kimmoisa efekti
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryAnimationController,
      curve: Curves.easeOutCubic,
    );

    _entryAnimationController.forward();
  }

  @override
  void dispose() {
    _entryAnimationController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    // Demo tykkäyksen vaihdolle
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
        // TODO: Lisää logiikka tykkäyksen tallentamiseksi Firebaseen
        // widget.post.likes.add(currentUser.uid);
      } else {
        _likeCount--;
        // TODO: Lisää logiikka tykkäyksen poistamiseksi Firebasesta
        // widget.post.likes.remove(currentUser.uid);
      }
    });
    // Tässä voisi myös animoida sydän-ikonia
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final timeAgo = _getTimeAgo(widget.post.timestamp);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          // Käytetään Card-widgetiä pohjana
          elevation: 3.0, // Hienovarainen korostus
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0), // Pyöristetyt kulmat
            // side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2), width: 0.5), // Valinnainen reunaviiva
          ),
          color: theme.cardColor, // Käytetään teeman cardColoria
          clipBehavior: Clip
              .antiAlias, // Varmistaa, että sisältö leikkautuu pyöristysten mukaan
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(context, theme, textTheme, timeAgo),
              if (widget.post.postImageUrl != null &&
                  widget.post.postImageUrl!.isNotEmpty)
                _buildPostImage(context, theme),
              _buildContent(context, theme, textTheme),
              _buildActionButtonsFooter(context, theme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme,
      TextTheme textTheme, String timeAgo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 10.0),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () {/* TODO: Navigoi käyttäjän profiiliin */},
            child: CircleAvatar(
              radius: 20,
              backgroundImage:
                  CachedNetworkImageProvider(widget.post.userAvatarUrl),
              backgroundColor: theme.colorScheme.surfaceVariant,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        // NÄYTETÄÄN KÄYTTÄJÄTUNNUS (USERNAME) @-merkillä
                        "@${widget.post.username}",
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600, // Korostettu
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.post.location.isNotEmpty) ...[
                      Text(" • ",
                          style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6))),
                      Flexible(
                        child: Text(
                          widget.post.location,
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]
                  ],
                ),
                Text(
                  timeAgo, // Aikaleima käyttäjätunnuksen alle
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.7)),
            splashRadius: 20,
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () =>
                _showFeatureComingSoon(context, "Postausasetukset"),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(BuildContext context, ThemeData theme) {
    return GestureDetector(
      // Mahdollistaa kuvan tuplaklikkaus-tykkäyksen tulevaisuudessa
      // onDoubleTap: _toggleLike,
      child: Container(
        constraints: BoxConstraints(
          // Rajoitetaan kuvan maksimikorkeutta
          maxHeight: MediaQuery.of(context).size.height *
              0.5, // Esim. puolet näytön korkeudesta
        ),
        child: CachedNetworkImage(
          imageUrl: widget.post.postImageUrl!,
          fit: BoxFit.cover, // Peittää koko alueen
          placeholder: (context, url) => Container(
            height: 250, // Placeholderin korkeus
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: theme.colorScheme.secondary)),
          ),
          errorWidget: (context, url, error) => Container(
            height: 250, // Placeholderin korkeus
            color: theme.colorScheme.errorContainer.withOpacity(0.3),
            child: Icon(Icons.broken_image_outlined,
                color: theme.colorScheme.onErrorContainer.withOpacity(0.6),
                size: 50),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    final String hikeDuration =
        '${widget.post.nights} yö${widget.post.nights != 1 ? 'tä' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700, // Selkeä otsikko
              fontSize: 19,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8.0),
          if (widget.post.caption.isNotEmpty) ...[
            Text(
              widget.post.caption,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.85),
                fontSize: 14.5,
                height: 1.4,
              ),
              maxLines:
                  3, // Näytä muutama rivi, "Lue lisää" voisi olla hyvä lisä
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10.0),
          ],

          // Vaelluksen tiedot (päivämäärät, matka, yöt)
          Row(
            children: [
              _buildSmallInfoPill(theme, Icons.calendar_month_outlined,
                  '${DateFormat('d.M.yy', 'fi_FI').format(widget.post.startDate)} - ${DateFormat('d.M.yy', 'fi_FI').format(widget.post.endDate)}'),
              const SizedBox(width: 8),
              _buildSmallInfoPill(theme, Icons.hiking,
                  '${widget.post.distanceKm.toStringAsFixed(widget.post.distanceKm.truncateToDouble() == widget.post.distanceKm ? 0 : 1)} km'),
              const SizedBox(width: 8),
              _buildSmallInfoPill(
                  theme, Icons.nights_stay_outlined, hikeDuration),
            ],
          ),

          // Jaettavat lisätiedot (paino, kalorit)
          if (widget.post.sharedData.isNotEmpty &&
              (widget.post.sharedData.contains('packing') &&
                      widget.post.weightKg != null ||
                  widget.post.sharedData.contains('food') &&
                      widget.post.caloriesPerDay != null))
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                children: [
                  if (widget.post.sharedData.contains('packing') &&
                      widget.post.weightKg != null)
                    _buildSmallInfoPill(theme, Icons.backpack_outlined,
                        '${widget.post.weightKg!.toStringAsFixed(1)} kg',
                        color: theme.colorScheme.tertiary),
                  if (widget.post.sharedData.contains('food') &&
                      widget.post.caloriesPerDay != null)
                    _buildSmallInfoPill(
                        theme,
                        Icons.local_fire_department_outlined,
                        '${widget.post.caloriesPerDay!.round()} kcal/pv',
                        color: theme.colorScheme.tertiary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallInfoPill(ThemeData theme, IconData icon, String text,
      {Color? color}) {
    final pillColor = color ?? theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: pillColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pillColor,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsFooter(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    // Käytetään _likeCount ja _isLiked tilamuuttujia
    String likeText = _likeCount.toString();
    if (_likeCount == 1 && _isLiked) {
      likeText = "Sinä tykkäsit";
    } else if (_likeCount > 0) {
      likeText = _likeCount.toString();
    } else {
      likeText = ""; // Ei näytetä "0" vaan tyhjä, tai "Tykkää"
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildFooterButton(
                context, theme,
                _isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                _isLiked
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface.withOpacity(0.7),
                likeText.isNotEmpty
                    ? likeText
                    : "Tykkää", // Näytä "Tykkää" jos ei numeroa
                _toggleLike,
              ),
              _buildFooterButton(
                context,
                theme,
                Icons.chat_bubble_outline_rounded,
                theme.colorScheme.onSurface.withOpacity(0.7),
                widget.post.commentCount > 0
                    ? widget.post.commentCount.toString()
                    : "Kommentoi",
                () => _showFeatureComingSoon(context, "Kommentit"),
              ),
              _buildFooterButton(
                context, theme,
                Icons.share_outlined, // Ei pyöristettyä versiota oletuksena
                theme.colorScheme.onSurface.withOpacity(0.7),
                "Jaa",
                () => _showFeatureComingSoon(context, "Jako"),
              ),
            ],
          ),
          // Jos halutaan "Reitti" ja "Kopioi" -napit footeriin:
          // if (widget.post.sharedData.contains('route') || widget.post.planId != null) ... [
          //   // Tähän voisi lisätä pienemmät versiot niistä napeista
          // ]
        ],
      ),
    );
  }

  Widget _buildFooterButton(BuildContext context, ThemeData theme,
      IconData icon, Color iconColor, String label, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, size: 20.0, color: iconColor),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: iconColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        //foregroundColor: iconColor, // Tämä asettaa sekä ikonin että tekstin värin
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    // ... (koodi ennallaan)
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) {
      try {
        return DateFormat('d.M.yy', 'fi_FI').format(dateTime);
      } catch (e) {
        return DateFormat('dd/MM/yy').format(dateTime);
      }
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} pv';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} t';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min';
    } else {
      return 'Nyt';
    }
  }

  void _showFeatureComingSoon(BuildContext context, String featureName) {
    // ... (koodi ennallaan)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName ei ole vielä toteutettu.'),
        backgroundColor:
            Theme.of(context).colorScheme.surfaceTint.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }
}
