// lib/pages/packing_list_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/hike_plan_model.dart';
import '../models/packing_list_item.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';
import '../providers/auth_provider.dart';

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class PackingListPage extends StatefulWidget {
  final String planId;
  final HikePlan initialPlan;
  final String? userId; // Optional userId for viewing other users' lists

  const PackingListPage({
    super.key,
    required this.planId,
    required this.initialPlan,
    this.userId,
  });

  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage>
    with TickerProviderStateMixin {
  final HikePlanService _hikePlanService = HikePlanService();
  final TextEditingController _newItemNameController = TextEditingController();
  final TextEditingController _newItemQuantityController =
      TextEditingController();
  final TextEditingController _categoryFilterController =
      TextEditingController();
  String _selectedCategory = 'General';

  // MUUTETTU: Vain yksi pääkategorialista.
  final List<String> _packingCategories = const [
    'Shelter',
    'Food',
    'Clothing',
    'Tools',
    'Hygiene',
    'First Aid',
    'Bonus',
  ];

  Timer? _debounceTimer;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final ScrollController _scrollController;
  TabController? _tabController;
  
  // User-specific packing list
  List<PackingListItem> _userPackingList = [];
  late String _currentUserId;
  late bool _isOwnList;
  late bool _isGroupHike;
  String? _viewingUserName;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController =
        TabController(length: _packingCategories.length, vsync: this);
    
    // Determine if this is a group hike
    _isGroupHike = widget.initialPlan.collabOwnerId != null || 
                   widget.initialPlan.collaboratorIds.isNotEmpty;
    
    // Get current user ID
    final currentUser = FirebaseAuth.instance.currentUser;
    _currentUserId = widget.userId ?? currentUser?.uid ?? '';
    
    // Check if viewing own list
    _isOwnList = widget.userId == null || widget.userId == currentUser?.uid;
    
    // Load user-specific packing list if group hike
    if (_isGroupHike) {
      _loadUserPackingList();
      if (!_isOwnList && widget.userId != null) {
        _loadUserName(widget.userId!);
      }
    } else {
      // For individual hikes, use the plan's packing list
      _userPackingList = List.from(widget.initialPlan.packingList);
    }
  }

  @override
  void dispose() {
    _newItemNameController.dispose();
    _newItemQuantityController.dispose();
    _categoryFilterController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  // Aputoiminnot ja logiikka pysyvät ennallaan...
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

  Future<void> _loadUserPackingList() async {
    if (!_isGroupHike || _currentUserId.isEmpty) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('plans')
          .doc(widget.planId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['packingList'] != null) {
          setState(() {
            _userPackingList = (data['packingList'] as List<dynamic>)
                .map((item) => PackingListItem.fromMap(item as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading user packing list: $e');
    }
  }

  Future<void> _loadUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _viewingUserName = data?['displayName'] ?? data?['username'] ?? 'User';
        });
      }
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  Future<void> _updatePackingList({bool showSuccess = false}) async {
    print('PackingListPage: Updating packing list');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      try {
        if (_isGroupHike && _currentUserId.isNotEmpty) {
          // For group hikes, save to user's personal document
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .collection('plans')
              .doc(widget.planId)
              .set({
            'packingList': _userPackingList.map((item) => item.toMap()).toList(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // For individual hikes, update the main plan
          final updatedPlan = widget.initialPlan.copyWith(packingList: _userPackingList);
          await _hikePlanService.updateHikePlan(updatedPlan);
        }

        print('PackingListPage: Update successful');

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
        print('PackingListPage: Error during update: $e');
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

  void _onItemStatusChanged(
      PackingListItem item, bool newPackedStatus) {
    print(
        'PackingListPage: Status changed for item: ${item.name} to $newPackedStatus');

    setState(() {
      _userPackingList = _userPackingList.map((i) {
        return i.id == item.id ? i.copyWith(isPacked: newPackedStatus) : i;
      }).toList();
    });

    _updatePackingList();
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
            List<String> filteredCategories =
                _packingCategories.where((category) {
              return category
                  .toLowerCase()
                  .contains(_categoryFilterController.text.toLowerCase());
            }).toList();

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
                        child: Text('Select Category',
                            style: appTextTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
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
                          onChanged: (value) => modalSetState(() {}),
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
                              childAspectRatio: 2.8,
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
                                            : AppColors.onCardColor(context),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppColors.primaryColor(context)
                                            : Theme.of(context)
                                                .dividerColor
                                                .withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
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

  void _addOrUpdateItem(
      {PackingListItem? itemToEdit,
      String? defaultCategory}) {
    
    // Don't allow editing if viewing someone else's list
    if (!_isOwnList) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can only edit your own packing list', 
              style: GoogleFonts.lato()),
          backgroundColor: AppColors.errorColor(context),
        ),
      );
      return;
    }
    _newItemNameController.text = itemToEdit?.name ?? '';
    _newItemQuantityController.text = (itemToEdit?.quantity ?? 1).toString();
    _selectedCategory = itemToEdit?.category ?? defaultCategory ?? 'Bonus';

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
                      style: appTextTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _newItemNameController,
                      decoration: _buildInputDecoration(
                          labelText: 'Item Name', appTextTheme: appTextTheme),
                      style: appTextTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newItemQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                          labelText: 'Quantity', appTextTheme: appTextTheme),
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
                            suffixIcon: const Icon(
                                Icons.arrow_forward_ios_rounded,
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
                        if (_newItemNameController.text.trim().isEmpty) return;
                        final int quantity =
                            int.tryParse(_newItemQuantityController.text) ?? 1;
                        if (quantity <= 0) return;

                        String newItemId = itemToEdit?.id ?? const Uuid().v4();

                        setState(() {
                          if (itemToEdit == null) {
                            _userPackingList.add(PackingListItem(
                              id: newItemId,
                              name: _newItemNameController.text.trim(),
                              quantity: quantity,
                              category: _selectedCategory,
                              isPacked: false,
                            ));
                          } else {
                            final int index = _userPackingList
                                .indexWhere((i) => i.id == itemToEdit.id);
                            if (index != -1) {
                              _userPackingList[index] = itemToEdit.copyWith(
                                name: _newItemNameController.text.trim(),
                                quantity: quantity,
                                category: _selectedCategory,
                              );
                            }
                          }
                        });
                        
                        _updatePackingList(showSuccess: true);
                        _newItemNameController.clear();
                        _newItemQuantityController.clear();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor(context),
                        foregroundColor: AppColors.onPrimaryColor(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        itemToEdit == null ? 'Add Item' : 'Save Changes',
                        style: appTextTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (itemToEdit != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDeleteItem(itemToEdit);
                        },
                        child: Text(
                          'Delete Item',
                          style: appTextTheme.labelLarge?.copyWith(
                              color: AppColors.errorColor(context),
                              fontSize: 14),
                        ),
                      ),
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
      PackingListItem itemToDelete) async {
    
    // Don't allow deleting if viewing someone else's list
    if (!_isOwnList) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can only edit your own packing list', 
              style: GoogleFonts.lato()),
          backgroundColor: AppColors.errorColor(context),
        ),
      );
      return;
    }
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
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.errorColor(context)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _userPackingList.removeWhere((item) => item.id == itemToDelete.id);
      });
      _updatePackingList(showSuccess: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTextTheme = _getAppTextTheme(context);
    final theme = Theme.of(context);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(context),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorWeight: 3.0,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.hintColor,
                  labelStyle:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  tabs: _packingCategories
                      .map((category) => Tab(text: category))
                      .toList(),
                ),
              ),
              pinned: true,
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: _packingCategories
                    .map((category) => _buildCategoryPage(context, category))
                    .toList(),
              ),
            )
          ],
        ),
        floatingActionButton: _isOwnList
            ? FloatingActionButton.extended(
                onPressed: () {
                  final currentCategory =
                      _packingCategories[_tabController!.index];
                  _addOrUpdateItem(defaultCategory: currentCategory);
                },
                label: Text('Add Item',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                icon: const Icon(Icons.add_rounded),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }

          Widget _buildCategoryPage(BuildContext context, String category) {
    final items = _userPackingList.where((item) => item.category == category).toList();
    items.sort((a, b) {
      if (a.isPacked && !b.isPacked) return 1;
      if (!a.isPacked && b.isPacked) return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (items.isEmpty) {
      return _buildEmptySectionPlaceholder(context,
          'No items in "$category" yet.', _getIconForCategory(category));
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
              child: _buildPackingListItem(
              context, item, _getAppTextTheme(context)),
              ),
            ),
          );
        },
      ),
    );
  }

  // POISTETTU: _buildMoreCategoriesPage on poistettu tarpeettomana.
  // ...

  // POISTETTU: _buildCategoryHeader on poistettu, koska sen toiminnallisuus
  // on nyt integroitu suoraan _buildCategoryPage-näkymään (tyhjän tilan osalta)
  // ja TabBar hoitaa navigoinnin.
  // ...

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'shelter':
        return Icons.holiday_village_rounded;
      case 'cooking':
        return Icons.outdoor_grill_rounded;
      case 'Tools':
        return Icons.explore_rounded;
      case 'first aid':
        return Icons.medical_services_rounded;
      case 'hygiene':
        return Icons.sanitizer_rounded;
      case 'tools':
        return Icons.construction_rounded;
      case 'electronics':
        return Icons.camera_alt_rounded;
      case 'food':
        return Icons.fastfood_rounded;
      case 'bonus':
        return Icons.star_border_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    const double expandedHeight = 400.0;

    final totalItems = _userPackingList.length;
    final packedItems = _userPackingList.where((i) => i.isPacked).length;
    final progress = totalItems > 0 ? packedItems / totalItems : 0.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => GoRouter.of(context).pop(),
      ),
      title: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final showTitle = _scrollController.hasClients &&
              _scrollController.offset > expandedHeight - kToolbarHeight - 20;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showTitle ? 1.0 : 0.0,
            child: Text(
              'Packing List',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface),
            ),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                return Container(
                  color: theme.colorScheme.surface.withOpacity(
                      (_scrollController.hasClients &&
                              _scrollController.offset > 0
                          ? (_scrollController.offset / expandedHeight)
                              .clamp(0.0, 0.6)
                          : 0.0)),
                  child: child,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: kToolbarHeight),
                  CircularPercentIndicator(
                    animateFromLastPercent: true,
                    animationDuration: 400,
                    radius: 50.0,
                    lineWidth: 9.0,
                    percent: progress,
                    center: Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: theme.colorScheme.primary,
                        )),
                    progressColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Text(
                          widget.initialPlan.hikeName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (!_isOwnList && _viewingUserName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Viewing $_viewingUserName\'s list',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$packedItems of $totalItems packed',
                    style:
                        GoogleFonts.lato(fontSize: 16, color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(
      BuildContext context, String message, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: theme.hintColor.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 17,
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackingListItem(BuildContext context, PackingListItem item,
      TextTheme appTextTheme) {
    return _OptimizedPackingListItem(
      key: ValueKey(item.id),
      item: item,
      appTextTheme: appTextTheme,
      onStatusChanged: (newStatus) {
        if (_isOwnList) {
          _onItemStatusChanged(item, newStatus);
        }
      },
      onEdit: () {
        if (_isOwnList) {
          _addOrUpdateItem(itemToEdit: item);
        }
      },
      isEditable: _isOwnList,
    );
  }
}

class _OptimizedPackingListItem extends StatefulWidget {
  final PackingListItem item;
  final TextTheme appTextTheme;
  final VoidCallback onEdit;
  final ValueChanged<bool> onStatusChanged;
  final bool isEditable;

  const _OptimizedPackingListItem({
    super.key,
    required this.item,
    required this.appTextTheme,
    required this.onEdit,
    required this.onStatusChanged,
    this.isEditable = true,
  });

  @override
  State<_OptimizedPackingListItem> createState() =>
      _OptimizedPackingListItemState();
}

class _OptimizedPackingListItemState extends State<_OptimizedPackingListItem> {
  late bool _localIsPacked;
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _localIsPacked = widget.item.isPacked;
  }

  @override
  void didUpdateWidget(covariant _OptimizedPackingListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.isPacked != _localIsPacked && !_isPending) {
      setState(() {
        _localIsPacked = widget.item.isPacked;
      });
    }
  }

  Future<void> _handleTap() async {
    setState(() {
      _localIsPacked = !_localIsPacked;
      _isPending = true;
    });

    widget.onStatusChanged(_localIsPacked);

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isPending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: _localIsPacked ? 0.5 : 2.5,
      shadowColor: _localIsPacked
          ? Colors.transparent
          : theme.shadowColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: _localIsPacked
                  ? theme.dividerColor.withOpacity(0.5)
                  : Colors.transparent,
              width: 1)),
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: InkWell(
        onTap: widget.isEditable && !_isPending ? _handleTap : null,
        onLongPress: widget.isEditable && !_isPending ? widget.onEdit : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          opacity: _isPending ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Checkbox(
                      value: _localIsPacked,
                      onChanged: widget.isEditable ? (value) => _handleTap() : null,
                      activeColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    if (_isPending)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.accentColor(context),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.item.quantity > 1 ? '${widget.item.quantity}x ' : ''}${widget.item.name}',
                    style: widget.appTextTheme.bodyLarge?.copyWith(
                      color: _localIsPacked
                          ? theme.hintColor
                          : theme.colorScheme.onSurface,
                      decoration: _localIsPacked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: theme.hintColor,
                      fontWeight:
                          _localIsPacked ? FontWeight.normal : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isEditable)
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded,
                        color: theme.hintColor, size: 24),
                    onPressed: _isPending ? null : widget.onEdit,
                    tooltip: 'Edit item',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
