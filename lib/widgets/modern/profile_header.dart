// lib/widgets/modern/profile_header.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile_model.dart';
import 'experience_bar.dart';
import 'interactive_follow_button.dart';

class ProfileHeader extends StatefulWidget {
  final UserProfile userProfile;

  const ProfileHeader({super.key, required this.userProfile});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _shineAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _updateAnimationForLevel();
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userProfile.level != oldWidget.userProfile.level) {
      _updateAnimationForLevel();
    }
  }

  void _updateAnimationForLevel() {
    if (_getLevelTitle(widget.userProfile.level) == "Legendary Hiker") {
      _animationController.repeat(reverse: false);
    } else {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getLevelTitle(int currentLevel) {
    if (currentLevel >= 100) return "Legendary Hiker";
    if (currentLevel >= 90) return "Supreme Voyager";
    if (currentLevel >= 80) return "Master Explorer";
    if (currentLevel >= 70) return "Grand Adventurer";
    if (currentLevel >= 60) return "Elite Navigator";
    if (currentLevel >= 50) return "Mountain Virtuoso";
    if (currentLevel >= 40) return "Seasoned Trekker";
    if (currentLevel >= 30) return "Peak Seeker";
    if (currentLevel >= 20) return "Highland Strider";
    if (currentLevel >= 15) return "Pathfinder";
    if (currentLevel >= 10) return "Explorer";
    if (currentLevel >= 5) return "Novice";
    return "Newbie";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelTitle = _getLevelTitle(widget.userProfile.level);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_buildActionButtons(context)],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userProfile.displayName,
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  '@${widget.userProfile.username}',
                  style: GoogleFonts.lato(
                      fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),

                // --- UUSI LEVEL-TITTELI WIDGET ---
                _buildLevelTitleChip(
                    context, levelTitle, widget.userProfile.level),

                if (widget.userProfile.bio != null &&
                    widget.userProfile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(widget.userProfile.bio!,
                      style: GoogleFonts.lato(fontSize: 14, height: 1.4)),
                ],
                const SizedBox(height: 16),
                _buildCountsBar(context, theme),
                const SizedBox(height: 16),
                ExperienceBar(userProfile: widget.userProfile),
              ],
            ),
          ),
          Positioned(
            top: -45,
            left: 16,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: theme.scaffoldBackgroundColor,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: (widget.userProfile.photoURL != null &&
                        widget.userProfile.photoURL!.isNotEmpty)
                    ? NetworkImage(widget.userProfile.photoURL!)
                    : const AssetImage('assets/images/default_avatar.png')
                        as ImageProvider,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTitleChip(BuildContext context, String title, int level) {
    final theme = Theme.of(context);
    final bool isLegendary = title == "Legendary Hiker";
    final bool isEpic = level >= 50 && !isLegendary;

    Color startColor, endColor, borderColor, textColor;

    if (isLegendary) {
      startColor = const Color(0xFF3C2F0E);
      endColor = const Color(0xFF241C06);
      borderColor = const Color(0xFFFFD700);
      textColor = const Color(0xFFFFF8E1);
    } else if (isEpic) {
      startColor = const Color(0xFF311B92);
      endColor = const Color(0xFF1A237E);
      borderColor = const Color(0xFF7E57C2);
      textColor = const Color(0xFFEDE7F6);
    } else {
      startColor = theme.colorScheme.surfaceContainerHighest;
      endColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.7);
      borderColor = theme.colorScheme.outline.withOpacity(0.5);
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    Widget textWidget = Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 0.8,
          shadows: [
            Shadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 1))
          ]),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isLegendary
          ? AnimatedBuilder(
              animation: _shineAnimation,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        Colors.transparent,
                        Colors.white70,
                        Colors.transparent,
                      ],
                      stops: [
                        _shineAnimation.value - 0.5,
                        _shineAnimation.value,
                        _shineAnimation.value + 0.5,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcATop,
                  child: child,
                );
              },
              child: textWidget,
            )
          : textWidget,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (widget.userProfile.relationToCurrentUser) {
      case UserRelation.self:
        return OutlinedButton(
          onPressed: () =>
              context.push('/profile/edit', extra: widget.userProfile),
          child: const Text('Edit Profile'),
        );
      case UserRelation.following:
      case UserRelation.notFollowing:
        return InteractiveFollowButton(
          targetUserId: widget.userProfile.uid,
          initialRelation: widget.userProfile.relationToCurrentUser,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCountsBar(BuildContext context, ThemeData theme) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildCountItem(
              context, 'Posts', widget.userProfile.postsCount, () {}),
          _buildDivider(theme),
          _buildCountItem(context, 'Followers',
              widget.userProfile.followerIds.length, () {}),
          _buildDivider(theme),
          _buildCountItem(context, 'Following',
              widget.userProfile.followingIds.length, () {}),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return VerticalDivider(
      color: theme.dividerColor,
      width: 24,
      thickness: 1,
      indent: 8,
      endIndent: 8,
    );
  }

  Widget _buildCountItem(
      BuildContext context, String label, int count, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            NumberFormat.compact().format(count),
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.lato(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
