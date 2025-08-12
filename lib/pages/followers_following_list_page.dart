import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_search_list_tile.dart';
import '../providers/follow_provider.dart';

enum UserListType { followers, following }

class FollowersFollowingListPage extends StatefulWidget {
  final String userId;
  final UserListType listType;

  const FollowersFollowingListPage({
    super.key,
    required this.userId,
    required this.listType,
  });

  @override
  State<FollowersFollowingListPage> createState() =>
      _FollowersFollowingListPageState();
}

class _FollowersFollowingListPageState
    extends State<FollowersFollowingListPage> {
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final profile = await authProvider.fetchUserProfileById(widget.userId);
      List<String> ids = widget.listType == UserListType.followers
          ? profile.followerIds
          : profile.followingIds;
      if (ids.isEmpty) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
        return;
      }
      // Haetaan käyttäjäprofiilit Firestoresta
      List<UserProfile> users = [];
      for (final id in ids) {
        try {
          final user = await authProvider.fetchUserProfileById(id);
          users.add(user);
        } catch (_) {}
      }
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _users = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        widget.listType == UserListType.followers ? "Followers" : "Following";
    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(
                    widget.listType == UserListType.followers
                        ? "No followers yet."
                        : "Not following anyone yet.",
                    style:
                        GoogleFonts.lato(fontSize: 16, color: theme.hintColor),
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Consumer<FollowProvider>(
                      builder: (context, followProvider, child) {
                        final isFollowing =
                            followProvider.isFollowing(user.uid);
                        return UserSearchListTile(
                          userProfile: user,
                          isFollowing: isFollowing,
                          onFollowToggle: (follow) async {
                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            await authProvider.toggleFollowStatus(
                                user.uid, isFollowing);
                            followProvider.setFollowing(user.uid, !isFollowing);
                          },
                          onTap: () => context.push('/profile/${user.uid}'),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
