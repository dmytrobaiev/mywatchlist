import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/json_read.dart';

/// Destinations shown under "My space" in the app sidebar, in their default
/// order (matching `master`: profile shortcuts, bookmarks, calendar, then MAL
/// notifications and messages).
enum SidebarItem {
  stats,
  about,
  friends,
  clubs,
  favorites,
  history,
  bookmarks,
  calendar,
  notifications,
  messages,
}

extension SidebarItemInfo on SidebarItem {
  String get label {
    final s = S.current;
    return switch (this) {
      SidebarItem.stats => s.Prof_Tab_Stats,
      SidebarItem.about => s.Prof_Tab_About,
      SidebarItem.friends => s.Prof_Tab_Friends,
      SidebarItem.clubs => s.Prof_Tab_Clubs,
      SidebarItem.favorites => s.Prof_Tab_Favorites,
      SidebarItem.history => s.Prof_Tab_History,
      SidebarItem.bookmarks => s.Bookmarks,
      SidebarItem.calendar => s.AnimeCalendar,
      SidebarItem.notifications => s.Mn_Title,
      SidebarItem.messages => s.Pm_Title,
    };
  }

  IconData get icon => switch (this) {
        SidebarItem.stats => Icons.stacked_bar_chart_rounded,
        SidebarItem.about => Icons.info_outline,
        SidebarItem.friends => Icons.people_alt_outlined,
        SidebarItem.clubs => Icons.castle_outlined,
        SidebarItem.favorites => Icons.favorite_outline,
        SidebarItem.history => Icons.history_rounded,
        SidebarItem.bookmarks => Icons.bookmark_outline,
        SidebarItem.calendar => Icons.calendar_month_outlined,
        SidebarItem.notifications => Icons.notifications_outlined,
        SidebarItem.messages => Icons.mail_outline_rounded,
      };
}

/// One row in the user's saved sidebar order.
class SidebarItemPreference extends Equatable {
  final SidebarItem item;
  final bool visible;

  const SidebarItemPreference(this.item, {this.visible = true});

  SidebarItemPreference copyWith({bool? visible}) =>
      SidebarItemPreference(item, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {
        'item': item.name,
        'visible': visible,
      };

  static SidebarItemPreference? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final name = map['item'];
    if (name is! String) return null;
    final item = SidebarItem.values.where((e) => e.name == name).firstOrNull;
    if (item == null) return null;
    final visible = readBool(map, 'visible', true);
    return SidebarItemPreference(item, visible: visible);
  }

  @override
  List<Object?> get props => [item, visible];
}

/// Default "My space" sidebar items in `master`'s order, all visible.
const List<SidebarItemPreference> defaultSidebarItems = [
  SidebarItemPreference(SidebarItem.stats),
  SidebarItemPreference(SidebarItem.about),
  SidebarItemPreference(SidebarItem.friends),
  SidebarItemPreference(SidebarItem.clubs),
  SidebarItemPreference(SidebarItem.favorites),
  SidebarItemPreference(SidebarItem.history),
  SidebarItemPreference(SidebarItem.bookmarks),
  SidebarItemPreference(SidebarItem.calendar),
  SidebarItemPreference(SidebarItem.notifications),
  SidebarItemPreference(SidebarItem.messages),
];

/// Ensures every [SidebarItem] appears exactly once, preserving saved order
/// and appending any newly added items at the end.
List<SidebarItemPreference> normalizeSidebarItems(
  Iterable<SidebarItemPreference> items,
) {
  final seen = <SidebarItem>{};
  final result = <SidebarItemPreference>[];
  for (final pref in items) {
    if (seen.add(pref.item)) result.add(pref);
  }
  for (final def in defaultSidebarItems) {
    if (seen.add(def.item)) result.add(def);
  }
  return List.unmodifiable(result);
}

List<SidebarItemPreference> decodeSidebarItems(Object? raw) {
  if (raw is! List) return defaultSidebarItems;
  final parsed = <SidebarItemPreference>[];
  for (final entry in raw) {
    final pref = SidebarItemPreference.fromJson(entry);
    if (pref != null) parsed.add(pref);
  }
  return normalizeSidebarItems(parsed);
}

List<Map<String, dynamic>> encodeSidebarItems(List<SidebarItemPreference> items) =>
    [for (final item in items) item.toJson()];
