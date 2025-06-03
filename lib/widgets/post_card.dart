// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String? currentUserId; // UUSI: Nykyisen kirjautuneen käyttäjän ID
  final VoidCallback?
      onPostDeleted; // UUSI: Callback, kun postaus on poistettu (listan päivitykseen)

  const PostCard({
    super.key,
    required this.post,
    this.currentUserId, // Lisätty konstruktoriin
    this.onPostDeleted, // Lisätty konstruktoriin
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  String _currentLocale = 'en_US';
  bool _isDeleting = false; // Tila poistotoiminnon latausindikaattorille

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes.length;
    // Voit tarkistaa tässä, onko nykyinen käyttäjä tykännyt postauksesta, jos currentUserId on saatavilla
    if (widget.currentUserId != null) {
      _isLiked = widget.post.likes.contains(widget.currentUserId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != null) {
      _currentLocale = locale.toLanguageTag();
      initializeDateFormatting(_currentLocale, null).then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
        initializeDateFormatting('en_US', null).then((_) {
          if (mounted) setState(() {});
        });
      });
    } else {
      initializeDateFormatting('en_US', null).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _toggleLike() {
    // TODO: Toteuta todellinen tykkäyslogiikka (Firestore-päivitys jne.)
    // Tarvitset nykyisen käyttäjän ID:n tähän.
    // final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // final String? actualCurrentUserId = authProvider.user?.uid;
    // if (actualCurrentUserId == null) {
    //   _showErrorSnackBar("You must be logged in to like posts.");
    //   return;
    // }

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
        // widget.post.likes.add(actualCurrentUserId);
        // Päivitä postaus Firestoreen...
      } else {
        _likeCount--;
        // widget.post.likes.remove(actualCurrentUserId);
        // Päivitä postaus Firestoreen...
      }
    });
  }

  Future<void> _confirmDeletePost() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text('Delete Post?',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface)),
          content: Text(
              'Are you sure you want to permanently delete this post? This action cannot be undone.',
              style:
                  GoogleFonts.lato(color: theme.colorScheme.onSurfaceVariant)),
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
              child: Text('Delete',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      _deletePost();
    }
  }

  Future<void> _deletePost() async {
    if (!mounted) return;
    setState(() => _isDeleting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);

    try {
      // 1. Poista julkaisu Firestoresta
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .delete();

      // 2. Päivitä käyttäjän postsCount, JOS poistettu postaus oli nykyisen käyttäjän oma
      if (authProvider.user?.uid == widget.post.userId) {
        await authProvider.handlePostDeletionSuccess();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Post deleted successfully!', style: GoogleFonts.lato()),
            backgroundColor: Colors.green[600], // Selkeämpi vihreä
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );
        // Kutsu callbackia, jos sellainen on annettu (listan päivittämiseksi vanhempikomponentissa)
        widget.onPostDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: ${e.toString()}',
                style: GoogleFonts.lato()),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = Theme.of(context)
        .textTheme
        .apply(fontFamily: GoogleFonts.lato().fontFamily);
    final timeAgo = _getTimeAgo(widget.post.timestamp);

    // Häivytä kortti ja näytä latausindikaattori poiston aikana
    return Opacity(
      opacity: _isDeleting ? 0.5 : 1.0,
      child: AbsorbPointer(
        absorbing: _isDeleting,
        child: Card(
          elevation: _isDeleting ? 0 : 2.5, // Poista korostus poiston aikana
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          color: theme.cardColor, // <--- TÄMÄ ON MUUTETTU RIVI
          clipBehavior: Clip.antiAlias,
          child: Stack(
            // Lisätty Stack latausindikaattoria varten
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeader(context, theme, textTheme, timeAgo),
                  if (widget.post.postImageUrl != null &&
                      widget.post.postImageUrl!.isNotEmpty)
                    _buildPostImage(context, theme),
                  _buildContent(context, theme, textTheme),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.dividerColor.withOpacity(0.6)),
                  ),
                  _buildActionButtonsFooter(context, theme),
                ],
              ),
              if (_isDeleting) // Näytä latausindikaattori kortin päällä
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor
                          .withOpacity(0.5), // Hieman tummennusta
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: theme.colorScheme.primary)),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 450.ms, curve: Curves.easeOutCubic).slideY(
            begin: 0.04, end: 0, duration: 400.ms, curve: Curves.easeOutQuint),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme,
      TextTheme textTheme, String timeAgo) {
    final bool isOwnPost = widget.currentUserId != null &&
        widget.currentUserId == widget.post.userId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          16.0, 12.0, 8.0, 10.0), // Pienennetty oikeaa paddingia
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              // TODO: Navigoi käyttäjän profiiliin (widget.post.userId)
              // Esim. context.push('/users/${widget.post.userId}');
            },
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
                      child: Text("@${widget.post.username}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.secondary,
                              letterSpacing: 0.1,
                              fontSize: 14.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (widget.post.location.isNotEmpty) ...[
                      Text(" • ",
                          style: GoogleFonts.lato(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.7),
                              fontWeight: FontWeight.w500)),
                      Flexible(
                        child: Text(widget.post.location,
                            style: GoogleFonts.lato(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12.5),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]
                  ],
                ),
                SizedBox(height: widget.post.location.isNotEmpty ? 1.5 : 2),
                Text(timeAgo,
                    style: GoogleFonts.lato(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // KORVATTU IconButton PopupMenuButtonilla
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)),
            tooltip: "More options",
            iconSize: 24,
            padding: const EdgeInsets.all(0), // Poista oletuspadding
            splashRadius: 20,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(10)), // Pyöristetyt kulmat valikolle
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (isOwnPost) // Näytä "Delete" vain omille postauksille
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Text('Delete Post',
                        style: GoogleFonts.lato(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              // Voit lisätä "Edit" -vaihtoehdon omille postauksille myöhemmin
              // if (isOwnPost)
              //   PopupMenuItem<String>(
              //     value: 'edit',
              //     child: Row(children: [
              //       Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              //       const SizedBox(width: 8),
              //       Text('Edit Post', style: GoogleFonts.lato(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
              //     ]),
              //   ),
              if (!isOwnPost) // Näytä "Details" (tai "Report") muiden postauksille
                PopupMenuItem<String>(
                  value: 'details',
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('Details',
                        style: GoogleFonts.lato(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              if (!isOwnPost) // Esimerkki: Report-toiminto
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.report_outlined,
                        size: 20,
                        color: theme.colorScheme.error.withOpacity(0.8)),
                    const SizedBox(width: 8),
                    Text('Report Post',
                        style: GoogleFonts.lato(
                            color: theme.colorScheme.error.withOpacity(0.8),
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
            ],
            onSelected: (String value) {
              if (value == 'delete') {
                _confirmDeletePost(); // Kutsu varmistusdialogia
              } else if (value == 'details') {
                _showFeatureComingSoon(context, "Post details");
              } else if (value == 'report') {
                _showFeatureComingSoon(context, "Report post");
              }
              // Käsittele 'edit' täällä, jos lisäät sen
            },
          ),
        ],
      ),
    );
  }

  // _buildPostImage, _buildContent, _buildSmallInfoPill, _buildActionButtonsFooter,
  // _buildFooterButton, _getTimeAgo, _showFeatureComingSoon pysyvät pääosin ennallaan.
  // Varmista, että ne käyttävät GoogleFonts-fontteja yhtenäisesti.

  Widget _buildPostImage(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onDoubleTap: _toggleLike,
      child: Container(
        margin: EdgeInsets.zero,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.52,
            minHeight: 220),
        child: CachedNetworkImage(
          imageUrl: widget.post.postImageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 280,
            color: theme.colorScheme.surfaceContainerLowest,
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: theme.colorScheme.primary.withOpacity(0.8))),
          ),
          errorWidget: (context, url, error) => Container(
            height: 280,
            color: theme.colorScheme.errorContainer.withOpacity(0.15),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.broken_image_outlined,
                  color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                  size: 50),
              const SizedBox(height: 10),
              Text("Image failed to load",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                      color:
                          theme.colorScheme.onErrorContainer.withOpacity(0.9))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    final String dateRange =
        _formatDateRange(widget.post.startDate, widget.post.endDate);

    final String hikeDuration =
        '${widget.post.nights} ${widget.post.nights != 1 ? 'nights' : 'night'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.post.title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 19,
                height: 1.35,
                letterSpacing: 0.05,
                color: theme.colorScheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8.0),
        if (widget.post.caption.isNotEmpty) ...[
          Text(widget.post.caption,
              style: GoogleFonts.lato(
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.55),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14.0),
        ],
        if (widget.post.caption.isEmpty) const SizedBox(height: 6.0),
        Wrap(spacing: 8.0, runSpacing: 8.0, children: [
          _buildSmallInfoPill(theme, Icons.calendar_today_outlined, dateRange),
          _buildSmallInfoPill(theme, Icons.hiking_rounded,
              '${widget.post.distanceKm.toStringAsFixed(widget.post.distanceKm.truncateToDouble() == widget.post.distanceKm ? 0 : 1)} km'),
          _buildSmallInfoPill(theme, Icons.bedtime_outlined, hikeDuration),
          if (widget.post.sharedData.contains('packing') &&
              widget.post.weightKg != null)
            _buildSmallInfoPill(theme, Icons.backpack_outlined,
                '${widget.post.weightKg!.toStringAsFixed(widget.post.weightKg!.truncateToDouble() == widget.post.weightKg ? 0 : 1)} kg',
                color: theme.colorScheme.tertiary),
          if (widget.post.sharedData.contains('food') &&
              widget.post.caloriesPerDay != null)
            _buildSmallInfoPill(theme, Icons.local_fire_department_outlined,
                '${widget.post.caloriesPerDay!.round()} kcal/day',
                color: theme.colorScheme.tertiary),
        ]),
      ]),
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      if (start.month == end.month) {
        return '${start.day}.${start.month}.–${end.day}.${end.month}.';
      } else {
        return '${start.day}.${start.month}.–${end.day}.${end.month}.';
      }
    } else {
      return '${start.day}.${start.month}.${start.year} – ${end.day}.${end.month}.${end.year}';
    }
  }

  Widget _buildSmallInfoPill(ThemeData theme, IconData icon, String text,
      {Color? color}) {
    final pillForegroundColor = color ?? theme.colorScheme.primary;
    final pillBackgroundColor =
        (color ?? theme.colorScheme.primary).withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
      decoration: BoxDecoration(
          color: pillBackgroundColor,
          borderRadius: BorderRadius.circular(20.0)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14.5, color: pillForegroundColor),
        const SizedBox(width: 5.5),
        Text(text,
            style: GoogleFonts.lato(
                color: pillForegroundColor,
                fontWeight: FontWeight.w500,
                fontSize: 11.8)),
      ]),
    );
  }

  Widget _buildActionButtonsFooter(BuildContext context, ThemeData theme) {
    String likeLabel = _likeCount > 0 ? _likeCount.toString() : "";
    String commentLabel =
        widget.post.commentCount > 0 ? widget.post.commentCount.toString() : "";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildFooterButton(
                context,
                theme,
                _isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                _isLiked
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                likeLabel,
                "Like",
                _toggleLike),
            _buildFooterButton(
                context,
                theme,
                Icons.mode_comment_outlined,
                theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                commentLabel,
                "Comment",
                () => _showFeatureComingSoon(context, "Comments")),
            _buildFooterButton(
                context,
                theme,
                Icons.share_outlined,
                theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                "",
                "Share",
                () => _showFeatureComingSoon(context, "Share")),
          ]),
    );
  }

  Widget _buildFooterButton(
      BuildContext context,
      ThemeData theme,
      IconData icon,
      Color iconColor,
      String countLabel,
      String tooltipMessage,
      VoidCallback onPressed) {
    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      child: TextButton.icon(
        style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            foregroundColor: iconColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0))),
        icon: Icon(icon, size: 21.0),
        label: Text(countLabel,
            style: GoogleFonts.lato(
                fontWeight: FontWeight.w600, color: iconColor, fontSize: 12.5)),
        onPressed: onPressed,
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    try {
      if (diff.inDays > 365)
        return DateFormat('d.M.yyyy', _currentLocale).format(dateTime);
      else if (diff.inDays > 30)
        return DateFormat('d. MMM', _currentLocale).format(dateTime);
      else if (diff.inDays >= 7) {
        final weeks = (diff.inDays / 7).floor();
        return weeks > 1 ? '$weeks weeks ago' : '1 week ago';
      } else if (diff.inDays >= 2)
        return '${diff.inDays} days ago';
      else if (diff.inDays == 1)
        return 'Yesterday';
      else if (diff.inHours >= 1)
        return '${diff.inHours}h ago';
      else if (diff.inMinutes >= 1)
        return '${diff.inMinutes} min ago';
      else if (diff.inSeconds >= 10) return '${diff.inSeconds} s ago';
      return 'Now';
    } catch (e) {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$featureName feature coming soon!',
          style:
              GoogleFonts.lato(color: theme.colorScheme.onSecondaryContainer)),
      backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.98),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(15, 5, 15, 20),
      duration: const Duration(seconds: 2, milliseconds: 300),
      elevation: 3,
    ));
  }

  void _showErrorSnackBar(String message) {
    // Lisätty virhe-snackbar
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        margin: const EdgeInsets.all(10.0),
      ),
    );
  }
}
