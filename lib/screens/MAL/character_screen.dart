import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/cache/top_characters.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/character_page.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/common/translator.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

// =============================================================================
// Data (plain objects built in a background isolate)
// =============================================================================

enum _SectionId {
  animeography,
  mangaography,
  voiceActors,
  voiceRoles,
  animeStaff,
  publishedManga,
}

enum _VoiceSort { recent, favorites, title }

class _Entry {
  final int id;
  final String title;
  final String? image;
  final String? subtitle;

  const _Entry(this.id, this.title, this.image, this.subtitle);
}

class _Section {
  final _SectionId id;
  final String category;
  final List<_Entry> entries;

  const _Section(this.id, this.category, this.entries);
}

class _Profile {
  final String name;
  final String alternateName;
  final String about;
  final int? favorites;
  final String? image;
  final List<_Section> sections;

  /// Favorites of the voiced characters when the source gives them (MAL's
  /// person page does, Jikan does not).
  final Map<int, int> roleFavorites;

  const _Profile({
    required this.name,
    required this.alternateName,
    required this.about,
    required this.favorites,
    required this.image,
    required this.sections,
    this.roleFavorites = const {},
  });

  _Section? section(_SectionId id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }
}

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

String? _jpg(Object? images, {String? fallbackImageUrl}) {
  final sizes = jikanImageSizes(images, fallbackImageUrl: fallbackImageUrl);
  final url = sizes.large ?? sizes.medium ?? sizes.small;
  return url != null && !RoundAvatar.isPlaceholderUrl(url) ? url : null;
}

/// Entries of a Jikan (`jikan-edge` or Jikan v4 / Tenrai / MalCharacterPage) relation list,
/// one per MAL id (first one wins).
List<_Entry> _entries(
  Object? list, {
  required String key,
  required String titleKey,
  required String subtitleKey,
  String? flatIdKey,
  String? flatTitleKey,
  String? flatImageKey,
  String? flatSubtitleKey,
}) {
  if (list is! List) return const [];
  final seen = <int>{};
  final out = <_Entry>[];
  for (final raw in list) {
    final row = _map(raw);
    if (row == null) continue;
    final nested = _map(row[key]);
    final int? id;
    final Object? title;
    final String? image;
    Object? subtitle;
    if (nested != null) {
      id = jikanInt(nested['malId'] ?? nested['mal_id']);
      title = nested[titleKey];
      image = _jpg(nested['images'], fallbackImageUrl: jikanStr(nested['imageUrl'] ?? nested['image_url']));
      subtitle = row[subtitleKey];
    } else {
      id = jikanInt(
        (flatIdKey != null ? row[flatIdKey] : null) ?? row['malId'] ?? row['mal_id'],
      );
      title = (flatTitleKey != null ? row[flatTitleKey] : null) ?? row[titleKey];
      image = _jpg(
        row['images'],
        fallbackImageUrl: jikanStr(
          (flatImageKey != null ? row[flatImageKey] : null) ??
              row['imageUrl'] ??
              row['image_url'],
        ),
      );
      subtitle = (flatSubtitleKey != null ? row[flatSubtitleKey] : null) ?? row[subtitleKey];
      if (subtitle is List) {
        subtitle = subtitle.map((e) => '$e').where((e) => e.isNotEmpty).join(', ');
      }
    }
    if (id == null || !seen.add(id)) continue;
    out.add(_Entry(
      id,
      title is String && title.isNotEmpty ? title : '?',
      image,
      subtitle is String && subtitle.isNotEmpty ? subtitle : null,
    ));
  }
  return out;
}

/// Parses a Jikan `characters/{id}/full` or `people/{id}/full` body. Runs in
/// a background isolate: the answer can be hundreds of kilobytes.
_Profile _parseProfile((String, bool) args) {
  final (body, isCharacter) = args;
  return _profileFromData(
      _map(_map(jsonDecode(body))?['data']) ?? const {}, isCharacter);
}

/// Builds the profile from Jikan's `data` object, or from MyAnimeList's page
/// parsed into the same shape ([MalCharacterPage]).
_Profile _profileFromData(Map<String, dynamic> data, bool isCharacter) {
  final name = (data['name'] as String?) ?? '';
  String alternate;
  if (isCharacter) {
    alternate = ((data['nameKanji'] ?? data['name_kanji']) as String?) ?? '';
  } else {
    final given = ((data['givenName'] ?? data['given_name']) as String?) ?? '';
    final family = ((data['familyName'] ?? data['family_name']) as String?) ?? '';
    alternate = [given, family].where((e) => e.isNotEmpty).join(', ');
  }
  final sections = isCharacter
      ? [
          _Section(
            _SectionId.animeography,
            'anime',
            _entries(data['anime'],
                key: 'anime', titleKey: 'title', subtitleKey: 'role'),
          ),
          _Section(
            _SectionId.mangaography,
            'manga',
            _entries(data['manga'],
                key: 'manga', titleKey: 'title', subtitleKey: 'role'),
          ),
          _Section(
            _SectionId.voiceActors,
            'person',
            _entries(data['voices'],
                key: 'person', titleKey: 'name', subtitleKey: 'language'),
          ),
        ]
      : [
          _Section(
            _SectionId.voiceRoles,
            'character',
            _entries(
              data['voices'],
              key: 'character',
              titleKey: 'name',
              subtitleKey: 'role',
              flatIdKey: 'characterId',
              flatTitleKey: 'characterName',
              flatImageKey: 'characterImageUrl',
              flatSubtitleKey: 'characterRole',
            ),
          ),
          _Section(
            _SectionId.animeStaff,
            'anime',
            _entries(
              data['anime'],
              key: 'anime',
              titleKey: 'title',
              subtitleKey: 'position',
              flatIdKey: 'animeId',
              flatTitleKey: 'animeTitle',
              flatSubtitleKey: 'positions',
            ),
          ),
          _Section(
            _SectionId.publishedManga,
            'manga',
            _entries(
              data['manga'],
              key: 'manga',
              titleKey: 'title',
              subtitleKey: 'position',
              flatIdKey: 'mangaId',
              flatTitleKey: 'mangaTitle',
              flatSubtitleKey: 'positions',
            ),
          ),
        ];
  final roleFavorites = <int, int>{};
  if (!isCharacter && data['voices'] is List) {
    for (final raw in data['voices'] as List) {
      final row = _map(raw);
      final id = jikanInt(
        _map(row?['character'])?['malId'] ??
            _map(row?['character'])?['mal_id'] ??
            row?['characterId'],
      );
      final fav = jikanInt(row?['favorites']);
      if (id != null && fav != null) roleFavorites.putIfAbsent(id, () => fav);
    }
  }
  return _Profile(
    name: name,
    alternateName: alternate,
    about: ((data['about'] as String?) ?? '').trim(),
    favorites: jikanInt(data['favorites']),
    image: _jpg(data['images'], fallbackImageUrl: jikanStr(data['imageUrl'] ?? data['image_url'])),
    sections: sections,
    roleFavorites: roleFavorites,
  );
}

List<String> _parsePictures(String body) {
  final data = _map(jsonDecode(body))?['data'];
  if (data is! List) return const [];
  return [
    for (final e in data)
      if (_jpg(e, fallbackImageUrl: jikanStr(_map(e)?['imageUrl'] ?? _map(e)?['image_url']))
          case final String url)
        url,
  ];
}

/// Favorites of characters already looked up, kept for the session so a
/// second sort (or another person's page) does not ask Jikan again.
final Map<int, int> _favoritesCache = {};

// =============================================================================
// Screen
// =============================================================================

/// A screen that displays details for a MAL character or person (seiyuu/staff).
///
/// Pass [category] = `'character'` (default) for characters, or `'person'`
/// for voice actors / staff members. The page is a MyAnimeList screen whatever
/// tracker is active: the data comes from Jikan by MAL id, raced against
/// MyAnimeList's own page ([MalCharacterPage], see [JikanFallbacks.race]:
/// Jikan gets a 3 s head start and the load ends within about 12 s).
class CharacterScreen extends StatefulWidget {
  final int id;
  final String category;

  const CharacterScreen({
    super.key,
    required this.id,
    this.category = 'character',
  });

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  _Profile? _profile;
  bool _failed = false;
  int _tab = 0;
  _VoiceSort _sort = _VoiceSort.recent;
  List<_Entry> _voices = const [];
  final ValueNotifier<List<String>> _pictures = ValueNotifier(const []);
  final ValueNotifier<(int, int)?> _sortProgress = ValueNotifier(null);
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _showBarTitle = ValueNotifier(false);
  final GlobalKey _headerNameKey = GlobalKey();

  /// Incremented to cancel a running favorites lookup.
  int _run = 0;

  bool get _isCharacter => widget.category == 'character';
  String get _path => _isCharacter ? 'characters' : 'people';
  String get _url => 'https://myanimelist.net/'
      '${_isCharacter ? 'character' : 'people'}/${widget.id}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _run++;
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _showBarTitle.dispose();
    _pictures.dispose();
    _sortProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ctx = _headerNameKey.currentContext;
    if (ctx == null) {
      if (_showBarTitle.value) _showBarTitle.value = false;
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final bottomY = box.localToGlobal(Offset(0, box.size.height)).dy;
    final barBottom = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final shouldShow = bottomY <= barBottom;
    if (_showBarTitle.value != shouldShow) {
      _showBarTitle.value = shouldShow;
    }
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (_failed || _profile != null) {
      setState(() {
        _failed = false;
        _profile = null;
      });
    }
    try {
      // For character pages, jikan-edge strips `<div class="spoiler">` wrappers
      // and truncates trailing spoilers at `<div`. Prefer MAL's own page so
      // collapsible `[Spoiler]` blocks remain intact, falling back to Jikan.
      final _Profile profile;
      if (_isCharacter) {
        _Profile? malProfile;
        try {
          malProfile = await _fromMal();
        } catch (_) {}
        profile = malProfile ?? await _fromJikan();
      } else {
        final result = await JikanFallbacks.race<_Profile>(
          jikan: _fromJikan,
          fallback: _fromMal,
        );
        profile = result.value;
      }
      _favoritesCache.addAll(profile.roleFavorites);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _voices = List.of(profile.section(_SectionId.voiceRoles)?.entries ??
            const <_Entry>[]);
      });
      _loadPictures(profile.image);
    } catch (e) {
      debugPrint('Character page failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<_Profile> _fromJikan() async {
    final res = await JikanClient.instance
        .get(Uri.parse('${Constants.jikanV4}/$_path/${widget.id}/full'));
    if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
    return compute(_parseProfile, (res.body, _isCharacter));
  }

  Future<_Profile> _fromMal() async {
    final data =
        await MalCharacterPage.load(widget.id, isCharacter: _isCharacter);
    return _profileFromData(data, _isCharacter);
  }

  /// Extra pictures are a bonus: a failure leaves the main picture alone.
  Future<void> _loadPictures(String? main) async {
    if (main != null) _pictures.value = [main];
    try {
      final res = await JikanClient.instance
          .get(Uri.parse('${Constants.jikanV4}/$_path/${widget.id}/pictures'));
      if (res.statusCode != 200 || !mounted) return;
      final extra = await compute(_parsePictures, res.body);
      if (!mounted) return;
      final all = <String>[
        if (main != null) main,
        ...extra.where((u) => u != main),
      ];
      if (all.isNotEmpty) _pictures.value = all;
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Voice roles sorting
  // ---------------------------------------------------------------------------

  void _applySort() {
    final base = List.of(
        _profile?.section(_SectionId.voiceRoles)?.entries ?? const <_Entry>[]);
    switch (_sort) {
      case _VoiceSort.recent:
        break;
      case _VoiceSort.title:
        base.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _VoiceSort.favorites:
        // List.sort is not stable: the original position breaks ties.
        final position = {for (var i = 0; i < base.length; i++) base[i].id: i};
        base.sort((a, b) {
          final byFav =
              (_favoritesCache[b.id] ?? 0).compareTo(_favoritesCache[a.id] ?? 0);
          return byFav != 0 ? byFav : position[a.id]!.compareTo(position[b.id]!);
        });
    }
    setState(() => _voices = base);
  }

  Future<void> _setSort(_VoiceSort sort) async {
    if (sort == _sort) return;
    _run++;
    _sortProgress.value = null;
    _sort = sort;
    _applySort();
    if (sort == _VoiceSort.favorites) await _loadFavorites();
  }

  /// Looks up the favorites of every voiced character not yet known, one at a
  /// time (Jikan allows about 3 requests per second; the client spaces them),
  /// then sorts. A rate limit stops the lookup and sorts with what is known.
  Future<void> _loadFavorites() async {
    final token = ++_run;
    // The shared top-characters list answers most popular roles at once.
    try {
      await TopCharacters.instance.ensureLoaded();
      for (final e in _voices) {
        final fav = TopCharacters.instance.favoritesOf(e.id);
        if (fav != null) _favoritesCache[e.id] = fav;
      }
    } catch (_) {}
    if (!mounted || token != _run) return;
    final missing = [
      for (final e in _voices)
        if (!_favoritesCache.containsKey(e.id)) e.id,
    ];
    if (missing.isEmpty) {
      _applySort();
      return;
    }
    var done = 0;
    _sortProgress.value = (0, missing.length);
    var complete = true;
    String? problem;
    for (final id in missing) {
      if (!mounted || token != _run) return;
      try {
        final res = await JikanClient.instance
            .get(Uri.parse('${Constants.jikanV4}/characters/$id'));
        if (res.statusCode == 429) {
          complete = false;
          problem = S.current.Fch_Rate_Limit;
          break;
        }
        if (res.statusCode == 200) {
          final fav = _map(_map(jsonDecode(res.body))?['data'])?['favorites'];
          _favoritesCache[id] = fav is int ? fav : 0;
        } else if (res.statusCode == 404) {
          _favoritesCache[id] = 0;
        } else {
          complete = false;
        }
      } on JikanUnavailable {
        complete = false;
        problem = S.current.Fch_Sort_Failed;
        break;
      } catch (_) {
        complete = false;
      }
      done++;
      if (mounted && token == _run) _sortProgress.value = (done, missing.length);
    }
    if (!mounted || token != _run) return;
    _sortProgress.value = null;
    _applySort();
    if (problem != null) {
      showToast(problem);
    } else if (complete) {
      showToast(S.current.Fch_Sorting_Done);
    } else {
      showToast(S.current.Fch_Sort_Failed);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _share(_Profile profile) {
    showShareBuilder(
      context,
      subject: profile.name,
      title: _isCharacter
          ? S.current.Fch_Share_Character
          : S.current.Fch_Share_Person,
      fields: personShareFields(
        url: _url,
        name: profile.name,
        favorites: profile.favorites,
        about: profile.about,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final title = profile?.name.isNotEmpty == true
        ? profile!.name
        : (_isCharacter ? S.current.Fch_Character : S.current.Fch_Person);
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            title: ValueListenableBuilder<bool>(
              valueListenable: _showBarTitle,
              builder: (context, show, child) => AnimatedOpacity(
                opacity: (profile == null || show) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: child,
              ),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              if (profile != null && profile.name.isNotEmpty)
                BookmarkButton(
                  tracker: AccountType.myanimelist.name,
                  kind: _isCharacter ? BookmarkKind.character : BookmarkKind.person,
                  id: widget.id,
                  title: profile.name,
                  imageUrl: profile.image,
                  subtitle: profile.alternateName.isEmpty
                      ? null
                      : profile.alternateName,
                  malId: widget.id,
                ),
              if (profile != null)
                AppBarMenu(
                  onShare: () => _share(profile),
                  onOpenInBrowser: () => openInBrowser(context, _url),
                ),
            ],
          ),
          ..._bodySlivers(profile),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(_Profile? profile) {
    if (_failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SectionMessage.error(
            message: S.current.Fch_Load_Failed,
            height: 240,
            onRetry: _load,
          ),
        ),
      ];
    }
    if (profile == null) return [const SliverToBoxAdapter(child: _Skeleton())];
    return [
      SliverToBoxAdapter(
        child: _Header(
          profile: profile,
          pictures: _pictures,
          nameKey: _headerNameKey,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(S.current.Fch_About)),
              ButtonSegment(value: 1, label: Text(S.current.Fch_Details)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
      ),
      if (_tab == 0) ..._aboutSlivers(profile) else ..._detailSlivers(profile),
    ];
  }

  List<Widget> _aboutSlivers(_Profile profile) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final encodedForTranslation = profile.about
        .replaceAll(RegExp(r'\[Spoiler\]', caseSensitive: false), '<<<S>>>')
        .replaceAll(RegExp(r'\[/Spoiler\]', caseSensitive: false), '<<<E>>>');
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
          child: profile.about.isEmpty
              ? Text(
                  S.current.Fch_No_About,
                  style: style?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : TranslatorWidget(
                  content: encodedForTranslation,
                  reversed: true,
                  builder: (context, text) => _AboutContent(text: text, style: style),
                ),
        ),
      ),
    ];
  }

  List<Widget> _detailSlivers(_Profile profile) {
    final slivers = <Widget>[];
    for (final section in profile.sections) {
      final isVoices = section.id == _SectionId.voiceRoles;
      final entries = isVoices ? _voices : section.entries;
      if (entries.isEmpty) continue;
      slivers.add(SliverToBoxAdapter(
        child: _SectionHeader(
          title: _sectionTitle(section.id),
          count: entries.length,
          trailing: isVoices ? _sortButton() : null,
          progress: isVoices ? _sortProgress : null,
        ),
      ));
      if (isVoices) {
        // Possibly hundreds of roles: a lazy grid, not a row.
        slivers.add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisExtent: 148,
            ),
            itemCount: entries.length,
            itemBuilder: (_, i) => _EntryCard(
              key: ValueKey(entries[i].id),
              entry: entries[i],
              category: section.category,
              favorites: _sort == _VoiceSort.favorites
                  ? _favoritesCache[entries[i].id]
                  : null,
            ),
          ),
        ));
      } else {
        slivers.add(SliverToBoxAdapter(
          child: SizedBox(
            height: section.category == 'person' ? 148 : 218,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemExtent: 112,
              itemCount: entries.length,
              itemBuilder: (_, i) => _EntryCard(
                key: ValueKey(entries[i].id),
                entry: entries[i],
                category: section.category,
              ),
            ),
          ),
        ));
      }
    }
    if (slivers.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: showNoContent()));
    }
    return slivers;
  }

  String _sectionTitle(_SectionId id) => switch (id) {
        _SectionId.animeography => S.current.Fch_Animeography,
        _SectionId.mangaography => S.current.Fch_Mangaography,
        _SectionId.voiceActors => S.current.Fch_Voice_Actors,
        _SectionId.voiceRoles => S.current.Fch_Voice_Roles,
        _SectionId.animeStaff => S.current.Fch_Anime_Staff,
        _SectionId.publishedManga => S.current.Fch_Published_Manga,
      };

  Widget _sortButton() {
    String label(_VoiceSort s) => switch (s) {
          _VoiceSort.recent => S.current.Fch_Sort_Recent,
          _VoiceSort.favorites => S.current.Fch_Sort_Favorites,
          _VoiceSort.title => S.current.Fch_Sort_Title,
        };
    return PopupMenuButton<_VoiceSort>(
      tooltip: S.current.Fch_Sort,
      icon: const Icon(Icons.sort),
      initialValue: _sort,
      onSelected: _setSort,
      itemBuilder: (_) => [
        for (final s in _VoiceSort.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == _sort,
            child: Text(label(s)),
          ),
      ],
    );
  }
}

// =============================================================================
// Widgets
// =============================================================================

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            bar(200, 24),
            const SizedBox(height: 10),
            bar(120, 16),
            const SizedBox(height: 24),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 5; i++) ...[
              bar(double.infinity, 14),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Name, alternate name, picture carousel and favorites.
class _Header extends StatelessWidget {
  final _Profile profile;
  final ValueNotifier<List<String>> pictures;
  final GlobalKey? nameKey;

  const _Header({required this.profile, required this.pictures, this.nameKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        _Gallery(pictures: pictures),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Text(
                profile.name,
                key: nameKey,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              if (profile.alternateName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  profile.alternateName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (profile.favorites != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite, size: 20, color: scheme.error),
                    const SizedBox(width: 8),
                    Text(
                      S.current.Fch_Favorites(profile.favorites!),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular picture carousel (auto-plays, tap to zoom). It owns its page
/// controller and timer, so a page change repaints only this widget.
class _Gallery extends StatefulWidget {
  final ValueNotifier<List<String>> pictures;

  const _Gallery({required this.pictures});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _controller = PageController(viewportFraction: 0.55);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.pictures.addListener(_restart);
    _restart();
  }

  @override
  void dispose() {
    widget.pictures.removeListener(_restart);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    final count = widget.pictures.value.length;
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % count,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.pictures,
      builder: (context, pictures, _) {
        if (pictures.isEmpty) {
          return SizedBox(
            height: 220,
            child: Center(
              child: ClipOval(
                child: SizedBox(
                  width: 196,
                  height: 196,
                  child: ColoredBox(
                    color: scheme.secondaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 64,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => zoomInImageList(context, pictures, _index),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _controller,
              itemCount: pictures.length,
              onPageChanged: (i) => _index = i,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipOval(
                      child: AppImage(
                        url: pictures[i],
                        width: 196,
                        height: 196,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholderColor: scheme.surfaceContainerHighest,
                        errorWidget: (_) => ColoredBox(
                          color: scheme.secondaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 64,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Widget? trailing;
  final ValueListenable<(int, int)?>? progress;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      TextSpan(
                        text: '  ${NumberFormat.decimalPattern().format(count)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing case final t?) t,
            ],
          ),
          if (progress != null)
            ValueListenableBuilder<(int, int)?>(
              valueListenable: progress!,
              builder: (context, value, _) {
                if (value == null) return const SizedBox.shrink();
                final (done, total) = value;
                return Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.current.Fch_Sorting_Progress(done, total),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: total == 0 ? null : done / total),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// One related title or person: a round picture for people, a poster for
/// anime and manga.
class _EntryCard extends StatelessWidget {
  final _Entry entry;
  final String category;
  final int? favorites;

  const _EntryCard({
    super.key,
    required this.entry,
    required this.category,
    this.favorites,
  });

  bool get _isPerson => category == 'character' || category == 'person';

  void _open(BuildContext context) {
    if (_isPerson) {
      gotoPage(
        context: context,
        newPage: CharacterScreen(id: entry.id, category: category),
      );
    } else {
      gotoPage(
        context: context,
        newPage: ContentDetailedScreen(
          category: category,
          id: entry.id,
          node: Anime(
            id: entry.id,
            title: entry.title,
            imageUrl: entry.image ?? '',
            score: 0,
            members: 0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final Widget picture = _isPerson
        ? RoundAvatar(url: entry.image, size: 84)
        : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppImage(
              url: entry.image,
              width: 96,
              height: 136,
              fit: BoxFit.cover,
              placeholderColor: scheme.surfaceContainerHighest,
              errorWidget: (_) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.image_not_supported_outlined, color: muted),
              ),
            ),
          );
    final subtitle = favorites != null
        ? NumberFormat.compact().format(favorites)
        : entry.subtitle;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            picture,
            const SizedBox(height: 6),
            Text(
              entry.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (favorites != null) ...[
                    Icon(Icons.favorite, size: 10, color: scheme.error),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

final RegExp _aboutSpoilerRe = RegExp(
  r'(?:\[Spoiler\]|<<<S>>>)\s*([\s\S]*?)\s*(?:\[/Spoiler\]|<<<E>>>)',
  caseSensitive: false,
);

/// Renders character/person About text with collapsible `[Spoiler]...[/Spoiler]` blocks
/// (no icons) and linkified URLs / social handles.
class _AboutContent extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _AboutContent({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final segments = <({bool spoiler, String body})>[];
    var cursor = 0;
    for (final match in _aboutSpoilerRe.allMatches(text)) {
      if (match.start > cursor) {
        final plain = text.substring(cursor, match.start).trim();
        if (plain.isNotEmpty) segments.add((spoiler: false, body: plain));
      }
      final body = (match.group(1) ?? '').trim();
      if (body.isNotEmpty) segments.add((spoiler: true, body: body));
      cursor = match.end;
    }
    if (cursor < text.length) {
      final tail = text.substring(cursor).trim();
      if (tail.isNotEmpty) segments.add((spoiler: false, body: tail));
    }

    if (segments.isEmpty) return const SizedBox.shrink();
    if (segments.length == 1 && !segments.first.spoiler) {
      return _LinkifiedAboutText(text: segments.first.body, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          if (segments[i].spoiler)
            _SpoilerBlock(text: segments[i].body, style: style)
          else
            _LinkifiedAboutText(text: segments[i].body, style: style),
        ],
      ],
    );
  }
}

class _SpoilerBlock extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _SpoilerBlock({required this.text, this.style});

  @override
  State<_SpoilerBlock> createState() => _SpoilerBlockState();
}

class _SpoilerBlockState extends State<_SpoilerBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                _expanded ? 'Hide spoiler' : 'Spoiler',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _LinkifiedAboutText(
                      text: widget.text,
                      style: widget.style,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

final RegExp _aboutLinkRe = RegExp(
  r'(https?://[^\s)\]]+)|((?:Twitter|X|Instagram|TikTok|YouTube)\s*:\s*)(@[A-Za-z0-9_.-]+(?:[ \t]*,[ \t\r\n]*@[A-Za-z0-9_.-]+)*)',
  caseSensitive: false,
);
final RegExp _singleAtHandleRe = RegExp(r'@([A-Za-z0-9_.-]+)');
final RegExp _danglingHtmlTagRe = RegExp(r'\s*<[a-zA-Z][^>]*$');

/// Strips any trailing incomplete HTML tag (e.g. dangling `<div` from jikan-edge).
String sanitizeAboutText(String raw) => raw.replaceFirst(_danglingHtmlTagRe, '').trimRight();

/// Builds the canonical profile URL for a social handle under [platformLabel].
String socialHandleUrl(String platformLabel, String handle) {
  final lower = platformLabel.toLowerCase();
  if (lower.startsWith('instagram')) return 'https://www.instagram.com/$handle';
  if (lower.startsWith('tiktok')) return 'https://www.tiktok.com/@$handle';
  if (lower.startsWith('youtube')) return 'https://www.youtube.com/@$handle';
  return 'https://x.com/$handle';
}

/// Tokenizes [text] into plain segments and clickable links (URLs plus single or
/// comma-separated `Twitter/X/Instagram/TikTok/YouTube: @handle` mentions).
List<({String text, String? url})> parseAboutLinks(String text) {
  final cleaned = sanitizeAboutText(text);
  final out = <({String text, String? url})>[];
  var cursor = 0;
  for (final match in _aboutLinkRe.allMatches(cleaned)) {
    if (match.start > cursor) {
      out.add((text: cleaned.substring(cursor, match.start), url: null));
    }
    final fullUrl = match.group(1);
    if (fullUrl != null) {
      out.add((text: fullUrl, url: fullUrl));
    } else {
      final prefix = match.group(2) ?? '';
      final handlesPart = match.group(3) ?? '';
      if (prefix.isNotEmpty) out.add((text: prefix, url: null));
      var subCursor = 0;
      for (final hMatch in _singleAtHandleRe.allMatches(handlesPart)) {
        if (hMatch.start > subCursor) {
          out.add((text: handlesPart.substring(subCursor, hMatch.start), url: null));
        }
        var rawToken = hMatch.group(0)!;
        var handle = hMatch.group(1)!;
        var trailing = '';
        while (handle.endsWith('.')) {
          handle = handle.substring(0, handle.length - 1);
          rawToken = rawToken.substring(0, rawToken.length - 1);
          trailing = '.$trailing';
        }
        if (handle.isNotEmpty) {
          out.add((text: rawToken, url: socialHandleUrl(prefix, handle)));
        } else {
          out.add((text: rawToken, url: null));
        }
        if (trailing.isNotEmpty) out.add((text: trailing, url: null));
        subCursor = hMatch.end;
      }
      if (subCursor < handlesPart.length) {
        out.add((text: handlesPart.substring(subCursor), url: null));
      }
    }
    cursor = match.end;
  }
  if (cursor < cleaned.length) {
    out.add((text: cleaned.substring(cursor), url: null));
  }
  return out;
}

/// Selectable text that turns URLs and `Twitter/X/Instagram/TikTok/YouTube: @handle`
/// mentions (including comma-separated lists) into tappable links, properly disposing
/// its [TapGestureRecognizer]s.
class _LinkifiedAboutText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _LinkifiedAboutText({required this.text, this.style});

  @override
  State<_LinkifiedAboutText> createState() => _LinkifiedAboutTextState();
}

class _LinkifiedAboutTextState extends State<_LinkifiedAboutText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final linkColor = Theme.of(context).colorScheme.primary;
    final linkStyle = (widget.style ?? const TextStyle()).copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    final spans = <InlineSpan>[];
    for (final token in parseAboutLinks(widget.text)) {
      if (token.url != null) {
        final target = token.url!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => openLink(context, target);
        _recognizers.add(recognizer);
        spans.add(TextSpan(text: token.text, style: linkStyle, recognizer: recognizer));
      } else {
        spans.add(TextSpan(text: token.text));
      }
    }

    return SelectableText.rich(
      TextSpan(style: widget.style, children: spans),
    );
  }
}
