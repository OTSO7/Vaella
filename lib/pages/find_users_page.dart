import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_search_list_tile.dart';
import '../providers/follow_provider.dart';

class FindUsersPage extends StatefulWidget {
  const FindUsersPage({super.key});

  @override
  State<FindUsersPage> createState() => _FindUsersPageState();
}

class _FindUsersPageState extends State<FindUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty && query != _lastSearchQuery) {
        _lastSearchQuery = query;
        _performSearch(query);
      } else if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _lastSearchQuery = '';
          });
        }
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final results = await authProvider.searchUsersByUsername(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Users',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _buildBodyContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildEmptyState(theme);
    }

    if (_searchResults.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              return Consumer<FollowProvider>(
                builder: (context, followProvider, child) {
                  final isFollowing = followProvider.isFollowing(user.uid);
                  return UserSearchListTile(
                    userProfile: user,
                    isFollowing: isFollowing,
                    onFollowToggle: (follow) async {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.toggleFollowStatus(
                          user.uid, isFollowing);
                      followProvider.setFollowing(user.uid, !isFollowing);
                    },
                    onTap: () => context.push('/profile/${user.uid}'),
                  );
                },
              );
            },
          );
        },
      );
    }

    return _buildInitialPrompt(theme);
  }

  Widget _buildInitialPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add_outlined, size: 60, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'Find new adventurers',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Start typing a username above to find and follow other users.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined,
                size: 60, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't find anyone matching '${_searchController.text}'.\nCheck the spelling and try again.",
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
