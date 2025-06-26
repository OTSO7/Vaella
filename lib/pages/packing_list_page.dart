// lib/pages/packing_list_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import 'package:uuid/uuid.dart'; // Import for Uuid

import '../models/hike_plan_model.dart';
import '../models/packing_list_item.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';

class PackingListPage extends StatefulWidget {
  final String planId;
  final HikePlan initialPlan;

  const PackingListPage({
    super.key,
    required this.planId,
    required this.initialPlan,
  });

  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  // RE-ADDED: _currentPlan as a state variable to prevent rebuilds on stream updates
  HikePlan?
      _currentHikePlan; // Changed name for clarity to avoid confusion with StreamBuilder's snapshot.data
  final HikePlanService _hikePlanService = HikePlanService();
  final TextEditingController _newItemNameController = TextEditingController();
  final TextEditingController _newItemQuantityController =
      TextEditingController();
  final TextEditingController _categoryFilterController =
      TextEditingController();
  String _selectedCategory = 'General';
  List<String> _categories = [
    'General',
    'Clothing',
    'Shelter',
    'Cooking',
    'Navigation',
    'First Aid',
    'Hygiene',
    'Tools',
    'Documents',
    'Electronics',
    'Food',
    'Miscellaneous',
  ];

  Timer? _debounceTimer;
  StreamSubscription<HikePlan?>?
      _hikePlanSubscription; // Keep this to manage stream lifecycle

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final Map<String, bool> _pendingUpdates = {};

  @override
  void initState() {
    super.initState();
    _currentHikePlan =
        widget.initialPlan; // Initialize with initial data from route
    print('PackingListPage: Initial Plan ID from widget: ${widget.planId}');
    _subscribeToHikePlanChanges(); // Start listening to Firestore immediately
  }

  @override
  void dispose() {
    _newItemNameController.dispose();
    _newItemQuantityController.dispose();
    _categoryFilterController.dispose();
    _debounceTimer?.cancel();
    _hikePlanSubscription?.cancel(); // Cancel subscription on dispose
    super.dispose();
  }

  void _subscribeToHikePlanChanges() {
    _hikePlanSubscription?.cancel(); // Ensure only one active subscription
    _hikePlanSubscription =
        _hikePlanService.getHikePlanStream(widget.planId).listen((plan) {
      if (mounted) {
        if (plan != null) {
          // This setState will trigger a rebuild with the latest data from Firestore
          // It's the primary way _currentHikePlan stays updated.
          setState(() {
            _currentHikePlan = plan;
          });
          print(
              'PackingListPage: Plan data updated from stream: ID ${plan.id}');
          print(
              'PackingListPage: Streamed Packing List: ${plan.packingList.map((item) => '${item.name} packed: ${item.isPacked}').toList()}');
        } else {
          print(
              'PackingListPage: Plan not found or deleted via stream. Navigating back.');
          // If the plan no longer exists in Firestore, navigate back
          if (mounted) {
            GoRouter.of(context).pop();
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content:
                    Text('Hike plan was deleted.', style: GoogleFonts.lato()),
                backgroundColor: AppColors.errorColor(context),
              ),
            );
          }
        }
      }
    }, onError: (error) {
      print('PackingListPage: Error subscribing to hike plan: $error');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error loading hike plan: $error',
                style: GoogleFonts.lato()),
            backgroundColor: AppColors.errorColor(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  TextTheme _getAppTextTheme(BuildContext context) {
    final currentTheme = Theme.of(context);
    return GoogleFonts.latoTextTheme(currentTheme.textTheme).copyWith(
      headlineLarge: currentTheme.textTheme.headlineLarge
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      headlineMedium: currentTheme.textTheme.headlineMedium
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      headlineSmall: currentTheme.textTheme.headlineSmall
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      titleLarge: currentTheme.textTheme.titleLarge
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      titleMedium: currentTheme.textTheme.titleMedium
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      titleSmall: currentTheme.textTheme.titleSmall
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      labelLarge: currentTheme.textTheme.labelLarge
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      bodyLarge: currentTheme.textTheme.bodyLarge
          ?.copyWith(fontFamily: GoogleFonts.lato().fontFamily),
      bodyMedium: currentTheme.textTheme.bodyMedium
          ?.copyWith(fontFamily: GoogleFonts.lato().fontFamily),
      bodySmall: currentTheme.textTheme.bodySmall
          ?.copyWith(fontFamily: GoogleFonts.lato().fontFamily),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    required TextTheme appTextTheme,
  }) {
    final theme = Theme.of(context);
    final labelStyle = appTextTheme.bodyMedium
        ?.copyWith(color: AppColors.subtleTextColor(context));
    final hintStyle = appTextTheme.bodyMedium
        ?.copyWith(color: AppColors.subtleTextColor(context).withOpacity(0.7));

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon,
              color: theme.colorScheme.secondary.withOpacity(0.7))
          : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide:
            BorderSide(color: AppColors.primaryColor(context), width: 1.8),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      errorStyle: appTextTheme.bodySmall
          ?.copyWith(color: AppColors.errorColor(context).withOpacity(0.8)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
            color: AppColors.errorColor(context).withOpacity(0.7), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: AppColors.errorColor(context), width: 2),
      ),
    );
  }

  Future<void> _updateHikePlan(HikePlan updatedPlan, String? affectedItemId,
      {bool showSuccess = true}) async {
    print('PackingListPage: _updateHikePlan called for plan ${updatedPlan.id}');

    // Set pending status for the affected item immediately (optimistic UI)
    if (affectedItemId != null && mounted) {
      setState(() {
        _pendingUpdates[affectedItemId] = true;
      });
      print(
          'PackingListPage: Optimistic update: Item $affectedItemId marked as pending.');
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 700), () async {
      print(
          'PackingListPage: Debounce timer fired for plan ${updatedPlan.id}.');
      if (!mounted) {
        print(
            'PackingListPage: Debounce callback: Widget not mounted, returning.');
        return;
      }

      try {
        print(
            'PackingListPage: Attempting Firestore update for plan ${updatedPlan.id}...');
        print(
            'PackingListPage: Packing list items before save: ${updatedPlan.packingList.map((item) => '${item.name} (${item.isPacked ? 'packed' : 'unpack'})').toList()}');

        await _hikePlanService.updateHikePlan(updatedPlan);

        print(
            'PackingListPage: Firestore update successful for plan ${updatedPlan.id}.');

        // Clear pending status after successful update
        if (affectedItemId != null && mounted) {
          setState(() {
            _pendingUpdates.remove(affectedItemId);
          });
          print(
              'PackingListPage: Optimistic update: Item $affectedItemId pending status cleared.');
        }

        if (mounted && showSuccess) {
          _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Packing list updated!', style: GoogleFonts.lato()),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('PackingListPage: Error during Firestore update: $e');
        // Clear pending status and show error
        if (affectedItemId != null && mounted) {
          setState(() {
            _pendingUpdates.remove(affectedItemId);
            // The StreamBuilder will automatically revert the UI because Firestore data
            // won't reflect the failed change. This is the desired behavior for optimistic UI.
            print(
                'PackingListPage: Optimistic update: Item $affectedItemId pending status cleared due to error. UI will revert via stream.');
          });
        }

        if (mounted) {
          _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Error updating packing list: $e',
                  style: GoogleFonts.lato()),
              backgroundColor: AppColors.errorColor(context),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    });
  }

  // MODIFIED: _togglePackedStatus now updates the item's `isPacked` status directly
  // within the current list received from the StreamBuilder and dispatches it.
  void _togglePackedStatus(PackingListItem item, HikePlan currentHikePlan) {
    print('PackingListPage: Toggling status for item: ${item.name}');

    // Create a new list where the target item's isPacked status is toggled.
    final List<PackingListItem> updatedList =
        currentHikePlan.packingList.map((i) {
      return i.id == item.id ? i.copyWith(isPacked: !item.isPacked) : i;
    }).toList();

    // Call _updateHikePlan to dispatch the updated plan to Firestore.
    // The UI will be optimistically updated via _pendingUpdates state.
    _updateHikePlan(
        currentHikePlan.copyWith(packingList: updatedList), item.id);
  }

  Future<void> _selectCategory(BuildContext context, TextTheme appTextTheme,
      Function(String) onCategorySelected) async {
    String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            List<String> filteredCategories = _categories.where((category) {
              return category
                  .toLowerCase()
                  .contains(_categoryFilterController.text.toLowerCase());
            }).toList();

            filteredCategories.sort((a, b) {
              if (a == 'General') return -1;
              if (b == 'General') return 1;
              return a.compareTo(b);
            });

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(25.0)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Select Category',
                          style: appTextTheme.titleLarge?.copyWith(
                            color: AppColors.textColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _categoryFilterController,
                          decoration: _buildInputDecoration(
                            labelText: 'Search Categories',
                            prefixIcon: Icons.search,
                            appTextTheme: appTextTheme,
                          ),
                          style: appTextTheme.bodyLarge,
                          onChanged: (value) {
                            modalSetState(() {});
                          },
                        ),
                      ),
                      Expanded(
                        child: AnimationLimiter(
                          child: GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.5,
                            ),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
                              final category = filteredCategories[index];
                              final bool isSelected =
                                  category == _selectedCategory;
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                columnCount: 2,
                                duration: const Duration(milliseconds: 300),
                                child: ScaleAnimation(
                                  scale: 0.9,
                                  curve: Curves.easeOutBack,
                                  child: FadeInAnimation(
                                    child: ChoiceChip(
                                      label: Text(category),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          _categoryFilterController.clear();
                                          Navigator.pop(context, category);
                                        }
                                      },
                                      selectedColor:
                                          AppColors.primaryColor(context),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      labelStyle:
                                          appTextTheme.bodyMedium?.copyWith(
                                        color: isSelected
                                            ? AppColors.onPrimaryColor(context)
                                            : AppColors.onCardColor(context)
                                                .withOpacity(0.9),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppColors.primaryColor(context)
                                                .withOpacity(0.8)
                                            : Theme.of(context)
                                                .dividerColor
                                                .withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      elevation: isSelected ? 4 : 1,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (selected != null) {
      onCategorySelected(selected);
    }
  }

  // MODIFIED: _addOrUpdateItem now operates on the currentHikePlan from the StreamBuilder context
  void _addOrUpdateItem(
      {PackingListItem? itemToEdit,
      String? defaultCategory,
      required HikePlan currentHikePlan}) {
    _newItemNameController.text = itemToEdit?.name ?? '';
    _newItemQuantityController.text = (itemToEdit?.quantity ?? 1).toString();
    _selectedCategory = itemToEdit?.category ?? defaultCategory ?? 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final appTextTheme = _getAppTextTheme(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25.0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      itemToEdit == null ? 'Add New Item' : 'Edit Item',
                      style: appTextTheme.titleLarge?.copyWith(
                        color: AppColors.textColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _newItemNameController,
                      decoration: _buildInputDecoration(
                        labelText: 'Item Name',
                        appTextTheme: appTextTheme,
                      ),
                      style: appTextTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newItemQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        labelText: 'Quantity',
                        appTextTheme: appTextTheme,
                      ),
                      style: appTextTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        await _selectCategory(context, appTextTheme,
                            (newCategory) {
                          modalSetState(() {
                            _selectedCategory = newCategory;
                          });
                        });
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller:
                              TextEditingController(text: _selectedCategory),
                          decoration: _buildInputDecoration(
                            labelText: 'Category',
                            suffixIcon: Icon(Icons.arrow_forward_ios_rounded,
                                color: AppColors.subtleTextColor(context),
                                size: 20),
                            appTextTheme: appTextTheme,
                          ),
                          style: appTextTheme.bodyLarge,
                          readOnly: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_newItemNameController.text.trim().isEmpty) {
                          _scaffoldMessengerKey.currentState?.showSnackBar(
                            SnackBar(
                              content: const Text('Item name cannot be empty!'),
                              backgroundColor: AppColors.errorColor(context),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(10),
                            ),
                          );
                          return;
                        }
                        final int quantity =
                            int.tryParse(_newItemQuantityController.text) ?? 1;
                        if (quantity <= 0) {
                          _scaffoldMessengerKey.currentState?.showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Quantity must be at least 1!'),
                              backgroundColor: AppColors.errorColor(context),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(10),
                            ),
                          );
                          return;
                        }

                        String newItemId = itemToEdit?.id ?? const Uuid().v4();

                        final List<PackingListItem> updatedList =
                            List<PackingListItem>.from(
                                currentHikePlan.packingList);

                        if (itemToEdit == null) {
                          final newItem = PackingListItem(
                            id: newItemId,
                            name: _newItemNameController.text.trim(),
                            quantity: quantity,
                            category: _selectedCategory,
                            isPacked: false,
                          );
                          updatedList.add(newItem);
                        } else {
                          final int index = updatedList
                              .indexWhere((i) => i.id == itemToEdit.id);
                          if (index != -1) {
                            updatedList[index] = itemToEdit.copyWith(
                              name: _newItemNameController.text.trim(),
                              quantity: quantity,
                              category: _selectedCategory,
                            );
                          }
                        }
                        _updateHikePlan(
                            currentHikePlan.copyWith(packingList: updatedList),
                            newItemId);
                        _newItemNameController.clear();
                        _newItemQuantityController.clear();
                        Navigator.pop(context);
                      },
                      style: Theme.of(context)
                          .elevatedButtonTheme
                          .style
                          ?.copyWith(
                            backgroundColor: MaterialStateProperty.all(
                                AppColors.primaryColor(context)),
                            foregroundColor: MaterialStateProperty.all(
                                AppColors.onPrimaryColor(context)),
                            padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 16)),
                            shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            elevation: MaterialStateProperty.all(4),
                          ),
                      child: Text(
                        itemToEdit == null ? 'Add Item' : 'Save Changes',
                        style: appTextTheme.labelLarge?.copyWith(
                          color: AppColors.onPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (itemToEdit != null) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDeleteItem(itemToEdit, currentHikePlan);
                        },
                        style: Theme.of(context)
                            .textButtonTheme
                            .style
                            ?.copyWith(
                              foregroundColor: MaterialStateProperty.all(
                                  AppColors.errorColor(context)),
                              padding: MaterialStateProperty.all(
                                  const EdgeInsets.symmetric(vertical: 12)),
                              shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                            ),
                        child: Text(
                          'Delete Item',
                          style: appTextTheme.labelLarge?.copyWith(
                              color: AppColors.errorColor(context),
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteItem(
      PackingListItem itemToDelete, HikePlan currentHikePlan) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: Theme.of(context).dialogTheme.shape,
        title: Text('Delete Item?',
            style: Theme.of(context).dialogTheme.titleTextStyle),
        content: Text('Are you sure you want to delete "${itemToDelete.name}"?',
            style: Theme.of(context).dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: MaterialStateProperty.all(
                    AppColors.subtleTextColor(context))),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor:
                    MaterialStateProperty.all(AppColors.errorColor(context))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      print(
          'PackingListPage: Confirming deletion of item: ${itemToDelete.name}');
      final updatedList =
          List<PackingListItem>.from(currentHikePlan.packingList)
            ..removeWhere((item) => item.id == itemToDelete.id);
      _updateHikePlan(
          currentHikePlan.copyWith(packingList: updatedList), itemToDelete.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTextTheme = _getAppTextTheme(context);
    final theme = Theme.of(context);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: StreamBuilder<HikePlan?>(
        stream: _hikePlanService.getHikePlanStream(widget.planId),
        builder: (context, snapshot) {
          // If data is loading or null, show loading indicator.
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData ||
              snapshot.data == null) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: Text('Loading Packing List...',
                    style: appTextTheme.titleLarge),
                backgroundColor: theme.appBarTheme.backgroundColor,
                elevation: theme.appBarTheme.elevation,
                leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: theme.appBarTheme.foregroundColor),
                    onPressed: () => GoRouter.of(context).pop()),
              ),
              body: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryColor(context)),
              ),
            );
          }

          if (snapshot.hasError) {
            print('PackingListPage StreamBuilder Error: ${snapshot.error}');
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: Text('Error', style: appTextTheme.titleLarge),
                backgroundColor: theme.appBarTheme.backgroundColor,
                elevation: theme.appBarTheme.elevation,
                leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: theme.appBarTheme.foregroundColor),
                    onPressed: () => GoRouter.of(context).pop()),
              ),
              body: Center(
                child: Text('Failed to load packing list: ${snapshot.error}',
                    style: appTextTheme.bodyLarge
                        ?.copyWith(color: AppColors.errorColor(context))),
              ),
            );
          }

          final HikePlan currentHikePlan =
              snapshot.data!; // Use non-nullable as we handled null above

          // This logic ensures that if the stream returns an updated plan,
          // we re-evaluate the categories and their sorting.
          final List<PackingListItem> currentPackingList =
              currentHikePlan.packingList;

          final Map<String, List<PackingListItem>> groupedItems = {};
          for (var item in currentPackingList) {
            if (!groupedItems.containsKey(item.category)) {
              groupedItems[item.category] = [];
            }
            groupedItems[item.category]!.add(item);
          }

          final sortedCategories = groupedItems.keys.toList()
            ..sort((a, b) {
              if (a == 'General') return -1;
              if (b == 'General') return 1;
              return a.compareTo(b);
            });

          for (var category in sortedCategories) {
            groupedItems[category]!.sort((a, b) {
              if (a.isPacked && !b.isPacked) return 1;
              if (!a.isPacked && b.isPacked) return -1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          }

          final int totalItems = currentPackingList.length;
          final int packedItems =
              currentPackingList.where((item) => item.isPacked).length;
          final double progress =
              totalItems > 0 ? packedItems / totalItems : 0.0;

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: Text(
                'Packing List for ${currentHikePlan.hikeName}',
                style: appTextTheme.titleLarge?.copyWith(
                  color: theme.appBarTheme.titleTextStyle?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: theme.appBarTheme.backgroundColor,
              elevation: theme.appBarTheme.elevation ?? 0.5,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: theme.appBarTheme.foregroundColor),
                onPressed: () => GoRouter.of(context).pop(),
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Packing Progress',
                        style: appTextTheme.titleMedium?.copyWith(
                          color: AppColors.textColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$packedItems / $totalItems items packed',
                                  style: appTextTheme.bodyLarge?.copyWith(
                                    color: AppColors.textColor(context)
                                        .withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: appTextTheme.bodyLarge?.copyWith(
                                    color: AppColors.accentColor(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppColors.accentColor(context)
                                    .withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentColor(context),
                                ),
                                minHeight: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: totalItems == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.backpack_outlined,
                                    size: 60,
                                    color: AppColors.subtleTextColor(context)
                                        .withOpacity(0.4)),
                                const SizedBox(height: 20),
                                Text(
                                  "Your packing list is empty.\nTap the '+' button to add your first item!",
                                  textAlign: TextAlign.center,
                                  style: appTextTheme.titleMedium?.copyWith(
                                    color: AppColors.subtleTextColor(context),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : AnimationLimiter(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16.0, 0.0, 16.0, 90.0),
                            itemCount: sortedCategories.length,
                            itemBuilder: (context, categoryIndex) {
                              final category = sortedCategories[categoryIndex];
                              final itemsInCategory = groupedItems[category]!;
                              final packedInCategory = itemsInCategory
                                  .where((item) => item.isPacked)
                                  .length;
                              final totalInCategory = itemsInCategory.length;

                              return AnimationConfiguration.staggeredList(
                                position: categoryIndex,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: _buildCategoryExpansionTile(
                                      context,
                                      category,
                                      packedInCategory,
                                      totalInCategory,
                                      itemsInCategory,
                                      appTextTheme,
                                      theme,
                                      currentHikePlan,
                                    ),
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12.0),
                          ),
                        ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () =>
                  _addOrUpdateItem(currentHikePlan: currentHikePlan),
              label: Text(
                'Add New Item',
                style: appTextTheme.labelLarge?.copyWith(
                    color: theme.floatingActionButtonTheme.foregroundColor),
              ),
              icon: Icon(Icons.add_rounded,
                  color: theme.floatingActionButtonTheme.foregroundColor),
              backgroundColor: theme.floatingActionButtonTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }

  Widget _buildCategoryExpansionTile(
    BuildContext context,
    String category,
    int packedCount,
    int totalCount,
    List<PackingListItem> items,
    TextTheme appTextTheme,
    ThemeData theme,
    HikePlan currentHikePlan,
  ) {
    return Card(
      elevation: theme.cardTheme.elevation,
      shape: theme.cardTheme.shape,
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          '$category',
          style: appTextTheme.titleMedium?.copyWith(
            color: AppColors.primaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$packedCount / $totalCount items packed',
          style: appTextTheme.bodyMedium?.copyWith(
            color: AppColors.subtleTextColor(context),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(packedCount / (totalCount == 0 ? 1 : totalCount) * 100).toStringAsFixed(0)}%',
              style: appTextTheme.bodyMedium?.copyWith(
                color: AppColors.accentColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more_rounded,
              color: AppColors.subtleTextColor(context),
            ),
          ],
        ),
        children: [
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.6)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 8.0),
                    child: Text(
                      'No items in this category yet.',
                      style: appTextTheme.bodyMedium?.copyWith(
                        color: AppColors.subtleTextColor(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...items
                      .map((item) => _buildPackingListItem(
                          context, item, appTextTheme, currentHikePlan))
                      .toList(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _addOrUpdateItem(
                        defaultCategory: category,
                        currentHikePlan: currentHikePlan),
                    icon: Icon(Icons.add_circle_outline,
                        color: AppColors.accentColor(context)),
                    label: Text(
                      'Add item to $category',
                      style: appTextTheme.labelLarge?.copyWith(
                        color: AppColors.accentColor(context),
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackingListItem(BuildContext context, PackingListItem item,
      TextTheme appTextTheme, HikePlan currentHikePlan) {
    // Check if this item is currently in a pending update state
    final bool isPending = _pendingUpdates.containsKey(item.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isPending
              ? null
              : () => _togglePackedStatus(item, currentHikePlan),
          onLongPress: isPending
              ? null
              : () => _addOrUpdateItem(
                  itemToEdit: item, currentHikePlan: currentHikePlan),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedOpacity(
            opacity: isPending ? 0.5 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        item.isPacked
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: item.isPacked
                            ? AppColors.primaryColor(context)
                            : AppColors.subtleTextColor(context),
                        size: 24,
                      ),
                      if (isPending)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: AppColors.accentColor(context),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${item.quantity > 1 ? '${item.quantity}x ' : ''}${item.name}',
                      style: appTextTheme.bodyLarge?.copyWith(
                        color: item.isPacked
                            ? AppColors.subtleTextColor(context)
                                .withOpacity(0.7)
                            : AppColors.onCardColor(context),
                        decoration: item.isPacked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        fontWeight:
                            item.isPacked ? FontWeight.normal : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded,
                        color: AppColors.subtleTextColor(context), size: 22),
                    onPressed: isPending
                        ? null
                        : () => _addOrUpdateItem(
                            itemToEdit: item, currentHikePlan: currentHikePlan),
                    tooltip: 'Edit item',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
