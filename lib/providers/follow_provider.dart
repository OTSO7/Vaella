import 'package:flutter/material.dart';

class FollowProvider with ChangeNotifier {
  final Set<String> _following = {};

  bool isFollowing(String userId) => _following.contains(userId);

  void setFollowing(String userId, bool following) {
    if (following) {
      _following.add(userId);
    } else {
      _following.remove(userId);
    }
    notifyListeners();
  }

  void setFollowingList(List<String> followingIds) {
    _following
      ..clear()
      ..addAll(followingIds);
    notifyListeners();
  }
}
