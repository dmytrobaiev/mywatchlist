import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart'
    as mal_status;
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart'
    as mal_manga_status;
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/cross_tracker_widget.dart';

/// MAL list status the user just saved, so the cross-tracker panel follows
/// an edit at once (before the details reload).
@immutable
class LiveListStatus {
  final String? status;
  final int? score;
  final int? progress;

  const LiveListStatus({this.status, this.score, this.progress});

  /// From the object `ContentEditWidget.onListStatusChange` reports.
  static LiveListStatus? from(dynamic status) {
    if (status is mal_status.MyAnimeListStatus) {
      return LiveListStatus(
        status: status.status,
        score: status.score,
        progress: status.numEpisodesWatched,
      );
    }
    if (status is mal_manga_status.MyMangaListStatus) {
      return LiveListStatus(
        status: status.status,
        score: status.score,
        progress: status.numChaptersRead,
      );
    }
    return null;
  }
}

/// Edit panel for the detail page: the list editor, then the cross-tracker
/// sync when other trackers are signed in. Uses a single scrollable when
/// hosted in a draggable sheet ([scrollController] provided).
class DetailEditPanel extends StatelessWidget {
  final DetailData data;
  final bool showCrossTracker;
  final LiveListStatus? live;
  final ValueChanged<bool> onUpdate;
  final ValueChanged<LiveListStatus> onLiveStatus;
  final VoidCallback onDelete;

  /// Closes the panel.
  final VoidCallback? onClose;

  /// Sheet scroll controller when hosted inside [QuickEditModalSheet].
  final ScrollController? scrollController;

  /// Synced expansion state when hosted inside [QuickEditModalSheet].
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// Whether manual swipe detection is active (off inside a draggable sheet).
  final bool enableSwipe;

  const DetailEditPanel({
    super.key,
    required this.data,
    required this.showCrossTracker,
    required this.live,
    required this.onUpdate,
    required this.onLiveStatus,
    required this.onDelete,
    this.onClose,
    this.scrollController,
    this.expanded,
    this.onExpandedChanged,
    this.enableSwipe = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = data.content;
    final saved = content?.myListStatus;
    final body = SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentEditWidget(
            id: data.id,
            contentDetailed: content,
            category: data.category,
            onUpdate: onUpdate,
            onListStatusChange: (status) {
              final value = LiveListStatus.from(status);
              if (value != null) onLiveStatus(value);
            },
            onDelete: onDelete,
            onDismiss: onClose,
            enableSwipe: enableSwipe,
            expanded: expanded,
            onExpandedChanged: onExpandedChanged,
          ),
          if (showCrossTracker)
            CrossTrackerWidget(
              malId: data.id,
              title: content?.title ?? '',
              category: data.category,
              malStatus: live?.status ?? saved?.status,
              malScore: live?.score ?? saved?.score,
              // The MAL manga list status has no parsed chapter count yet.
              malProgress: live?.progress ??
                  (data.isAnime ? saved?.numEpisodesWatched : null),
            ),
        ],
      ),
    );
    if (scrollController != null) return body;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: body,
    );
  }
}
