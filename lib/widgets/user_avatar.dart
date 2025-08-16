import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  final double radius;
  final String? initialUrl;
  final Color? backgroundColor;
  final IconData placeholderIcon;
  final Color? placeholderColor;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.radius,
    this.initialUrl,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
    this.placeholderColor,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildAvatar(String? url) {
      final hasUrl = (url != null && url.isNotEmpty);
      final avatar = CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        backgroundImage: hasUrl ? NetworkImage(url!) : null,
        child: !hasUrl
            ? Icon(
                placeholderIcon,
                color: placeholderColor ?? theme.colorScheme.primary,
                size: radius,
              )
            : null,
      );

      if (borderColor != null && borderWidth > 0) {
        return Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor!, width: borderWidth),
          ),
          child: avatar,
        );
      }
      return avatar;
    }

    if (userId.isEmpty) {
      return buildAvatar(initialUrl);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return buildAvatar(initialUrl);
        }
        final data = snapshot.data?.data();
        final url = data != null ? (data['photoURL'] as String?) : initialUrl;
        return buildAvatar(url ?? initialUrl);
      },
    );
  }
}
