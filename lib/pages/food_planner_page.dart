import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../models/hike_plan_model.dart';
import '../widgets/nutrition_info_dialog.dart';
import '../services/hike_plan_service.dart';

// --- DATA MODELS ---

class FoodItem {
  final String id;
  String name;
  double calories;
  double protein;
  double carbs;
  double fats;
  String? barcode;

  FoodItem({
    required this.id,
    required this.name,
    this.calories = 0.0,
    this.protein = 0.0,
    this.carbs = 0.0,
    this.fats = 0.0,
    this.barcode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'barcode': barcode,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'],
        name: json['name'],
        calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
        fats: (json['fats'] as num?)?.toDouble() ?? 0.0,
        barcode: json['barcode'],
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
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory FoodSection.fromJson(Map<String, dynamic> json) => FoodSection(
        id: json['id'],
        name: json['name'],
        items: (json['items'] as List<dynamic>?)
                ?.map((itemJson) =>
                    FoodItem.fromJson(itemJson as Map<String, dynamic>))
                .toList() ??
            [],
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
        'sections': sections.map((section) => section.toJson()).toList(),
      };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
        id: json['id'],
        name: json['name'],
        sections: (json['sections'] as List<dynamic>?)
                ?.map((sectionJson) =>
                    FoodSection.fromJson(sectionJson as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// --- MAIN WIDGET ---

class FoodPlannerPage extends StatefulWidget {
  final String planId;
  final HikePlan? initialPlan;

  const FoodPlannerPage({super.key, required this.planId, this.initialPlan});

  @override
  State<FoodPlannerPage> createState() => _FoodPlannerPageState();
}

class _FoodPlannerPageState extends State<FoodPlannerPage> {
  final List<DayPlan> _dayPlans = [];
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });

    _initializeDays();
  }

  void _initializeDays() {
    // Try to load existing food plan first
    if (widget.initialPlan?.foodPlanJson != null &&
        widget.initialPlan!.foodPlanJson!.isNotEmpty) {
      try {
        final List<dynamic> decodedList =
            jsonDecode(widget.initialPlan!.foodPlanJson!);
        final loadedPlans = decodedList
            .map((planJson) =>
                DayPlan.fromJson(planJson as Map<String, dynamic>))
            .toList();
        if (loadedPlans.isNotEmpty) {
          _dayPlans.addAll(loadedPlans);
          return; // Exit if loaded successfully
        }
      } catch (e) {
        print("Error decoding food plan JSON: $e");
        // Fallback to creating default days if decoding fails
      }
    }

    // Fallback: Create default days if no plan exists or loading failed
    int numberOfDays = 1; // Default to 1 day
    if (widget.initialPlan != null &&
        widget.initialPlan!.startDate != null &&
        widget.initialPlan!.endDate != null) {
      final duration = widget.initialPlan!.endDate!
              .difference(widget.initialPlan!.startDate!)
              .inDays +
          1;
      numberOfDays = duration > 0 ? duration : 1;
    }

    for (int i = 0; i < numberOfDays; i++) {
      final dayNumber = i + 1;
      _dayPlans.add(
        DayPlan(
          id: _uuid.v4(),
          name: 'Day $dayNumber',
          sections: [
            FoodSection(id: _uuid.v4(), name: 'Breakfast'),
            FoodSection(id: _uuid.v4(), name: 'Lunch'),
            FoodSection(id: _uuid.v4(), name: 'Dinner'),
            FoodSection(id: _uuid.v4(), name: 'Snacks'),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Food Planner',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Save and Mark as Done',
            onPressed: _savePlan,
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
              itemBuilder: (context, index) {
                return _buildDayView(_dayPlans[index]);
              },
            ),
          ),
        ],
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
    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      header: Column(
        children: [
          _buildDailyTotalsCard(dayPlan),
          const SizedBox(height: 8),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Center(
          child: TextButton.icon(
            onPressed: () => _addSectionDialog(dayPlan),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Add Meal Section'),
          ),
        ),
      ),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = dayPlan.sections.removeAt(oldIndex);
          dayPlan.sections.insert(newIndex, item);
        });
      },
      children: dayPlan.sections
          .map((section) => _buildSectionCard(dayPlan, section))
          .toList(),
    );
  }

  Widget _buildSectionCard(DayPlan dayPlan, FoodSection section) {
    final theme = Theme.of(context);
    final totals = _calculateSectionTotals(section);

    return Card(
      key: ValueKey(section.id),
      color: theme.colorScheme.surface,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: dayPlan.sections.indexOf(section),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                ),
                Expanded(
                  child: Text(
                    section.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Rename',
                  onPressed: () => _renameSection(section),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Remove section',
                  onPressed: () =>
                      setState(() => dayPlan.sections.remove(section)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (section.items.isEmpty)
              InkWell(
                onTap: () => _showAddFoodAction(section),
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
                    .map((item) => _buildFoodItemTile(section, item))
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 44.0), // Align with title
                    child: Text(
                      'Total: ${totals['calories']!.toStringAsFixed(0)} kcal',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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

  Widget _buildFoodItemTile(FoodSection section, FoodItem item) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(left: 36, right: 0, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Text(
          item.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.calories.toStringAsFixed(0)} kcal · P ${item.protein.toStringAsFixed(0)}g · C ${item.carbs.toStringAsFixed(0)}g · F ${item.fats.toStringAsFixed(0)}g',
          style: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.8), fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => _editFoodItem(section, item),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => setState(() => section.items.remove(item)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTotalsCard(DayPlan dayPlan) {
    final theme = Theme.of(context);
    final totals = _calculateDayTotals(dayPlan);

    return Card(
      color: theme.colorScheme.primary.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
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

  Future<void> _savePlan() async {
    if (widget.initialPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot save, no initial plan provided.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // Serialize the current food plan to a JSON string
    final foodPlanJsonString =
        jsonEncode(_dayPlans.map((d) => d.toJson()).toList());

    final service = HikePlanService();
    final planToUpdate = widget.initialPlan!.copyWith(
      preparationItems: {
        ...widget.initialPlan!.preparationItems,
        PrepItemKeys.foodPlanner: true,
      },
      // Save the serialized food plan data
      foodPlanJson: foodPlanJsonString,
    );

    try {
      // The service now returns the fully updated plan from Firestore
      final HikePlan updatedPlanFromDb =
          await service.updateHikePlan(planToUpdate);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Food plan saved!'),
          backgroundColor: Colors.teal.shade600,
        ),
      );
      // Pop the page and return the fresh, updated plan object
      Navigator.of(context).pop(updatedPlanFromDb);
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

  Future<void> _addSectionDialog(DayPlan dayPlan) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Meal Section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Section name',
            hintText: 'e.g. Evening snacks',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'))
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() {
        dayPlan.sections.add(FoodSection(id: _uuid.v4(), name: name));
      });
    }
  }

  Future<void> _renameSection(FoodSection section) async {
    final controller = TextEditingController(text: section.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Section name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'))
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => section.name = newName);
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

    await showDialog(
      context: context,
      builder: (context) => NutritionInfoDialog(
        foodName: name,
        onSave: (macros) {
          setState(() {
            section.items.add(FoodItem(
              id: _uuid.v4(),
              name: name,
              calories: macros['calories'] ?? 0,
              protein: macros['protein'] ?? 0,
              carbs: macros['carbs'] ?? 0,
              fats: macros['fats'] ?? 0,
            ));
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

      setState(() {
        section.items.add(FoodItem(
          id: _uuid.v4(),
          name: product.name ?? 'Scanned product',
          calories: product.kcal,
          protein: product.protein,
          carbs: product.carbs,
          fats: product.fats,
          barcode: result.barcode,
        ));
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
          'calories': item.calories,
          'protein': item.protein,
          'carbs': item.carbs,
          'fats': item.fats,
        },
        onSave: (macros) {
          setState(() {
            item.calories = macros['calories'] ?? item.calories;
            item.protein = macros['protein'] ?? item.protein;
            item.carbs = macros['carbs'] ?? item.carbs;
            item.fats = macros['fats'] ?? item.fats;
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
              final raw = capture.barcodes.firstOrNull?.rawValue;
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
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Text(
              'Align barcode within the frame',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
