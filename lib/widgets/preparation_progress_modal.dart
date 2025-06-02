// lib/widgets/preparation_progress_modal.dart
import 'package:flutter/material.dart';
import '../models/hike_plan_model.dart'; // Tuo HikePlan ja PrepItemKeys

class PreparationProgressModal extends StatefulWidget {
  final HikePlan initialPlan;

  const PreparationProgressModal({super.key, required this.initialPlan});

  @override
  State<PreparationProgressModal> createState() =>
      _PreparationProgressModalState();
}

class _PreparationProgressModalState extends State<PreparationProgressModal> {
  late Map<String, bool> _currentPreparationItems;

  @override
  void initState() {
    super.initState();
    // Tehdään kopio, jotta alkuperäistä objektia ei muuteta suoraan ennen tallennusta
    _currentPreparationItems =
        Map<String, bool>.from(widget.initialPlan.preparationItems);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPrepKeys = PrepItemKeys.allKeys;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Merkitse valmistelut tehdyiksi',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 20),
          Flexible(
            // Estää ylivuodon, jos kohteita on paljon
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allPrepKeys.length,
              itemBuilder: (context, index) {
                final itemKey = allPrepKeys[index];
                final itemName = PrepItemKeys.getDisplayName(itemKey);
                return CheckboxListTile(
                  title: Text(itemName, style: theme.textTheme.bodyLarge),
                  value: _currentPreparationItems[itemKey] ?? false,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _currentPreparationItems[itemKey] = value;
                      });
                    }
                  },
                  activeColor: theme.colorScheme.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Tallenna edistyminen'),
            onPressed: () {
              // Palauta päivitetyt tiedot kutsujalle
              Navigator.of(context).pop(_currentPreparationItems);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            child: const Text('Peruuta'),
            onPressed: () =>
                Navigator.of(context).pop(), // Sulje modaali ilman muutoksia
          ),
        ],
      ),
    );
  }
}

// Helper-funktio modaalin näyttämiseen
Future<Map<String, bool>?> showPreparationProgressModal(
    BuildContext context, HikePlan plan) {
  return showModalBottomSheet<Map<String, bool>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext modalContext) {
      return Padding(
        // Lisätään padding näppäimistön varalle, jos modaali venyisi
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom),
        child: PreparationProgressModal(initialPlan: plan),
      );
    },
  );
}
