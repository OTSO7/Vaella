// lib/widgets/modern/interactive_follow_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile_model.dart';
import '../../providers/auth_provider.dart';

class InteractiveFollowButton extends StatefulWidget {
  final String targetUserId;
  final UserRelation initialRelation;

  const InteractiveFollowButton({
    super.key,
    required this.targetUserId,
    required this.initialRelation,
  });

  @override
  State<InteractiveFollowButton> createState() =>
      _InteractiveFollowButtonState();
}

class _InteractiveFollowButtonState extends State<InteractiveFollowButton> {
  bool _isLoading = false;
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialRelation == UserRelation.following;
  }

  @override
  void didUpdateWidget(covariant InteractiveFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRelation != oldWidget.initialRelation) {
      setState(() {
        _isFollowing = widget.initialRelation == UserRelation.following;
      });
    }
  }

  Future<void> _handleFollowToggle() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.toggleFollowStatus(widget.targetUserId, _isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: Could not update follow status.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 100,
        height: 36,
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.0))),
      );
    }

    if (_isFollowing) {
      return OutlinedButton(
        onPressed: _handleFollowToggle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        child: const Text('Following'),
      );
    } else {
      return ElevatedButton(
        onPressed: _handleFollowToggle,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        child: const Text('Follow'),
      );
    }
  }
}
