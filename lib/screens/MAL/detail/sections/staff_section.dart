import 'package:flutter/widgets.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/screens/MAL/characters_staff_screen.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/home/animecharacterwidget.dart';

/// Anime staff; arrow opens the staff tab of the full cast screen.
DetailSection? staffSection(DetailData data) {
  if (data.isManga || data.staff.isEmpty) return null;
  void openAll(BuildContext context) => gotoPage(
        context: context,
        newPage: CharactersStaffScreen(
          id: data.id,
          category: data.category,
          initialTab: 1,
        ),
      );
  return DetailSection(
    TabType.Staff,
    Builder(
      builder: (context) => AnimeCharacterWidget(
        staffList: data.staff,
        horizPadding: detailHorizPadding,
        onViewAll: () => openAll(context),
      ),
    ),
    onViewAll: openAll,
  );
}
