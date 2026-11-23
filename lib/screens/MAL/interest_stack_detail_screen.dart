import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/user/list/list_status_pill.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Size of an entry cover, DailyAL's 100 x 150; the loading skeleton uses the same.
const double stackCoverWidth = 100;
const double stackCoverHeight = 150;

/// MyAnimeList writes stack dates in English ("Oct 27 2026, 1:37 AM"). Reads one (a leading
/// "Created"/"Updated" is ignored) and writes it in [locale]; anything unreadable comes back as is.
@visibleForTesting
String formatStackDate(String raw, String locale) {
  final match = _stackDate.firstMatch(raw);
  if (match == null) return raw.trim();
  final month = _months.indexOf(match.group(1)!.toLowerCase()) + 1;
  if (month == 0) return raw.trim();
  final day = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final hourText = match.group(4);
  try {
    if (hourText == null) return DateFormat.yMMMd(locale).format(DateTime(year, month, day));
    var hour = int.parse(hourText) % 12;
    if (match.group(6)!.toUpperCase() == 'PM') hour += 12;
    return DateFormat.yMMMd(locale).add_jm().format(DateTime(year, month, day, hour, int.parse(match.group(5)!)));
  } on Object {
    return raw.trim();
  }
}

final RegExp _stackDate = RegExp(
    r'([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})(?:,?\s+(\d{1,2}):(\d{2})\s*([AaPp][Mm]))?');
const List<String> _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

class InterestStackDetailScreen extends StatefulWidget {
  final InterestStack stack;

  const InterestStackDetailScreen({
    super.key,
    required this.stack,
  });

  @override
  State<InterestStackDetailScreen> createState() =>
      _InterestStackDetailScreenState();
}

class _InterestStackDetailScreenState extends State<InterestStackDetailScreen> {
  Map<String, dynamic>? _detailedData;
  bool _isLoading = true;
  String? _error;

  static const horizPadding = 25.0;
  static const padding = EdgeInsets.symmetric(horizontal: horizPadding);

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final stackId = _extractStackId(widget.stack.url);
      if (stackId != null) {
        final data = await MwlApi.i.getInterestStackDetail(stackId);
        if (mounted) {
          setState(() {
            _detailedData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int? _extractStackId(String? url) {
    if (url == null) return null;
    final match = RegExp(r'/stacks/(\d+)').firstMatch(url);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // --- Data accessors ---

  /// The title exactly as MyAnimeList writes it (no case change).
  String get _title {
    final fetched = _detailedData?['title']?.toString().trim();
    if (fetched != null && fetched.isNotEmpty) return fetched;
    final listed = widget.stack.title?.trim();
    if (listed != null && listed.isNotEmpty) return listed;
    return S.current.Social_Stack_Title;
  }

  List<Map<String, dynamic>> get _entries =>
      (_detailedData?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<InterestStack> get _similarStacks =>
      (_detailedData?['similarStacks'] as List?)
          ?.map((e) => InterestStack.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
      [];

  List<InterestStack> get _malStacks =>
      (_detailedData?['myAnimeListStacks'] as List?)
          ?.map((e) => InterestStack.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
      [];

  bool get _hasEntries => _entries.isNotEmpty;
  bool get _hasSimilar => _similarStacks.isNotEmpty;
  bool get _hasMalStacks => _malStacks.isNotEmpty;
  bool get _showTabs => _hasEntries || _hasSimilar || _hasMalStacks;

  List<String> get _tabs => [
        if (_hasEntries) S.current.Social_Stack_Tab_Entries,
        if (_hasSimilar) S.current.Social_Stack_Tab_Similar,
        if (_hasMalStacks) S.current.Social_Stack_Tab_Mal,
      ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: ShimmerColor(_buildShell(context)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: _buildErrorState(Theme.of(context)),
      );
    }

    if (_detailedData == null || !_showTabs) {
      return Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) =>
              _topSlivers(context, innerBoxIsScrolled),
          body: _buildNoContentFallback(Theme.of(context)),
        ),
      );
    }

    return Scaffold(
      body: DefaultTabController(
        length: _tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) =>
              _topSlivers(context, innerBoxIsScrolled),
          body: _bodyWidget(),
        ),
      ),
    );
  }

  // --- Collapsing app bar (matches FeaturedScreen / News detail header logic) ---

  Widget _appBarSliver(BuildContext context, bool innerBoxIsScrolled) {
    final url = _webUrl;
    final canShare = !_isLoading && _error == null;
    final hasTabs = _showTabs && _tabs.length > 1;
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: hasTabs ? 300 : 252,
      title: innerBoxIsScrolled
          ? Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      actions: [
        if (canShare && _stackId != null)
          BookmarkButton(
            tracker: 'myanimelist',
            kind: BookmarkKind.interestStack,
            id: _stackId!,
            title: _title,
            imageUrl: _coverUrl,
            subtitle: widget.stack.username,
          ),
        if (canShare)
          AppBarMenu(
            onShare: () => showShareBuilder(
              context,
              fields: stackShareFields(
                url: url,
                title: _title,
                author: widget.stack.username,
                entries: [for (final e in _entries) if (e['title'] is String) e['title'] as String],
                description: _description,
              ),
              subject: _title,
              title: S.current.Social_Stack_Title,
            ),
            onOpenInBrowser: url == null ? null : () => openInBrowser(context, url),
          ),
      ],
      flexibleSpace: _headerWidget(context, hasTabs: hasTabs),
      bottom: hasTabs
          ? TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final e in _tabs) Tab(text: e)],
            )
          : null,
    );
  }

  Widget _headerWidget(BuildContext context, {required bool hasTabs}) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final locale = Localizations.localeOf(context).toString();
    final created = _formatted(_detailedData?['createdAt'], locale);
    final updated = _formatted(_detailedData?['updatedAt'], locale);
    final dateParts = [
      if (created != null) S.current.StackPolish_Created(created),
      if (updated != null) S.current.StackPolish_Updated(updated),
    ];
    final entriesCount = _entries.length;

    return FlexibleSpaceBar(
      background: Material(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Background(
              context: context,
              url: _coverUrl,
              forceBg: true,
            ),
            Padding(
              padding: EdgeInsets.only(
                top: topInset + kToolbarHeight + 12,
                left: 16,
                right: 16,
                bottom: hasTabs ? 60 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 72.0),
                    child: AutoSizeText(
                      _title,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InterestStackAuthor(username: widget.stack.username, align: TextAlign.start),
                  if (dateParts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      dateParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (entriesCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$entriesCount ${S.current.Social_Stack_Entries.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top slivers (header) ---

  List<Widget> _topSlivers(BuildContext context, bool innerBoxIsScrolled) {
    return [
      _appBarSliver(context, innerBoxIsScrolled),
      if (_detailedData == null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: loadingCenter(),
          ),
        ),
    ];
  }

  String get _description => _detailedData?['description'] as String? ?? '';

  String? _formatted(Object? raw, String locale) {
    final text = raw is String ? raw.trim() : '';
    return text.isEmpty ? null : formatStackDate(text, locale);
  }

  // --- Body (TabBarView) ---

  Widget _bodyWidget() {
    if (!_showTabs) return SB.z;
    // If only one tab, no need for TabBarView
    if (_tabs.length == 1) {
      if (_hasEntries) return _buildEntriesListView();
      if (_hasSimilar) return _buildInterestStackList(_similarStacks);
      if (_hasMalStacks) return _buildInterestStackList(_malStacks);
    }
    return TabBarView(
      children: [
        if (_hasEntries) _buildEntriesListView(),
        if (_hasSimilar) _buildInterestStackList(_similarStacks),
        if (_hasMalStacks) _buildInterestStackList(_malStacks),
      ],
    );
  }

  Widget _buildEntriesListView() {
    final hasDesc = _description.isNotEmpty;
    return ListView.builder(
      itemCount: _entries.length + (hasDesc ? 1 : 0),
      padding: const EdgeInsets.only(top: 10.0, bottom: 60.0),
      itemBuilder: (context, index) {
        if (hasDesc && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _ExpandableDescription(description: _description),
          );
        }
        final item = _entries[index - (hasDesc ? 1 : 0)];
        final category = item['category'] as String? ?? 'anime';
        return StackEntryTile(
          item: item,
          category: category,
        );
      },
    );
  }

  Widget _buildInterestStackList(List<InterestStack> stacks) {
    return InterestStackContentList(
      horizPadding: horizPadding,
      interestStacks: stacks,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      type: DisplayType.list_vert,
    );
  }

  int? get _stackId => _extractStackId(widget.stack.url);

  /// The picture saved with the bookmark: the stack's first cover, else its first entry's.
  String? get _coverUrl {
    final images = widget.stack.imageUrls;
    if (images != null && images.isNotEmpty) return images.first;
    for (final e in _entries) {
      final url = e['imageUrl'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  /// The stack page on MyAnimeList (the scraper may give a path or a full address).
  String? get _webUrl => stackWebUrl(widget.stack.url);

  // --- Shell for loading shimmer ---

  Widget _buildShell(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          SB.h20,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SB.w20,
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 24,
                      width: 180,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SB.h15,
                    Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              SB.w20,
              Container(
                height: 240,
                width: 170,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              SB.w20,
            ],
          ),
          SB.h20,
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: stackCoverWidth,
                      height: stackCoverHeight,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    SB.w15,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 18,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SB.h10,
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          SB.h15,
          Text(
            S.current.Social_Stack_Failed,
            style: TextStyle(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          SB.h20,
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _fetchDetail();
            },
            child: Text(S.current.Social_Retry),
          ),
        ],
      ),
    );
  }

  Widget _buildNoContentFallback(ThemeData theme) {
    return Center(
      child: Text(
        _detailedData == null
            ? S.current.Social_Stack_Loading
            : S.current.Social_Stack_No_Entries,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// --- Expandable description widget ---

class _ExpandableDescription extends StatefulWidget {
  final String description;

  const _ExpandableDescription({
    required this.description,
  });

  @override
  State<_ExpandableDescription> createState() =>
      _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const _characterLimit = 300;
  bool _expanded = false;

  bool get _needsExpansion => widget.description.length > _characterLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _expanded || !_needsExpansion
        ? widget.description
        : '${widget.description.substring(0, _characterLimit)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topLeft,
          child: _buildRichText(context, text, theme),
        ),
        if (_needsExpansion)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded ? S.current.Social_Show_Less : S.current.Social_Show_More,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a RichText with clickable URLs detected in the text.
  Widget _buildRichText(BuildContext context, String text, ThemeData theme) {
    final urlRegex = RegExp(
      r'https?://[^\s<>\[\]()]+',
      caseSensitive: false,
    );
    final matches = urlRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text, style: theme.textTheme.bodyMedium);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Text before the URL
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: theme.textTheme.bodyMedium,
        ));
      }
      // The URL itself (clickable)
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () =>
              launchURLWithConfirmation(url, context: context),
      ));
      lastEnd = match.end;
    }

    // Remaining text after last URL
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: theme.textTheme.bodyMedium,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// --- Entry row (like DailyAL's SpaciousContentWidget) ---

/// One entry of a stack: a 100 x 150 cover (as in DailyAL), score, title, details and genres.
@visibleForTesting
class StackEntryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String category;

  const StackEntryTile({
    required this.item,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final malId = item['malId'] as int?;
    final entryTitle = item['title'] as String? ?? '?';
    final imageUrl = item['imageUrl'] as String? ?? '';
    final mediaType = item['mediaType'] as String? ?? '';
    final status = item['status'] as String? ?? '';
    final additionalInfo = item['additionalInfo'] as String? ?? '';
    final score = (item['score'] as num?)?.toDouble();
    final members = item['members'] as String? ?? '';
    final genres = (item['genres'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Build the media info line: "TV · Finished · 25eps, 24min"
    final mediaInfoParts = <String>[];
    if (mediaType.isNotEmpty) mediaInfoParts.add(mediaType);
    if (status.isNotEmpty) mediaInfoParts.add(status.standardize() ?? status);
    if (additionalInfo.isNotEmpty) mediaInfoParts.add(additionalInfo);
    final mediaInfo = mediaInfoParts.join(' · ');

    // Format members count compactly
    String? membersFormatted;
    if (members.isNotEmpty) {
      final parsed = int.tryParse(members.replaceAll(',', ''));
      if (parsed != null) {
        membersFormatted = NumberFormat.compact().format(parsed);
      } else {
        membersFormatted = members;
      }
    }

    return InkWell(
      onTap: malId != null
          ? () => gotoPage(
                context: context,
                newPage: ContentDetailedScreen(
                  category: category,
                  id: malId,
                  node: Anime(
                    id: malId,
                    title: entryTitle,
                    imageUrl: imageUrl,
                    score: 0,
                    members: 0,
                  ),
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading cover: DailyAL's 100 x 150
            AvatarWidget(
              height: stackCoverHeight,
              width: stackCoverWidth,
              url: imageUrl.isNotEmpty ? imageUrl : null,
              userRoundBorderforLoading: false,
              radius: BorderRadius.circular(6.0),
            ),
            const SizedBox(width: 12),
            // Trailing info aligned with Search's MediaTile style
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (score != null && score > 0) ...[
                        Icon(Icons.star_rounded,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 2),
                        ScoreReveal(
                          child: Text(
                            score.toStringAsFixed(2),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                      if (membersFormatted != null)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(start: 4),
                            child: Text(
                              '($membersFormatted)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: muted),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entryTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (mediaInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      mediaInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                  if (malId != null) ...[
                    const SizedBox(height: 6),
                    ListStatusPill(id: malId, category: category),
                  ],
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 24,
                      child: ListView.separated(
                        itemCount: genres.length,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        separatorBuilder: (_, __) => const SizedBox(width: 5),
                        itemBuilder: (context, i) {
                          final genreName = genres[i]['name'] as String? ?? '';
                          return Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            child: Text(
                              genreName,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (malId != null)
              IconButton(
                tooltip: S.current.Social_Stack_Edit_Entry,
                icon: const Icon(Icons.edit_rounded),
                visualDensity: VisualDensity.compact,
                onPressed: () => showContentEditSheet(
                  context,
                  category,
                  Anime(
                    id: malId,
                    title: entryTitle,
                    imageUrl: imageUrl,
                    score: 0,
                    members: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
