// lib/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// MUUTETTU: Palautettu StatefulWidget-muotoon animaatioita varten
class ProfileHeader extends StatefulWidget {
  final String username;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String? bannerImageUrl;
  final int level;
  final int currentExperience;
  final int experienceToNextLevel;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.displayName,
    this.photoURL,
    this.bio,
    this.bannerImageUrl,
    required this.level,
    required this.currentExperience,
    required this.experienceToNextLevel,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader>
    with SingleTickerProviderStateMixin {
  // LISÄTTY: Animaatiokontrolleri ja animaatio-oliot tuotu takaisin
  late AnimationController _animationController;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _shineAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
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

  Color _getColorForLevel(int level, ThemeData theme) {
    if (level >= 100) return Colors.amber.shade600;
    if (level >= 50) return Colors.purple.shade300;
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasBanner =
        widget.bannerImageUrl != null && widget.bannerImageUrl!.isNotEmpty;
    final Color textColor =
        hasBanner ? Colors.white : theme.colorScheme.onSurface;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (hasBanner)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.bannerImageUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.45),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                        width: 4.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ]),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage:
                      (widget.photoURL != null && widget.photoURL!.isNotEmpty)
                          ? NetworkImage(widget.photoURL!)
                          : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.displayName,
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      shadows: const [
                        Shadow(
                            blurRadius: 2.0,
                            color: Colors.black54,
                            offset: Offset(1, 1))
                      ]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text('@${widget.username}',
                  style: GoogleFonts.lato(
                      fontSize: 15,
                      color: theme.colorScheme.secondary,
                      shadows: const [
                        Shadow(
                            blurRadius: 1.0,
                            color: Colors.black54,
                            offset: Offset(0.5, 0.5))
                      ]),
                  textAlign: TextAlign.center),
              if (widget.bio != null && widget.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(widget.bio!,
                    style: GoogleFonts.lato(
                        fontSize: 14,
                        color: hasBanner
                            ? Colors.white.withOpacity(0.9)
                            : theme.colorScheme.onSurfaceVariant,
                        height: 1.45),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 20),
              _buildCompactLevelIndicator(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLevelIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final levelTitle = _getLevelTitle(widget.level);
    final levelColor = _getColorForLevel(widget.level, theme);
    final double experienceProgress = (widget.experienceToNextLevel > 0)
        ? widget.currentExperience / widget.experienceToNextLevel
        : 0.0;

    // Animaatio on aktiivinen vain tasosta 50 eteenpäin
    final bool isAnimationActive = widget.level >= 50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.3))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // MUUTETTU: Titteli on nyt animoitu
              AnimatedBuilder(
                animation: _shineAnimation,
                builder: (context, child) {
                  // Käytetään ShaderMaskia vain, jos animaatio on aktiivinen
                  if (isAnimationActive) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          transform: _SlideGradientTransform(
                              percent: _shineAnimation.value),
                          colors: [levelColor, Colors.white, levelColor],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: child,
                    );
                  }
                  return child!;
                },
                child: Text(
                  levelTitle,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: levelColor,
                  ),
                ),
              ),
              Text(
                'Level ${widget.level}',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: experienceProgress,
              minHeight: 6,
              backgroundColor: theme.dividerColor.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
        ],
      ),
    );
  }
}

// LISÄTTY: Apuluokka gradientin liikuttamiseen ShaderMaskissa
class _SlideGradientTransform extends GradientTransform {
  final double percent;
  const _SlideGradientTransform({required this.percent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0.0, 0.0);
  }
}
