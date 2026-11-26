import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// Settings screen to reorder and show/hide "My space" sidebar destinations.
class SidebarEditorPage extends StatelessWidget {
  const SidebarEditorPage({super.key});

  void _save(BuildContext context, List<SidebarItemPreference> next) {
    final normalized = normalizeSidebarItems(next);
    final event = GeneralPreferencesChanged(
      (p) => p.copyWith(sidebarItems: normalized),
    );
    try {
      context.read<PreferencesBloc>().add(event);
    } on ProviderNotFoundException {
      Preferences.bloc?.add(event);
    }
  }

  List<SidebarItemPreference> _read(BuildContext context) {
    try {
      return context.select((PreferencesBloc b) => b.state.general.sidebarItems);
    } on ProviderNotFoundException {
      return Preferences.general.sidebarItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _read(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.Sidebar_Section_Profile),
        actions: [
          TextButton(
            onPressed: () => _save(context, defaultSidebarItems),
            child: Text(S.current.Reset),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          final updated = List<SidebarItemPreference>.of(items);
          if (newIndex > oldIndex) newIndex--;
          final moved = updated.removeAt(oldIndex);
          updated.insert(newIndex, moved);
          _save(context, updated);
        },
        itemBuilder: (context, index) {
          final pref = items[index];
          return Card(
            key: ValueKey(pref.item),
            elevation: 0,
            color: scheme.surfaceContainerLow,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: Icon(
                pref.item.icon,
                color: pref.visible
                    ? scheme.onSurfaceVariant
                    : scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              title: Text(
                pref.item.label,
                style: pref.visible
                    ? null
                    : TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: pref.visible ? S.current.Hide : S.current.Show,
                    icon: Icon(
                      pref.visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: pref.visible
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      final updated = List<SidebarItemPreference>.of(items);
                      updated[index] = pref.copyWith(visible: !pref.visible);
                      _save(context, updated);
                    },
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
