// lib/pages/packing_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Varmista, että tämä on tarvittaessa lisätty
import 'package:uuid/uuid.dart'; // Lisätty Uuid

// Oletetaan, että AppColors on määritelty kuten aiemmissa esimerkeissäsi
// Esim. tiedostossa lib/pages/hike_plan_hub_page.dart tai keskitetysti
// Jos ei, kopioi AppColors-luokan määrittely tähän tai importtaa se.
// Tässä oletetaan, että se on saatavilla importtien kautta, esim.
// import 'hike_plan_hub_page.dart'; // Jos AppColors on siellä
// Tai parempi: import '../theme/app_colors.dart'; // Jos olet keskittänyt sen

// Paikallinen AppColors-määrittely, jos sitä ei ole keskitetty:
class AppColors {
  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color onPrimaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;
  static Color accentColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;
  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color cardColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color onCardColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color subtleTextColor(BuildContext context) =>
      Theme.of(context).hintColor;
  static Color errorColor(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  // ... (muut AppColors-määrittelyt)
}

// Tuodaan modelit (jos ne ovat eri tiedostossa)
// import '../models/hike_plan_model.dart'; // Tarvitaan HikePlan-viittausta varten
// import '../models/packing_list_models.dart'; // PackingListItem ja PackingListCategory

// Käytetään malleja suoraan tässä tiedostossa yksinkertaisuuden vuoksi tässä esimerkissä
class PackingListCategory {
  final String id;
  final String name;
  final IconData icon;
  final int order;

  PackingListCategory(
      {required this.id,
      required this.name,
      required this.icon,
      this.order = 0});
}

class PackingListItem {
  String id;
  String name;
  String categoryId;
  bool isPacked;
  int quantity;
  String? notes;

  PackingListItem({
    String? id,
    required this.name,
    required this.categoryId,
    this.isPacked = false,
    this.quantity = 1,
    this.notes,
  }) : this.id = id ?? const Uuid().v4();

  PackingListItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    bool? isPacked,
    int? quantity,
    String? notes,
  }) {
    return PackingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      isPacked: isPacked ?? this.isPacked,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}

List<PackingListCategory> defaultCategories = [
  PackingListCategory(
      id: 'essentials',
      name: 'Essentials & Safety',
      icon: Icons.health_and_safety_rounded,
      order: 0),
  PackingListCategory(
      id: 'gear',
      name: 'Gear & Equipment',
      icon: Icons.backpack_rounded,
      order: 1),
  PackingListCategory(
      id: 'clothes', name: 'Clothing', icon: Icons.checkroom_rounded, order: 2),
  PackingListCategory(
      id: 'sleeping',
      name: 'Sleep System',
      icon: Icons.king_bed_rounded,
      order: 3),
  PackingListCategory(
      id: 'cooking',
      name: 'Cooking & Kitchen',
      icon: Icons.outdoor_grill_rounded,
      order: 4),
  PackingListCategory(
      id: 'food',
      name: 'Food & Hydration',
      icon: Icons.restaurant_rounded,
      order: 5),
  PackingListCategory(
      id: 'hygiene',
      name: 'Hygiene & First Aid',
      icon: Icons.medical_services_rounded,
      order: 6),
  PackingListCategory(
      id: 'tools',
      name: 'Tools & Navigation',
      icon: Icons.explore_rounded,
      order: 7),
  PackingListCategory(
      id: 'personal',
      name: 'Personal Items',
      icon: Icons.person_search_rounded,
      order: 8),
  PackingListCategory(
      id: 'misc', name: 'Miscellaneous', icon: Icons.widgets_rounded, order: 9),
]..sort((a, b) => a.order.compareTo(b.order));

class PackingListPage extends StatefulWidget {
  // final HikePlan hikePlan; // Vastaanotetaan HikePlan, jotta tiedetään mihin vaellukseen lista liittyy
  const PackingListPage({
    super.key,
    /*required this.hikePlan*/ // Otetaan käyttöön, kun HikePlan-integraatio on valmis
  });

  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  List<PackingListItem> _items = []; // Tähän ladataan/tallennetaan tavarat
  Map<String, bool> _categoryExpandedState =
      {}; // Tallentaa kategorioiden avoin/kiinni-tilan

  // Dummy data for demonstration
  void _loadDummyData() {
    _items = [
      PackingListItem(
          categoryId: 'essentials', name: 'First Aid Kit', quantity: 1),
      PackingListItem(
          categoryId: 'essentials',
          name: 'Headlamp + Batteries',
          quantity: 1,
          isPacked: true),
      PackingListItem(
          categoryId: 'gear',
          name: 'Backpack 60L',
          quantity: 1,
          isPacked: true),
      PackingListItem(categoryId: 'gear', name: 'Trekking Poles', quantity: 1),
      PackingListItem(
          categoryId: 'clothes',
          name: 'Hiking Boots',
          quantity: 1,
          isPacked: true),
      PackingListItem(categoryId: 'clothes', name: 'Rain Jacket', quantity: 1),
      PackingListItem(categoryId: 'clothes', name: 'Warm Hat', quantity: 1),
      PackingListItem(
          categoryId: 'sleeping', name: 'Tent', quantity: 1, isPacked: true),
      PackingListItem(
          categoryId: 'sleeping', name: 'Sleeping Bag (-5°C)', quantity: 1),
      PackingListItem(
          categoryId: 'cooking', name: 'Portable Stove', quantity: 1),
      PackingListItem(
          categoryId: 'food', name: 'Trail Mix (500g)', quantity: 1),
    ];
    // Initialize expanded state for all categories (default to expanded or based on preference)
    for (var category in defaultCategories) {
      _categoryExpandedState[category.id] = true; // Default to expanded
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDummyData(); // Ladataan esimerkkidata
    // Myöhemmin: _loadItemsForHike(widget.hikePlan.id);
  }

  TextTheme _getAppTextTheme(BuildContext context) {
    final currentTheme = Theme.of(context);
    return GoogleFonts.latoTextTheme(currentTheme.textTheme).copyWith(
      headlineSmall:
          GoogleFonts.poppins(textStyle: currentTheme.textTheme.headlineSmall),
      titleLarge:
          GoogleFonts.poppins(textStyle: currentTheme.textTheme.titleLarge),
      titleMedium:
          GoogleFonts.poppins(textStyle: currentTheme.textTheme.titleMedium),
      bodyLarge: GoogleFonts.lato(textStyle: currentTheme.textTheme.bodyLarge),
      bodyMedium:
          GoogleFonts.lato(textStyle: currentTheme.textTheme.bodyMedium),
      labelLarge:
          GoogleFonts.poppins(textStyle: currentTheme.textTheme.labelLarge),
    );
  }

  void _toggleItemPacked(PackingListItem item) {
    setState(() {
      item.isPacked = !item.isPacked;
      // Myöhemmin: _packingListService.updateItem(item);
    });
  }

  void _addItem(String name, String categoryId, int quantity) {
    if (name.trim().isEmpty) return;
    setState(() {
      _items.add(PackingListItem(
        name: name.trim(),
        categoryId: categoryId,
        quantity: quantity > 0 ? quantity : 1,
      ));
      // Varmistetaan, että kategoria on auki uuden itemin lisäämisen jälkeen
      _categoryExpandedState[categoryId] = true;
      // Myöhemmin: _packingListService.addItem(newItem);
    });
  }

  void _removeItem(PackingListItem item) {
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
      // Myöhemmin: _packingListService.removeItem(item.id);
    });
  }

  void _showAddItemDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController quantityController =
        TextEditingController(text: '1');
    String selectedCategoryId = defaultCategories.first.id; // Oletuskategoria

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final appTextTheme = _getAppTextTheme(context);
        return StatefulBuilder(
            // Käytetään StatefulBuilderia, jotta dialogin sisällä oleva tila päivittyy (esim. dropdown)
            builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardColor(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add New Item',
                style: appTextTheme.titleLarge
                    ?.copyWith(color: AppColors.textColor(context))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      labelStyle: appTextTheme.bodyMedium
                          ?.copyWith(color: AppColors.subtleTextColor(context)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppColors.primaryColor(context)),
                      ),
                    ),
                    style: appTextTheme.bodyLarge
                        ?.copyWith(color: AppColors.textColor(context)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      labelStyle: appTextTheme.bodyMedium
                          ?.copyWith(color: AppColors.subtleTextColor(context)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppColors.primaryColor(context)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: appTextTheme.bodyLarge
                        ?.copyWith(color: AppColors.textColor(context)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: appTextTheme.bodyMedium
                          ?.copyWith(color: AppColors.subtleTextColor(context)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppColors.primaryColor(context)),
                      ),
                    ),
                    value: selectedCategoryId,
                    dropdownColor: AppColors.cardColor(context),
                    style: appTextTheme.bodyLarge
                        ?.copyWith(color: AppColors.textColor(context)),
                    items:
                        defaultCategories.map((PackingListCategory category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        child: Row(
                          children: [
                            Icon(category.icon,
                                size: 20,
                                color: AppColors.accentColor(context)),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          // Päivitetään dialogin tila StatefulBuilderin kautta
                          selectedCategoryId = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel',
                    style: appTextTheme.labelLarge
                        ?.copyWith(color: AppColors.subtleTextColor(context))),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text('Add Item', style: appTextTheme.labelLarge),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor(context),
                    foregroundColor: AppColors.onPrimaryColor(context),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () {
                  _addItem(
                    nameController.text,
                    selectedCategoryId,
                    int.tryParse(quantityController.text) ?? 1,
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTextTheme = _getAppTextTheme(context);
    final primaryColor = AppColors.primaryColor(context);
    final onPrimaryColor = AppColors.onPrimaryColor(context);
    final pageBackgroundColor = AppColors.backgroundColor(context);

    int totalItems = _items.length;
    int packedItems = _items.where((item) => item.isPacked).length;
    double progress = totalItems > 0 ? packedItems / totalItems : 0;

    return Theme(
      data: Theme.of(context).copyWith(textTheme: appTextTheme),
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          elevation: 2.0, // Subtle shadow for AppBar
          title: Text(
            'Packing List', // Myöhemmin: widget.hikePlan.hikeName
            style: appTextTheme.titleLarge?.copyWith(color: onPrimaryColor),
          ),
          actions: [
            // Tähän voi lisätä toimintoja, esim. "Tallenna malliksi"
            IconButton(
              icon: Icon(Icons.save_alt_rounded, color: onPrimaryColor),
              tooltip: 'Save as Template (Coming Soon)',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Save as Template: Coming soon!")));
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressHeader(
                context, packedItems, totalItems, progress, appTextTheme),
            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState(context, appTextTheme)
                  : AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 8.0),
                        itemCount: defaultCategories.length,
                        itemBuilder: (context, categoryIndex) {
                          final category = defaultCategories[categoryIndex];
                          final itemsInCategory = _items
                              .where((item) => item.categoryId == category.id)
                              .toList();

                          // Älä näytä kategoriaa, jos siinä ei ole yhtään itemiä EIKÄ se ole "Essentials" tms. tärkeä kategoria
                          // TAI jos kaikki kategoriat halutaan aina näyttää, poista tämä ehto.
                          // if (itemsInCategory.isEmpty && category.id != 'essentials') {
                          //   return const SizedBox.shrink();
                          // }

                          return AnimationConfiguration.staggeredList(
                            position: categoryIndex,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildCategoryTile(context, category,
                                    itemsInCategory, appTextTheme),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddItemDialog,
          backgroundColor:
              AppColors.accentColor(context), // Use accent color for FAB
          foregroundColor: AppColors.onPrimaryColor(
              context), // Assuming accent is dark enough for white text
          icon: const Icon(Icons.add_rounded),
          label: Text('Add Item',
              style: appTextTheme.labelLarge
                  ?.copyWith(color: AppColors.onPrimaryColor(context))),
          elevation: 4.0,
        ),
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context, int packedItems,
      int totalItems, double progress, TextTheme appTextTheme) {
    final primaryColor = AppColors.primaryColor(context);
    final cardColor = AppColors.cardColor(context); // For header background
    final onCardColor = AppColors.onCardColor(context);

    return Material(
      // Material for elevation
      elevation: 1.0, // Subtle elevation to lift it from the page gradient
      color:
          cardColor, // Use cardColor to make it distinct from AppBar but consistent with content cards
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: $packedItems / $totalItems Packed',
                  style: appTextTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: onCardColor),
                ),
                if (totalItems > 0 && packedItems == totalItems)
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade600, size: 28)
              ],
            ),
            const SizedBox(height: 8.0),
            if (totalItems > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: primaryColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  minHeight: 10.0,
                ),
              )
            else
              Text(
                "Your packing list is empty. Add some items!",
                style: appTextTheme.bodyMedium
                    ?.copyWith(color: AppColors.subtleTextColor(context)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, PackingListCategory category,
      List<PackingListItem> items, TextTheme appTextTheme) {
    final cardColor = AppColors.cardColor(context);
    final onCardColor = AppColors.onCardColor(context);
    final int packedInCategory = items.where((item) => item.isPacked).length;
    final bool isCategoryExpanded =
        _categoryExpandedState[category.id] ?? true; // Default to expanded

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      color: cardColor,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior:
          Clip.antiAlias, // Ensures ExpansionTile contents are clipped
      child: ExpansionTile(
        key: PageStorageKey<String>(
            category.id), // Maintain expanded state on scroll
        initiallyExpanded: isCategoryExpanded,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _categoryExpandedState[category.id] = expanded;
          });
        },
        backgroundColor: cardColor, // Match card color
        collapsedIconColor: AppColors.accentColor(context),
        iconColor: AppColors.primaryColor(context),
        leading: Icon(category.icon,
            color: AppColors.primaryColor(context), size: 26),
        title: Text(
          '${category.name} (${items.isNotEmpty ? "$packedInCategory/${items.length}" : "0"})',
          style: appTextTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: onCardColor),
        ),
        childrenPadding:
            const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
        children: items.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: Text(
                    "No items in this category yet. Add some!",
                    style: appTextTheme.bodyMedium?.copyWith(
                        color: AppColors.subtleTextColor(context),
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                )
              ]
            : items
                .map((item) =>
                    _buildPackingListItemWidget(context, item, appTextTheme))
                .toList(),
      ),
    );
  }

  Widget _buildPackingListItemWidget(
      BuildContext context, PackingListItem item, TextTheme appTextTheme) {
    final onCardColor = AppColors.onCardColor(context);
    final subtleOnCardColor = AppColors.subtleTextColor(context);
    final primaryColor = AppColors.primaryColor(context);

    return Material(
      // Wrap with Material for InkWell splash effect
      color: Colors
          .transparent, // Make Material transparent to show card background
      child: InkWell(
        onTap: () => _toggleItemPacked(item),
        onLongPress: () {
          // Example: Long press to show delete option
          showDialog(
              context: context,
              builder: (dContext) => AlertDialog(
                    title: Text("Remove Item?"),
                    content: Text("Do you want to remove '${item.name}'?"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dContext),
                          child: Text("Cancel")),
                      TextButton(
                          onPressed: () {
                            _removeItem(item);
                            Navigator.pop(dContext);
                          },
                          child: Text("Remove",
                              style: TextStyle(
                                  color: AppColors.errorColor(context)))),
                    ],
                  ));
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          child: Row(
            children: [
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: item.isPacked,
                  onChanged: (bool? value) {
                    _toggleItemPacked(item);
                  },
                  activeColor: primaryColor,
                  checkColor: AppColors.onPrimaryColor(
                      context), // Color of the check mark
                  side: BorderSide(
                    color: item.isPacked
                        ? primaryColor
                        : subtleOnCardColor.withOpacity(0.8),
                    width: 2.0,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: appTextTheme.bodyLarge?.copyWith(
                        color: item.isPacked ? subtleOnCardColor : onCardColor,
                        decoration: item.isPacked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: subtleOnCardColor.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.notes!,
                        style: appTextTheme.bodySmall?.copyWith(
                            color: subtleOnCardColor,
                            fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    ]
                  ],
                ),
              ),
              if (item.quantity > 1) ...[
                const SizedBox(width: 12.0),
                Text(
                  'x${item.quantity}',
                  style: appTextTheme.bodyMedium?.copyWith(
                    color: item.isPacked
                        ? subtleOnCardColor.withOpacity(0.7)
                        : onCardColor.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TextTheme appTextTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_outlined,
                size: 80.0, color: AppColors.subtleTextColor(context)),
            const SizedBox(height: 24.0),
            Text(
              'Your Packing List is Empty',
              style: appTextTheme.titleLarge
                  ?.copyWith(color: AppColors.textColor(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              'Start by adding items you need for your adventure using the (+) button below.',
              style: appTextTheme.bodyMedium
                  ?.copyWith(color: AppColors.subtleTextColor(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
