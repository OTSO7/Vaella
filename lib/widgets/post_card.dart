import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Varmista, että tämä on mukana kielikohtaista dataa varten
import 'package:google_fonts/google_fonts.dart'; // Lisätty Google Fonts
import '../models/post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false; // TODO: Fetch real state (e.g. from AuthProvider)
  int _likeCount = 0; // TODO: Fetch real state
  String _currentLocale = 'en_US'; // Oletuslokaali

  @override
  void initState() {
    super.initState();
    // Alustetaan kielikohtaiset päivämäärämuotoilut.
    // On parempi tehdä tämä kerran sovelluksen alussa (esim. main.dart),
    // mutta tässä se on varmuuden vuoksi.
    // initializeDateFormatting(); // Yleinen alustus, jos lokaalia ei määritellä erikseen

    _likeCount = widget.post.likes.length;
    // Example: Check if current user has liked the post
    // final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    // if (currentUserId != null) {
    //   _isLiked = widget.post.likes.contains(currentUserId);
    // }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hae nykyinen lokaali ja alusta sille päivämäärämuotoilut
    // Tämä varmistaa, että _getTimeAgo käyttää oikeaa kieltä, jos mahdollista
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != null) {
      _currentLocale = locale.toLanguageTag();
      initializeDateFormatting(_currentLocale, null).then((_) {
        if (mounted) setState(() {});
      }).catchError((e) {
        // Jos lokaalin alustus epäonnistuu, käytetään oletusta
        initializeDateFormatting('en_US', null).then((_) {
          if (mounted) setState(() {});
        });
      });
    } else {
      // Fallback, jos lokaalia ei saada
      initializeDateFormatting('en_US', null).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
        // TODO: Save like to Firebase (add currentUserId to widget.post.likes)
      } else {
        _likeCount--;
        // TODO: Remove like from Firebase (remove currentUserId from widget.post.likes)
      }
    });
    // Optional: Haptic feedback for like
    // HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Käytetään Google Fonts -fontteja
    final textTheme = Theme.of(context).textTheme.apply(
          fontFamily: GoogleFonts.lato().fontFamily, // Oletusfontti Lato
        );
    final timeAgo = _getTimeAgo(widget.post.timestamp);

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      color: theme.colorScheme.surface, // Käytä teeman pintaväriä kortille
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(context, theme, textTheme, timeAgo),
          if (widget.post.postImageUrl != null &&
              widget.post.postImageUrl!.isNotEmpty)
            _buildPostImage(context, theme),
          _buildContent(context, theme, textTheme),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: theme.dividerColor.withOpacity(0.6),
            ),
          ),
          _buildActionButtonsFooter(context, theme),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms, curve: Curves.easeOutCubic).slideY(
        begin: 0.04, end: 0, duration: 400.ms, curve: Curves.easeOutQuint);
  }

  Widget _buildHeader(BuildContext context, ThemeData theme,
      TextTheme textTheme, String timeAgo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 10.0, 10.0),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () {/* TODO: Navigate to user profile */},
            child: CircleAvatar(
              radius: 20,
              backgroundImage: widget.post.userAvatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.post.userAvatarUrl)
                  : null,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
              child: widget.post.userAvatarUrl.isEmpty
                  ? Icon(Icons.person_outline_rounded,
                      size: 22, color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        "@${widget.post.username}",
                        style: GoogleFonts.poppins(
                          // Käyttäjänimi Poppins-fontilla
                          fontWeight: FontWeight.w600,
                          // MUUTETTU VÄRI TÄSSÄ: Käyttäjänimi oranssiksi
                          color: theme.colorScheme.secondary,
                          letterSpacing: 0.1,
                          fontSize: 14.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.post.location.isNotEmpty) ...[
                      Text(
                        " • ",
                        style: GoogleFonts.lato(
                            // Paikkakunta Lato-fontilla
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.7),
                            fontWeight: FontWeight.w500),
                      ),
                      Flexible(
                        child: Text(
                          widget.post.location,
                          style: GoogleFonts.lato(
                            // Paikkakunta Lato-fontilla
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]
                  ],
                ),
                SizedBox(height: widget.post.location.isNotEmpty ? 1.5 : 2),
                Text(
                  timeAgo,
                  style: GoogleFonts.lato(
                    // Aikaleima Lato-fontilla
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)),
            splashRadius: 20,
            iconSize: 24,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: "More options",
            onPressed: () => _showFeatureComingSoon(context, "Post settings"),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onDoubleTap: _toggleLike, // Kaksoisnapautus tykkää
      child: Container(
        margin: EdgeInsets
            .zero, // Poista marginaali, jotta kuva täyttää kortin leveyden
        // Asetetaan kuvalle korkeusrajoitukset
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height *
              0.52, // Max 52% näytön korkeudesta
          minHeight: 220, // Minimi korkeus
        ),
        child: CachedNetworkImage(
          imageUrl: widget.post.postImageUrl!,
          fit: BoxFit.cover, // Kuva täyttää containerin, rajautuu tarvittaessa
          placeholder: (context, url) => Container(
            height: 280, // Placeholderin oletuskorkeus
            color: theme
                .colorScheme.surfaceContainerLowest, // Hienovarainen taustaväri
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.primary.withOpacity(0.8)),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 280, // Virhetilanteen oletuskorkeus
            color: theme.colorScheme.errorContainer.withOpacity(0.15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                    size: 50),
                const SizedBox(height: 10),
                Text(
                  "Image failed to load",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                      // Lato-fontti virheviestille
                      color:
                          theme.colorScheme.onErrorContainer.withOpacity(0.9)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    // Käytetään nykyistä lokaalia päivämäärämuotoilussa
    final DateFormat postDateFormat = DateFormat('d.M.yy', _currentLocale);
    final String hikeDuration =
        '${widget.post.nights} ${widget.post.nights != 1 ? 'nights' : 'night'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.title,
            style: GoogleFonts.poppins(
              // Otsikko Poppins-fontilla
              fontWeight: FontWeight.w600,
              fontSize: 19,
              height: 1.35, // Riviväli
              letterSpacing: 0.05,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8.0),
          if (widget.post.caption.isNotEmpty) ...[
            Text(
              widget.post.caption,
              style: GoogleFonts.lato(
                // Kuvaus Lato-fontilla
                color: theme.colorScheme.onSurface.withOpacity(0.9),
                fontSize: 15,
                height: 1.55, // Riviväli
              ),
              maxLines: 3, // Rajoitetaan kuvauksen pituutta kortissa
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14.0),
          ],
          if (widget.post.caption.isEmpty)
            const SizedBox(height: 6.0), // Pieni väli jos ei kuvausta
          Wrap(
            spacing: 8.0, // Vaakasuuntainen väli pillereiden välillä
            runSpacing:
                8.0, // Pystysuuntainen väli pillereiden välillä rivinvaihdossa
            children: [
              _buildSmallInfoPill(theme, Icons.calendar_today_outlined,
                  '${postDateFormat.format(widget.post.startDate)} - ${postDateFormat.format(widget.post.endDate)}'),
              _buildSmallInfoPill(theme, Icons.hiking_rounded,
                  '${widget.post.distanceKm.toStringAsFixed(widget.post.distanceKm.truncateToDouble() == widget.post.distanceKm ? 0 : 1)} km'),
              _buildSmallInfoPill(theme, Icons.bedtime_outlined, hikeDuration),
              if (widget.post.sharedData.contains('packing') &&
                  widget.post.weightKg != null)
                _buildSmallInfoPill(theme, Icons.backpack_outlined,
                    '${widget.post.weightKg!.toStringAsFixed(widget.post.weightKg!.truncateToDouble() == widget.post.weightKg ? 0 : 1)} kg',
                    color:
                        theme.colorScheme.tertiary), // Paino tertiäärivärillä
              if (widget.post.sharedData.contains('food') &&
                  widget.post.caloriesPerDay != null)
                _buildSmallInfoPill(theme, Icons.local_fire_department_outlined,
                    '${widget.post.caloriesPerDay!.round()} kcal/day',
                    color:
                        theme.colorScheme.tertiary), // Kalorit tertiäärivärillä
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfoPill(ThemeData theme, IconData icon, String text,
      {Color? color}) {
    // MUUTETTU VÄRI TÄSSÄ: Oletusväri infopillereille on nyt primary (sininen)
    final pillForegroundColor = color ?? theme.colorScheme.primary;
    final pillBackgroundColor =
        (color ?? theme.colorScheme.primary).withOpacity(0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: pillBackgroundColor,
        borderRadius: BorderRadius.circular(20.0), // Pyöristetyt kulmat
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Pilleri vie vain tarvittavan tilan
        children: [
          Icon(icon, size: 14.5, color: pillForegroundColor),
          const SizedBox(width: 5.5),
          Text(
            text,
            style: GoogleFonts.lato(
              // Pillerin teksti Lato-fontilla
              color: pillForegroundColor,
              fontWeight: FontWeight.w500, // Hieman vahvempi painotus
              fontSize: 11.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsFooter(BuildContext context, ThemeData theme) {
    String likeLabel = _likeCount > 0 ? _likeCount.toString() : "";
    String commentLabel =
        widget.post.commentCount > 0 ? widget.post.commentCount.toString() : "";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround, // Tasainen jako painikkeille
        children: <Widget>[
          _buildFooterButton(
            context,
            theme,
            _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            _isLiked
                ? theme.colorScheme.error // Tykätty-väri punainen
                : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            likeLabel,
            "Like",
            _toggleLike,
          ),
          _buildFooterButton(
            context,
            theme,
            Icons.mode_comment_outlined,
            theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            commentLabel,
            "Comment",
            () => _showFeatureComingSoon(context, "Comments"),
          ),
          _buildFooterButton(
            context,
            theme,
            Icons.share_outlined,
            theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            "", // Jaa-painikkeessa ei yleensä näytetä lukumäärää
            "Share",
            () => _showFeatureComingSoon(context, "Share"),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    Color iconColor,
    String countLabel,
    String tooltipMessage,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          foregroundColor: iconColor, // Tekstin ja kuvakkeen väri
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        icon: Icon(icon, size: 21.0),
        label: Text(
          countLabel,
          style: GoogleFonts.lato(
            // Footer-painikkeen teksti Lato-fontilla
            fontWeight: FontWeight.w600,
            color: iconColor,
            fontSize: 12.5,
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    // Käytä _currentLocale-muuttujaa DateFormatissa
    try {
      // Jos widget ei ole enää puussa, vältä setState-kutsuja, mutta muotoile silti
      // if (!mounted && !(diff.inDays > 365 || diff.inDays > 7)) {
      //   return DateFormat('d.M.yy', _currentLocale).format(dateTime);
      // } // Tämä ehto voi olla tarpeeton, koska _getTimeAgo kutsutaan build-metodista

      if (diff.inDays > 365) {
        return DateFormat('d.M.yyyy', _currentLocale).format(dateTime);
      } else if (diff.inDays > 30) {
        // Yli kuukausi sitten, näytä päivämäärä
        return DateFormat('d. MMM', _currentLocale).format(dateTime);
      } else if (diff.inDays >= 7) {
        // Yli viikko sitten, näytä "X days ago"
        final weeks = (diff.inDays / 7).floor();
        return weeks > 1 ? '$weeks weeks ago' : '1 week ago';
      } else if (diff.inDays >= 2) {
        return '${diff.inDays} days ago';
      } else if (diff.inDays == 1) {
        // Yritä käyttää lokalisoitua "Yesterday" jos mahdollista
        // Tämä vaatii enemmän työtä lokalisaatiopakettien kanssa,
        // joten pidetään yksinkertaisena toistaiseksi.
        return 'Yesterday';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes} min ago';
      } else if (diff.inSeconds >= 10) {
        return '${diff.inSeconds} s ago';
      }
      return 'Now';
    } catch (e) {
      // Fallback, jos jokin menee pieleen lokalisaation kanssa
      // print("Error formatting time ago with locale '$_currentLocale': $e");
      // Yksinkertainen englanninkielinen fallback
      if (diff.inDays > 7)
        return DateFormat('dd/MM/yy', 'en_US').format(dateTime);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'Just now';
    }
  }

  void _showFeatureComingSoon(BuildContext context, String featureName) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName feature coming soon!',
            style: GoogleFonts.lato(
                color: theme.colorScheme.onSecondaryContainer)),
        backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.98),
        behavior: SnackBarBehavior.floating, // Kelluva tyyli
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 20), // Marginaalit
        duration: const Duration(seconds: 2, milliseconds: 300),
        elevation: 3,
      ),
    );
  }
}
