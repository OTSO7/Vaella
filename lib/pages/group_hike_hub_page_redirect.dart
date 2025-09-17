// lib/pages/group_hike_hub_page_redirect.dart
// Clean redirect to enhanced group hike hub page
import 'package:flutter/material.dart';

import '../models/hike_plan_model.dart';
import 'enhanced_group_hike_hub_page.dart';

class GroupHikeHubPage extends StatelessWidget {
  final HikePlan initialPlan;

  const GroupHikeHubPage({super.key, required this.initialPlan});

  @override
  Widget build(BuildContext context) {
    // Redirect directly to enhanced version with carousel functionality
    return EnhancedGroupHikeHubPage(initialPlan: initialPlan);
  }
}
