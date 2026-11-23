import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';

/// Full list of recommended titles for an anime or manga, rendered in the same
/// Search-style list/grid layout ([MediaTile] / [AnimeGridCard]), with user
/// recommendation comments accessible from the AppBar action.
class RecommendationsListPage extends StatefulWidget {
  final int id;
  final String category;
  final List<Recommendation> recommendations;

  const RecommendationsListPage({
    super.key,
    required this.id,
    required this.category,
    required this.recommendations,
  });

  @override
  State<RecommendationsListPage> createState() => _RecommendationsListPageState();
}

class _RecommendationsListPageState extends State<RecommendationsListPage> {
  bool _grid = false;

  void _openComments() {
    gotoPage(
      context: context,
      newPage: Scaffold(
        appBar: AppBar(title: Text(S.current.Recommendations)),
        body: ContentFullRecommendation(id: widget.id, category: widget.category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.recommendations;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          S.current.Recommendations,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            visualDensity: VisualDensity.compact,
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          IconButton(
            tooltip: S.current.Edit_Comments,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.comment_outlined),
            onPressed: _openComments,
          ),
        ],
      ),
      body: _grid ? _buildGrid(items) : _buildList(items),
    );
  }

  Widget _buildList(List<Recommendation> items) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final rec = items[index];
        final count = rec.numRecommendations;
        return MediaTile(
          item: rec.animenode,
          category: widget.category,
          size: MediaTileSize.compact,
          showEdit: true,
          thumbOverlay: count > 0
              ? PositionedDirectional(
                  bottom: 2,
                  end: 2,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildGrid(List<Recommendation> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final rec = items[index];
        return AnimeGridCard(
          node: rec.animenode,
          category: widget.category,
          displaySubType: DisplaySubType.compact,
          showMemberCount: true,
          onTap: () => AppRoutes.push(
            context,
            ContentDetailedScreen(node: rec.animenode, category: widget.category),
          ),
        );
      },
    );
  }
}
