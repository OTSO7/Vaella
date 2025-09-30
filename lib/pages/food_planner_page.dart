import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../models/hike_plan_model.dart';
import '../widgets/nutrition_info_dialog.dart';
import '../widgets/portion_picker_dialog.dart';
import '../services/hike_plan_service.dart';

// --- FIXED SECTION NAMES ---
const List<String> kFixedSectionNames = <String>[
  'Breakfast',
  'Lunch',
  'Dinner',
  'Evening Meal',
  'Snacks',
];

// --- DATA MODELS ---

class FoodItem {
  final String id;
  String name;
  // Current totals for the selected portion
  double calories;
  double protein;
  double carbs;
  double fats;
  // Portion information
  double amount; // e.g., 120
  String unit; // e.g., 'g', 'ml', 'tsp', 'tbsp', 'dl', 'cup'
  String baseUnit; // 'g' or 'ml' for per-100 scaling
  // Base nutrition per 100 baseUnit (used to rescale when portion changes)
  double baseCaloriesPer100;
  double baseProteinPer100;
  double baseCarbsPer100;
  double baseFatsPer100;
  String? barcode;

  FoodItem({
    required this.id,
    required this.name,
    this.calories = 0.0,
    this.protein = 0.0,
    this.carbs = 0.0,
    this.fats = 0.0,
    this.amount = 0.0,
    this.unit = 'g',
    this.baseUnit = 'g',
    this.baseCaloriesPer100 = 0.0,
    this.baseProteinPer100 = 0.0,
    this.baseCarbsPer100 = 0.0,
    this.baseFatsPer100 = 0.0,
    this.barcode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'amount': amount,
        'unit': unit,
        'baseUnit': baseUnit,
        'baseCaloriesPer100': baseCaloriesPer100,
        'baseProteinPer100': baseProteinPer100,
        'baseCarbsPer100': baseCarbsPer100,
        'baseFatsPer100': baseFatsPer100,
        'barcode': barcode,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String,
        calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
        fats: (json['fats'] as num?)?.toDouble() ?? 0.0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? 'g',
        baseUnit: json['baseUnit'] as String? ?? 'g',
        baseCaloriesPer100:
            (json['baseCaloriesPer100'] as num?)?.toDouble() ?? 0.0,
        baseProteinPer100:
            (json['baseProteinPer100'] as num?)?.toDouble() ?? 0.0,
        baseCarbsPer100: (json['baseCarbsPer100'] as num?)?.toDouble() ?? 0.0,
        baseFatsPer100: (json['baseFatsPer100'] as num?)?.toDouble() ?? 0.0,
        barcode: json['barcode'] as String?,
      );
}

class FoodSection {
  final String id;
  String name;
  final List<FoodItem> items;

  FoodSection({required this.id, required this.name, List<FoodItem>? items})
      : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory FoodSection.fromJson(Map<String, dynamic> json) => FoodSection(
        id: json['id'] as String,
        name: json['name'] as String,
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DayPlan {
  final String id;
  String name;
  final List<FoodSection> sections;

  DayPlan({required this.id, required this.name, List<FoodSection>? sections})
      : sections = sections ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        sections: ((json['sections'] as List<dynamic>?) ?? [])
            .map((e) => FoodSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// --- MAIN WIDGET ---

class FoodPlannerPage extends StatefulWidget {
  final String planId;
  final HikePlan? initialPlan;
  final String? viewingUserId; // For viewing teammate's food plan
  final bool isPreviewMode; // Read-only preview mode

  const FoodPlannerPage({
    super.key,
    required this.planId,
    this.initialPlan,
    this.viewingUserId,
    this.isPreviewMode = false,
  });

  @override
  State<FoodPlannerPage> createState() => _FoodPlannerPageState();
}

class _FoodPlannerPageState extends State<FoodPlannerPage> {
  final List<DayPlan> _dayPlans = [];
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Uuid _uuid = const Uuid();
  bool _isDirty = false;

  HikePlan? _lastSavedPlan;

  DocumentReference<Map<String, dynamic>>? _planDocRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _planSub;

  @override
  void initState() {
    super.initState();
    _lastSavedPlan = widget.initialPlan;
    _initializeDays();
    // Start with clean state since we just loaded
    _isDirty = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachPlanListener();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _planSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FoodPlannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldJson = oldWidget.initialPlan?.foodPlanJson;
    final newJson = widget.initialPlan?.foodPlanJson;
    if (newJson != null && newJson.isNotEmpty && newJson != oldJson) {
      _applyFoodPlanJson(newJson, markClean: true);
      _lastSavedPlan = widget.initialPlan;
    }
  }

  void _attachPlanListener() {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _planDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('plans')
        .doc(widget.planId);

    _planSub = _planDocRef!.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final fp = data['foodPlanJson'] as String?;
      if (fp == null || fp.isEmpty) return;

      if (_isDirty) return;

      final currentJson = jsonEncode(_dayPlans.map((d) => d.toJson()).toList());
      if (currentJson != fp) {
        _applyFoodPlanJson(fp, markClean: true);
      }
    });
  }

  void _applyFoodPlanJson(String jsonString, {bool markClean = false}) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final loadedPlans = decoded
          .map((e) => DayPlan.fromJson(e as Map<String, dynamic>))
          .toList();

      // Normalize to fixed section set for each day
      for (final d in loadedPlans) {
        _ensureFixedSections(d);
      }

      setState(() {
        _dayPlans
          ..clear()
          ..addAll(loadedPlans);
        if (markClean) _isDirty = false;
      });
    } catch (_) {
      // ignore
    }
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  void _initializeDays() {
    if (widget.initialPlan?.foodPlanJson != null &&
        widget.initialPlan!.foodPlanJson!.isNotEmpty) {
      _applyFoodPlanJson(widget.initialPlan!.foodPlanJson!, markClean: true);
      return;
    }

    int numberOfDays = 1;
    if (widget.initialPlan != null && widget.initialPlan!.endDate != null) {
      final duration = widget.initialPlan!.endDate!
              .difference(widget.initialPlan!.startDate)
              .inDays +
          1;
      numberOfDays = duration > 0 ? duration : 1;
    }

    _dayPlans.clear();
    for (int i = 0; i < numberOfDays; i++) {
      final dayNumber = i + 1;
      final day = DayPlan(
        id: _uuid.v4(),
        name: 'Day $dayNumber',
        sections: [],
      );
      _ensureFixedSections(day);
      _dayPlans.add(day);
    }
    // Don't mark as dirty when just initializing empty structure
    _isDirty = false;
  }

  void _ensureFixedSections(DayPlan day) {
    // Keep only fixed sections in fixed order, preserve items where names match.
    final Map<String, FoodSection> byName = {
      for (final s in day.sections) s.name.toLowerCase(): s
    };
    day.sections
      ..clear()
      ..addAll(kFixedSectionNames.map((name) {
        final existing = byName[name.toLowerCase()];
        return existing ??
            FoodSection(
              id: _uuid.v4(),
              name: name,
              items: [],
            );
      }));
  }

  Future<bool> _handleBackPressed() async {
    if (!_isDirty) {
      Navigator.of(context)
          .pop<HikePlan?>(_lastSavedPlan ?? widget.initialPlan);
      return false;
    }

    final cs = Theme.of(context).colorScheme;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Save your changes?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'You have unsaved changes to your food plan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Column(
                children: [
                  // Primary action - Save
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop('save'),
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('Save changes'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Secondary action - Leave without saving
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop('discard'),
                      icon: Icon(
                        Icons.exit_to_app_rounded,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                      label: Text(
                        'Leave without saving',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tertiary action - Stay
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop('cancel'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue editing',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return false;

    switch (action) {
      case 'discard':
        Navigator.of(context)
            .pop<HikePlan?>(_lastSavedPlan ?? widget.initialPlan);
        return false;
      case 'save':
        await _savePlan(popAfter: true);
        return false;
      case 'cancel':
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (widget.isPreviewMode) {
          Navigator.of(context).pop();
          return;
        }
        await _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isPreviewMode ? 'Food Plan Preview' : 'Food Planner',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (widget.isPreviewMode)
                Text(
                  'Viewing teammate\'s meal plan',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.isPreviewMode
                ? () => Navigator.of(context).pop()
                : _handleBackPressed,
          ),
          actions: widget.isPreviewMode
              ? [
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Read Only',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : [
                  IconButton(
                    tooltip: 'Save changes',
                    onPressed: () => _savePlan(),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                  )
                ],
        ),
        body: Column(
          children: [
            _buildDaySelector(theme),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _dayPlans.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  return _buildDayView(_dayPlans[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    final hikeStartDate = widget.initialPlan?.startDate;
    String dateString = '';
    if (hikeStartDate != null) {
      final currentDate = hikeStartDate.add(Duration(days: _currentPage));
      dateString = DateFormat('E, d MMM').format(currentDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _currentPage > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
          ),
          Column(
            children: [
              Text(
                _dayPlans.isNotEmpty ? _dayPlans[_currentPage].name : 'Day 1',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              if (dateString.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    dateString,
                    style: GoogleFonts.lato(
                      color: theme.hintColor,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: _currentPage < _dayPlans.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(DayPlan dayPlan) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        _buildDailyTotalsCard(dayPlan),
        const SizedBox(height: 8),
        ...dayPlan.sections.map((s) => _buildSectionCard(dayPlan, s)),
      ],
    );
  }

  Widget _buildSectionCard(DayPlan dayPlan, FoodSection section) {
    final theme = Theme.of(context);
    final totals = _calculateSectionTotals(section);

    return Card(
      key: ValueKey(section.id),
      color: theme.colorScheme.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                // No rename or delete for sections (fixed structure)
              ],
            ),
            const SizedBox(height: 6),
            if (section.items.isEmpty)
              InkWell(
                onTap: widget.isPreviewMode
                    ? null
                    : () => _showAddFoodAction(section),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_box_outlined,
                          color: theme.hintColor, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add food',
                        style: GoogleFonts.lato(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: section.items
                    .map((item) => _FoodItemExpansionTile(
                          key: ValueKey(item.id),
                          item: item,
                          isPreviewMode: widget.isPreviewMode,
                          onEditPortion: widget.isPreviewMode
                              ? null
                              : () => _editPortion(section, item),
                          onEditMacros: widget.isPreviewMode
                              ? null
                              : () => _editFoodItem(section, item),
                          onDelete: widget.isPreviewMode
                              ? null
                              : () {
                                  setState(() => section.items.remove(item));
                                  _markAsDirty();
                                },
                        ))
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${totals['calories']!.toStringAsFixed(0)} kcal',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!widget.isPreviewMode)
                  FilledButton.icon(
                    onPressed: () => _showAddFoodAction(section),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTotalsCard(DayPlan dayPlan) {
    final theme = Theme.of(context);
    final totals = _calculateDayTotals(dayPlan);

    return Card(
      color: theme.colorScheme.primary.withOpacity(0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day totals',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text(
              '${totals['calories']!.toStringAsFixed(0)} kcal',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Protein ${totals['protein']!.toStringAsFixed(1)} g · Carbs ${totals['carbs']!.toStringAsFixed(1)} g · Fats ${totals['fats']!.toStringAsFixed(1)} g',
              style: GoogleFonts.lato(
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC & DATA HANDLING ---

  Map<String, double> _calculateSectionTotals(FoodSection section) {
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final item in section.items) {
      kcal += item.calories;
      p += item.protein;
      c += item.carbs;
      f += item.fats;
    }
    return {'calories': kcal, 'protein': p, 'carbs': c, 'fats': f};
  }

  Map<String, double> _calculateDayTotals(DayPlan dayPlan) {
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final s in dayPlan.sections) {
      final t = _calculateSectionTotals(s);
      kcal += t['calories']!;
      p += t['protein']!;
      c += t['carbs']!;
      f += t['fats']!;
    }
    return {'calories': kcal, 'protein': p, 'carbs': c, 'fats': f};
  }

  Future<void> _savePlan({bool popAfter = false}) async {
    if (widget.initialPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot save, no initial plan provided.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final foodPlanJsonString =
        jsonEncode(_dayPlans.map((d) => d.toJson()).toList());

    final service = HikePlanService();
    final planToUpdate = widget.initialPlan!.copyWith(
      preparationItems: {
        ...widget.initialPlan!.preparationItems,
        PrepItemKeys.foodPlanner: true,
      },
      foodPlanJson: foodPlanJsonString,
    );

    try {
      final HikePlan updatedPlanFromDb =
          await service.updateHikePlan(planToUpdate);

      if (!mounted) return;
      setState(() {
        _isDirty = false;
        _lastSavedPlan = updatedPlanFromDb;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Food plan saved!'),
          backgroundColor: Colors.teal.shade600,
        ),
      );
      if (popAfter) {
        Navigator.of(context).pop<HikePlan>(updatedPlanFromDb);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving plan: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _showAddFoodAction(FoodSection section) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Scan barcode'),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Add manually'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'scan') {
      final result = await Navigator.push<_ScanResult?>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerView()),
      );
      if (result != null && mounted) {
        await _handleBarcodeResult(section, result);
      }
    } else if (action == 'manual') {
      await _addFoodManually(section);
    }
  }

  Future<void> _addFoodManually(FoodSection section) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Food name'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Oatmeal'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, nameController.text.trim()),
              child: const Text('Next'))
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    // Step 1: Choose portion and unit
    final portion = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const PortionPickerDialog(
        title: 'Select portion',
        baseUnit: 'g',
        initialAmount: 100,
        initialUnit: 'g',
        allowMacroBasisChoice: true,
        initialIsPer100: true,
        allowedUnits: ['g', 'ml', 'tsp', 'tbsp', 'dl', 'cup'],
      ),
    );
    if (portion == null || !mounted) return;

    final double amount = (portion['amount'] as num).toDouble();
    final String unit = portion['unit'] as String;
    final String baseUnit = (unit == 'g') ? 'g' : 'ml';
    final bool isPer100 = portion['isPer100'] as bool? ?? true;

    // Step 2: Enter nutrition info
    await showDialog(
      context: context,
      builder: (context) => NutritionInfoDialog(
        foodName: name,
        subtitle: isPer100
            ? 'Enter values per 100 $baseUnit'
            : 'Enter values for the selected portion ($amount $unit)',
        onSave: (macros) {
          final double kcal = macros['calories'] ?? 0.0;
          final double p = macros['protein'] ?? 0.0;
          final double c = macros['carbs'] ?? 0.0;
          final double f = macros['fats'] ?? 0.0;

          final baseAmount = _toBaseAmount(baseUnit, unit, amount);

          // Determine base per 100
          final double baseK = isPer100
              ? kcal
              : (baseAmount > 0 ? (kcal * 100 / baseAmount) : 0.0);
          final double baseP =
              isPer100 ? p : (baseAmount > 0 ? (p * 100 / baseAmount) : 0.0);
          final double baseC =
              isPer100 ? c : (baseAmount > 0 ? (c * 100 / baseAmount) : 0.0);
          final double baseF =
              isPer100 ? f : (baseAmount > 0 ? (f * 100 / baseAmount) : 0.0);

          // Scale totals for selected portion
          final scaledFactor = baseAmount / 100.0;
          final tK = baseK * scaledFactor;
          final tP = baseP * scaledFactor;
          final tC = baseC * scaledFactor;
          final tF = baseF * scaledFactor;

          setState(() {
            section.items.add(FoodItem(
              id: _uuid.v4(),
              name: name,
              calories: tK,
              protein: tP,
              carbs: tC,
              fats: tF,
              amount: amount,
              unit: unit,
              baseUnit: baseUnit,
              baseCaloriesPer100: baseK,
              baseProteinPer100: baseP,
              baseCarbsPer100: baseC,
              baseFatsPer100: baseF,
            ));
            _markAsDirty();
          });
        },
      ),
    );
  }

  Future<void> _handleBarcodeResult(
      FoodSection section, _ScanResult result) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text('Fetching from OpenFoodFacts: ${result.barcode}'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final product = await _fetchOpenFoodFactsProduct(result.barcode);
      if (!mounted) return;

      if (product == null) {
        scaffold.showSnackBar(
          SnackBar(
            content: const Text('Product not found. Enter manually.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        await _addFoodManually(section);
        return;
      }

      // Ask for portion (mass-based units only due to per-100g data)
      final portion = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => PortionPickerDialog(
          title: product.name ?? 'Select portion',
          baseUnit: 'g',
          initialAmount: 100,
          initialUnit: 'g',
          allowMacroBasisChoice: false,
          initialIsPer100: true,
          allowedUnits: const ['g'],
        ),
      );
      if (portion == null) return;

      final double amount = (portion['amount'] as num).toDouble();
      final String unit = portion['unit'] as String; // should be 'g'
      const String baseUnit = 'g';

      final baseAmount = _toBaseAmount(baseUnit, unit, amount);
      final factor = baseAmount / 100.0;

      setState(() {
        section.items.add(FoodItem(
          id: _uuid.v4(),
          name: product.name ?? 'Scanned product',
          calories: product.kcal * factor,
          protein: product.protein * factor,
          carbs: product.carbs * factor,
          fats: product.fats * factor,
          amount: amount,
          unit: unit,
          baseUnit: baseUnit,
          baseCaloriesPer100: product.kcal,
          baseProteinPer100: product.protein,
          baseCarbsPer100: product.carbs,
          baseFatsPer100: product.fats,
          barcode: result.barcode,
        ));
        _markAsDirty();
      });
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _editFoodItem(FoodSection section, FoodItem item) async {
    await showDialog(
      context: context,
      builder: (context) => NutritionInfoDialog(
        foodName: item.name,
        initialMacros: {
          // Edit current portion totals, not per-100
          'calories': item.calories,
          'protein': item.protein,
          'carbs': item.carbs,
          'fats': item.fats,
        },
        subtitle:
            'Adjust totals for current portion (${item.amount.toStringAsFixed(item.amount == item.amount.roundToDouble() ? 0 : 1)} ${item.unit}).',
        onSave: (macros) {
          setState(() {
            // Update current totals from dialog
            item.calories = (macros['calories'] ?? item.calories)
                .clamp(0.0, double.infinity);
            item.protein =
                (macros['protein'] ?? item.protein).clamp(0.0, double.infinity);
            item.carbs =
                (macros['carbs'] ?? item.carbs).clamp(0.0, double.infinity);
            item.fats =
                (macros['fats'] ?? item.fats).clamp(0.0, double.infinity);

            // Recompute base-per-100 from current portion to keep scaling consistent
            final baseAmount =
                _toBaseAmount(item.baseUnit, item.unit, item.amount);
            final safeBaseAmount = baseAmount > 0 ? baseAmount : 100.0;
            item.baseCaloriesPer100 = (item.calories * 100.0) / safeBaseAmount;
            item.baseProteinPer100 = (item.protein * 100.0) / safeBaseAmount;
            item.baseCarbsPer100 = (item.carbs * 100.0) / safeBaseAmount;
            item.baseFatsPer100 = (item.fats * 100.0) / safeBaseAmount;

            _markAsDirty();
          });
        },
      ),
    );
  }

  Future<_OFFProduct?> _fetchOpenFoodFactsProduct(String barcode) async {
    final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    final res = await http
        .get(url, headers: {'User-Agent': 'VaellaFoodPlanner/1.0 (Flutter)'});
    if (res.statusCode != 200) return null;

    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    if ((jsonMap['status'] as int?) != 1) return null;

    final product = jsonMap['product'] as Map<String, dynamic>;
    final name = product['product_name'] as String?;
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    if (nutriments == null) return _OFFProduct(name: name);

    double kcal = _asDouble(nutriments['energy-kcal_100g']) ??
        _kcalFromKj(_asDouble(nutriments['energy-kj_100g'])) ??
        0.0;
    double protein = _asDouble(nutriments['proteins_100g']) ?? 0.0;
    double carbs = _asDouble(nutriments['carbohydrates_100g']) ?? 0.0;
    double fats = _asDouble(nutriments['fat_100g']) ?? 0.0;

    return _OFFProduct(
        name: name, kcal: kcal, protein: protein, carbs: carbs, fats: fats);
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  double _kcalFromKj(double? kj) => (kj ?? 0.0) / 4.184;

  // --- UNIT/PORTION HELPERS ---
  double _toBaseAmount(String baseUnit, String unit, double amount) {
    if (amount <= 0) return 0.0;
    if (baseUnit == 'g') {
      // Mass: keep grams only (avoid density assumptions)
      return amount; // unit should be 'g'
    } else {
      // Volume (ml)
      switch (unit) {
        case 'ml':
          return amount;
        case 'tsp':
          return amount * 5.0;
        case 'tbsp':
          return amount * 15.0;
        case 'dl':
          return amount * 100.0;
        case 'cup':
          return amount * 240.0;
        default:
          return amount;
      }
    }
  }

  void _editPortion(FoodSection section, FoodItem item) async {
    final bool missingBase = (item.baseCaloriesPer100 == 0.0 &&
        item.baseProteinPer100 == 0.0 &&
        item.baseCarbsPer100 == 0.0 &&
        item.baseFatsPer100 == 0.0);
    if (missingBase) {
      final String baseUnit = item.baseUnit.isNotEmpty ? item.baseUnit : 'g';
      final String unit =
          (item.unit.isNotEmpty) ? item.unit : (baseUnit == 'g' ? 'g' : 'ml');
      final double amount = item.amount > 0 ? item.amount : 100.0;
      final baseAmount = _toBaseAmount(baseUnit, unit, amount);
      final safeBaseAmount = baseAmount > 0 ? baseAmount : 100.0;
      item.baseUnit = baseUnit;
      item.unit = unit;
      item.amount = amount;
      item.baseCaloriesPer100 = (item.calories * 100.0) / safeBaseAmount;
      item.baseProteinPer100 = (item.protein * 100.0) / safeBaseAmount;
      item.baseCarbsPer100 = (item.carbs * 100.0) / safeBaseAmount;
      item.baseFatsPer100 = (item.fats * 100.0) / safeBaseAmount;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PortionPickerDialog(
        title: 'Edit portion',
        baseUnit: item.baseUnit,
        initialAmount: item.amount > 0 ? item.amount : 100,
        initialUnit: item.unit,
        allowMacroBasisChoice: false,
        initialIsPer100: true,
        allowedUnits: item.baseUnit == 'g'
            ? const ['g']
            : const ['ml', 'tsp', 'tbsp', 'dl', 'cup'],
      ),
    );
    if (result == null) return;

    final double amount = (result['amount'] as num).toDouble();
    final String unit = result['unit'] as String;
    final String baseUnit = item.baseUnit;

    final baseAmount = _toBaseAmount(baseUnit, unit, amount);
    final factor = baseAmount / 100.0;

    setState(() {
      item.amount = amount;
      item.unit = unit;
      item.calories = item.baseCaloriesPer100 * factor;
      item.protein = item.baseProteinPer100 * factor;
      item.carbs = item.baseCarbsPer100 * factor;
      item.fats = item.baseFatsPer100 * factor;
      _markAsDirty();
    });
  }
}

// --- FOOD ITEM EXPANSION TILE (collapsed shows only name) ---

class _FoodItemExpansionTile extends StatefulWidget {
  final FoodItem item;
  final VoidCallback? onEditPortion;
  final VoidCallback? onEditMacros;
  final VoidCallback? onDelete;
  final bool isPreviewMode;

  const _FoodItemExpansionTile({
    super.key,
    required this.item,
    this.onEditPortion,
    this.onEditMacros,
    this.onDelete,
    this.isPreviewMode = false,
  });

  @override
  State<_FoodItemExpansionTile> createState() => _FoodItemExpansionTileState();
}

class _FoodItemExpansionTileState extends State<_FoodItemExpansionTile>
    with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = widget.item;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? theme.colorScheme.primary.withOpacity(0.35)
              : theme.dividerColor.withOpacity(0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                i.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            // Smooth open & close animations (size + fade)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _expanded
                    ? _buildDetails(context, i)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, FoodItem i) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withOpacity(0.9);

    Widget chip(IconData icon, String label, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.lato(color: textColor)),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('details'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text('Nutrition',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(Icons.local_fire_department_rounded,
                  '${i.calories.toStringAsFixed(0)} kcal', Colors.redAccent),
              chip(Icons.fitness_center_rounded,
                  'Protein ${i.protein.toStringAsFixed(1)} g', Colors.teal),
              chip(Icons.grain_rounded, 'Carbs ${i.carbs.toStringAsFixed(1)} g',
                  Colors.orange),
              chip(Icons.circle_rounded, 'Fats ${i.fats.toStringAsFixed(1)} g',
                  Colors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Text('Portion',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            '${i.amount.toStringAsFixed(i.amount == i.amount.roundToDouble() ? 0 : 1)} ${i.unit}'
            '  (base: per 100 ${i.baseUnit})',
            style: GoogleFonts.lato(
                color: theme.colorScheme.onSurface.withOpacity(0.8)),
          ),
          const SizedBox(height: 12),
          // Use Wrap to avoid overflow on narrow screens
          if (!widget.isPreviewMode)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onEditPortion,
                  icon: const Icon(Icons.scale_rounded),
                  label: const Text('Edit portion'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onEditMacros,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Edit macros'),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_rounded,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Preview Mode - Read Only',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}

// --- HELPER & SUB-WIDGETS ---

class _OFFProduct {
  final String? name;
  final double kcal, protein, carbs, fats;
  _OFFProduct(
      {this.name,
      this.kcal = 0.0,
      this.protein = 0.0,
      this.carbs = 0.0,
      this.fats = 0.0});
}

class _ScanResult {
  final String barcode;
  const _ScanResult(this.barcode);
}

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});
  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _locked = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            const Text('Scan Barcode', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) async {
              if (_locked) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              setState(() => _locked = true);
              Navigator.of(context).pop<_ScanResult?>(_ScanResult(raw));
            },
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 220,
              decoration: BoxDecoration(
                border:
                    Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Text(
              'Align barcode within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
