// lib/widgets/select_visibility_modal.dart
import 'package:flutter/material.dart';
import '../models/post_model.dart';

class SelectVisibilityModal extends StatelessWidget {
  final Function(PostVisibility) onVisibilitySelectedCallback;

  const SelectVisibilityModal(
      {super.key, required this.onVisibilitySelectedCallback});

  Widget _buildVisibilityOption(
      BuildContext tileContext,
      IconData icon,
      String title,
      String subtitle,
      PostVisibility visibilityValue,
      Color iconColor) {
    final theme = Theme.of(tileContext);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.15),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
      onTap: () {
        onVisibilitySelectedCallback(visibilityValue);
      },
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: theme.colorScheme.primary.withOpacity(0.05),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(
          top: 20.0, left: 16.0, right: 16.0, bottom: 16.0),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ]),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
              child: Text(
                'Valitse postauksen näkyvyys',
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
              ),
            ),
            const SizedBox(height: 16),
            _buildVisibilityOption(
              context,
              Icons.public,
              'Julkinen',
              'Näkyy kaikille käyttäjille.',
              PostVisibility.public,
              theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            _buildVisibilityOption(
              context,
              Icons.group_outlined,
              'Ystävät',
              'Näkyy vain ystävillesi.',
              PostVisibility.friends,
              theme.colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            _buildVisibilityOption(
              context,
              Icons.lock_outline,
              'Yksityinen',
              'Näkyy vain sinulle itsellesi.',
              PostVisibility.private,
              Colors.grey.shade500,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

void showSelectVisibilityModal(BuildContext homePageContext,
    Function(PostVisibility) onVisibilitySelectedFromHomePage) {
  showModalBottomSheet<PostVisibility>(
    context: homePageContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext modalSheetContext) {
      return SelectVisibilityModal(
        onVisibilitySelectedCallback: (selectedVisibilityByModal) {
          Navigator.pop(modalSheetContext, selectedVisibilityByModal);
        },
      );
    },
  ).then((selectedVisibilityReturnedFromModal) {
    if (selectedVisibilityReturnedFromModal != null) {
      onVisibilitySelectedFromHomePage(selectedVisibilityReturnedFromModal);
    }
  }).catchError((error) {
    // Voit halutessasi käsitellä virheen tässä, esim. näyttämällä SnackBarin
    print('Error in showModalBottomSheet: $error');
  });
}
