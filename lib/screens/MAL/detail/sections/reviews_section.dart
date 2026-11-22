import 'package:flutter/widgets.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart';
import 'package:mywatchlist/widgets/MAL/review/reviews_list_screen.dart';

/// User reviews (loaded by the widget itself); the arrow and trailing card open
/// every review in one vertical list, as DailyAL.
DetailSection? reviewsSection(DetailData data) {
  if (!data.hasContent) return null;
  void openAll(BuildContext context) => gotoPage(
        context: context,
        newPage: ReviewsListScreen(id: data.id, category: data.category),
      );
  return DetailSection(
    TabType.Reviews,
    Builder(
      builder: (context) => ShowAnimeReviews(
        animeId: data.id,
        category: data.category,
        onViewAll: () => openAll(context),
      ),
    ),
    onViewAll: openAll,
  );
}
