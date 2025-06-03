import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileHeader extends StatefulWidget {
  final String username;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String? bannerImageUrl;
  final VoidCallback onEditProfile;
  final int level;
  final int currentExperience;
  final int experienceToNextLevel;

  const ProfileHeader({
    Key? key,
    required this.username,
    required this.displayName,
    this.photoURL,
    this.bio,
    this.bannerImageUrl,
    required this.onEditProfile,
    required this.level,
    required this.currentExperience,
    required this.experienceToNextLevel,
  }) : super(key: key);

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shineAnimation;
  late Animation<Color?> _glowColorAnimation;
  late Animation<double>
      _textGlowStrengthAnimation; // Tekstin hehkun voimakkuus
  int _previousLevel = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowColorAnimation = ColorTween(
      begin: Colors.amberAccent.shade200.withOpacity(0.0),
      end: Colors.amberAccent.shade200.withOpacity(0.8),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.75, curve: Curves.easeInOut),
      ),
    );

    // Tekstin hehkun voimakkuuden animaatio Legendary Hikerille
    _textGlowStrengthAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0,
            curve: Curves.easeInOut), // Pulssittava voimakkuus
      ),
    );

    _previousLevel = widget.level;
    _updateGlowAnimation();
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.level != oldWidget.level) {
      _previousLevel = widget.level;
      _updateGlowAnimation();
    }
  }

  void _updateGlowAnimation() {
    final bool isLegendary = _getLevelTitle(widget.level) == "Legendary Hiker";
    if (isLegendary) {
      _controller.duration =
          const Duration(seconds: 4); // Hieman pidempi animaatio hehkulle
      _controller.repeat(reverse: true);
    } else {
      _controller.duration =
          const Duration(seconds: 3); // Takaisin oletuskestoon
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getLevelTitle(int currentLevel) {
    if (currentLevel == 100) return "Legendary Hiker";
    if (currentLevel >= 90) return "Supreme Voyager";
    if (currentLevel >= 80) return "Master Explorer";
    if (currentLevel >= 70) return "Grand Adventurer";
    if (currentLevel >= 60) return "Elite Navigator";
    if (currentLevel >= 50) return "Mountain Virtuoso";
    if (currentLevel >= 40) return "Seasoned Trekker";
    if (currentLevel >= 30) return "Peak Seeker";
    if (currentLevel >= 20) return "Highland Strider";
    if (currentLevel >= 15) return "Pathfinder";
    if (currentLevel >= 10) return "Trail Explorer";
    if (currentLevel >= 5) return "Novice Wanderer";
    return "Newbie";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String levelTitle = _getLevelTitle(widget.level);
    final bool isLegendaryHiker = levelTitle == "Legendary Hiker";

    final Color titleColor = isLegendaryHiker
        ? Colors.amberAccent.shade200
        : Colors.white.withOpacity(0.95);

    List<Shadow> textShadows = [
      Shadow(
        blurRadius: 1.0,
        color: Colors.black.withOpacity(0.3),
        offset: const Offset(0.5, 0.5),
      ),
    ];

    if (isLegendaryHiker) {
      textShadows.addAll([
        Shadow(
          blurRadius:
              15.0 * _textGlowStrengthAnimation.value, // Animoitu hehkun blur
          color: _glowColorAnimation.value ??
              Colors.amberAccent.shade200
                  .withOpacity(0.9), // Intensiivisempi hehku
          offset: const Offset(0, 0),
        ),
        Shadow(
          blurRadius:
              30.0 * _textGlowStrengthAnimation.value, // Animoitu hehkun blur
          color: (_glowColorAnimation.value ??
                  Colors.amberAccent.shade200.withOpacity(0.9))
              .withOpacity(0.5 *
                  _textGlowStrengthAnimation.value), // Pehmeämpi ulompi hehku
          offset: const Offset(0, 0),
        ),
      ]);
    }

    final double experienceProgress = (widget.experienceToNextLevel > 0)
        ? widget.currentExperience / widget.experienceToNextLevel
        : 0.0;

    final int xpNeeded = widget.level < 100
        ? widget.experienceToNextLevel - widget.currentExperience
        : 0;
    final int displayXpNeeded = xpNeeded > 0 ? xpNeeded : 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: (widget.bannerImageUrl != null &&
                        widget.bannerImageUrl!.isNotEmpty)
                    ? NetworkImage(widget.bannerImageUrl!)
                    : const AssetImage('assets/images/default_banner.jpg')
                        as ImageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.45), BlendMode.darken),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Colors.white.withOpacity(0.9), size: 26),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
            ),
            tooltip: 'Muokkaa profiilia',
            onPressed: widget.onEditProfile,
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar ilman Legendary Hiker -efektiä
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                        width: 4.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage:
                      (widget.photoURL != null && widget.photoURL!.isNotEmpty)
                          ? NetworkImage(widget.photoURL!)
                          : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                  child: (widget.photoURL == null || widget.photoURL!.isEmpty)
                      ? Icon(Icons.person_outline_rounded,
                          size: 70, color: Colors.grey[400])
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.displayName,
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                            blurRadius: 1.0,
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0.5, 0.5))
                      ]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text('@${widget.username}',
                  style: GoogleFonts.lato(
                      fontSize: 15,
                      color: theme.colorScheme.secondary,
                      shadows: [
                        Shadow(
                            blurRadius: 1.0,
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0.5, 0.5))
                      ]),
                  textAlign: TextAlign.center),
              if (widget.bio != null && widget.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(widget.bio!,
                      style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.45,
                          shadows: [
                            Shadow(
                                blurRadius: 1.0,
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0.5, 0.5))
                          ]),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 65.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                Colors.transparent,
                                Colors.white30,
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
                          child: Text(
                            levelTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: titleColor,
                              letterSpacing: 0.3,
                              shadows: textShadows,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Taso ${widget.level}',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        if (widget.level < 100)
                          Text(
                            '$displayXpNeeded XP tasolle ${widget.level + 1}',
                            style: GoogleFonts.lato(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: experienceProgress,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary.withOpacity(0.9)),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(3.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
