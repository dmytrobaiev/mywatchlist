import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart'
    show DisplaySubType, DisplayType, genresWidget, showNoContent;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_screen.dart'
    show DetailCollapsedTitle;
import 'package:mywatchlist/screens/search/search_filter_panel.dart'
    show SearchDisplay;
import 'package:mywatchlist/screens/search/search_history.dart';
import 'package:mywatchlist/screens/search/search_home_view.dart';
import 'package:mywatchlist/screens/search/search_queries.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/screens/studios/studio_screen.dart'
    show studioTopLuminance;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Genre;
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/character_page.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../edit-sheet/fixtures.dart';

class _StubEntryService implements ListEntryService {
  @override
  bool get canEdit => true;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) async =>
      EditableContent.fromMalJson(completedAnimeJson(), isAnime: isAnime);

  @override
  Future<EntryUpdate> update(
    int id, {
    required bool isAnime,
    required EntryPatch patch,
    ListEntry? previous,
  }) async {
    final p = previous ?? const ListEntry(status: 'completed');
    return EntryUpdate(p, p);
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {}
}

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ArticleTile clickable tag chips', () {
    testWidgets('invokes onTagTap with tapped tag name', (tester) async {
      String? tapped;
      final item = AnimeNewsOrFeaturedItem(
        id: 101,
        title: 'Spring Anime Roundup',
        text: 'Highlights for the upcoming season.',
        tags: 'Anime, Industry, Music',
        imageUrl: '',
        url: 'https://myanimelist.net/news/101',
      );
      await tester.pumpWidget(_app(ArticleTile(
        item: item,
        isNews: true,
        onTagTap: (tag) => tapped = tag,
      )));
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Industry'), findsOneWidget);
      await tester.tap(find.text('Industry'));
      await tester.pump();
      expect(tapped, 'Industry');
    });
  });

  group('SpecialQuery two-step backspace & long-press fill', () {
    test('strips @suffix first and #head second', () {
      final first = SpecialQuery.stepBackspace(
        '#favorite@manga',
        '#favorite@mang',
        wasSpecialTag: true,
      );
      expect(first, '#favorite');
      final second = SpecialQuery.stepBackspace(
        '#favorite',
        '#favorit',
        wasSpecialTag: true,
      );
      expect(second, '');

      expect(
        SpecialQuery.stepBackspace('#winter@2026', '#winter@202', wasSpecialTag: true),
        '#winter',
      );
      expect(
        SpecialQuery.stepBackspace('#winter', '#winte', wasSpecialTag: true),
        '',
      );
      expect(
        SpecialQuery.stepBackspace('naruto', 'narut', wasSpecialTag: false),
        isNull,
      );
    });

    testWidgets('long-pressing a tag suggestion calls onFillQuery without submitting',
        (tester) async {
      String? submitted;
      String? filled;
      final suggestions = ValueNotifier(const SuggestionState(
        query: '#fav',
        category: 'anime',
        specials: [
          (query: '#favorite@manga', label: 'Most Favorited Manga'),
        ],
      ));
      await tester.pumpWidget(_app(SearchHomeView(
        history: SearchHistory.instance,
        suggestions: suggestions,
        onQuery: (q) => submitted = q,
        onFillQuery: (q) => filled = q,
      )));
      await tester.pump();
      await tester.longPress(find.text('#favorite@manga'));
      await tester.pump();
      expect(filled, '#favorite@manga');
      expect(submitted, isNull);
      suggestions.dispose();
    });
  });

  group('Quick Edit top-right toggle & icon-only delete', () {
    testWidgets('pins layout toggle top-right in both modes and removes More options button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(SingleChildScrollView(
        child: ContentEditWidget(
          id: 5114,
          category: 'anime',
          service: _StubEntryService(),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('More options'), findsNothing);
      expect(find.text('Delete from List'), findsNothing);
      expect(find.byKey(const ValueKey('edit-delete')), findsOneWidget);
      expect(find.byTooltip('Delete from List'), findsOneWidget);

      final toggleFinder = find.byKey(const ValueKey('edit-episode-layout-toggle'));
      expect(toggleFinder, findsOneWidget);
      final barToggleRight = tester.getRect(toggleFinder).right;

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      final stepperToggleRight = tester.getRect(toggleFinder).right;
      expect((stepperToggleRight - barToggleRight).abs(), lessThan(2.0));
    });
  });

  group('Grid card height 100-360 & saveHeightPerLayout', () {
    test('ListDisplay supports 100-360 and per-layout saved heights with JSON round-trip', () {
      expect(ListDisplay.minGridHeight, 100);
      expect(ListDisplay.maxGridHeight, 360);

      var display = const ListDisplay(type: DisplayType.grid, subType: DisplaySubType.comfortable);
      expect(display.saveHeightPerLayout, isTrue);

      display = display.withGridHeight(120);
      expect(display.effectiveGridHeight(), 120);

      display = display.withSubType(DisplaySubType.compact).withGridHeight(180);
      expect(display.effectiveGridHeight(), 180);

      display = display.withSubType(DisplaySubType.comfortable);
      expect(display.effectiveGridHeight(), 120);

      final restored = ListDisplay.fromJson(display.toJson());
      expect(restored, display);
      expect(restored.effectiveGridHeight(DisplaySubType.compact), 180);
      expect(restored.effectiveGridHeight(DisplaySubType.comfortable), 120);
    });

    test('SearchDisplay supports 100-360 and per-layout saved heights', () {
      expect(SearchDisplay.minGridHeight, 100);
      var display = SearchDisplay.defaults.withGridHeight(110);
      expect(display.effectiveGridHeight(), 110);
      display = display.withSubType(DisplaySubType.cover_only_grid).withGridHeight(140);
      expect(display.effectiveGridHeight(), 140);
      expect(display.withSubType(DisplaySubType.compact).effectiveGridHeight(), 110);
    });
  });

  group('DetailCollapsedTitle', () {
    testWidgets('is hidden when expanded and visible when snapped to tab bar', (tester) async {
      Widget wrap(double currentExtent) => _app(FlexibleSpaceBarSettings(
            toolbarOpacity: 1,
            minExtent: 100,
            maxExtent: 300,
            currentExtent: currentExtent,
            child: const DetailCollapsedTitle(title: 'Frieren'),
          ));

      await tester.pumpWidget(wrap(260));
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.0);

      await tester.pumpWidget(wrap(100));
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1.0);
    });
  });

  group('Studio adaptive luminance', () {
    test('detects bright white vs dark black top bands', () {
      final white = Uint8List.fromList(List.filled(4 * 4 * 4, 255));
      final black = Uint8List.fromList([
        for (var i = 0; i < 16; i++) ...[0, 0, 0, 255],
      ]);
      final transparent = Uint8List.fromList(List.filled(4 * 4 * 4, 0));

      expect(studioTopLuminance(white, 4, 4), greaterThan(0.9));
      expect(studioTopLuminance(black, 4, 4), lessThan(0.1));
      expect(studioTopLuminance(transparent, 4, 4), greaterThan(0.9));
    });
  });

  group('Media image placeholder & Synopsis genre tag spacing', () {
    testWidgets('AvatarWidget(useUserImageOnError: false) uses Icons.image_outlined', (tester) async {
      await tester.pumpWidget(_app(const AvatarWidget(
        url: null,
        width: 120,
        height: 160,
        useUserImageOnError: false,
        userRoundBorderforLoading: false,
      )));
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('genresWidget sizes short tags tightly without 64px button minWidth', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => genresWidget(
          [
            Genre(id: 8, name: 'Drama'),
            Genre(id: 1, name: 'Action'),
          ],
          'anime',
          context,
        ),
      )));
      final dramaRect = tester.getRect(find.ancestor(
        of: find.text('Drama'),
        matching: find.byType(InkWell),
      ));
      expect(dramaRect.width, lessThan(60));
    });
  });

  group('Offline centering & Settings sidebar wording', () {
    testWidgets('showNoContent wraps in Center', (tester) async {
      await tester.pumpWidget(_app(showNoContent(text: 'Empty')));
      expect(find.byType(Center), findsWidgets);
    });

    test('SettingsSection.sidebar.description describes sidebar customization', () {
      expect(SettingsSection.sidebar.description, S.current.Sidebar_Settings_Desc);
      expect(SettingsSection.sidebar.description, isNot(S.current.Customize_Home_Page));
    });
  });

  group('Person external links', () {
    test('parseMalPersonPage extracts website_url and preserves <a href> links in about', () {
      const html = '''
<html><head><meta property="og:title" content="Kamiya, Hiroshi"></head>
<body><div id="content">
<h1 class="title-name">Kamiya, Hiroshi</h1>
<div>
  <span class="dark_text">Website:</span>
  <a href="https://www.aoni.co.jp/search/kamiya-hiroshi.html">Official</a>
</div>
<div class="people-informantion-more">
  Profile: <a href="https://www.aoni.co.jp/search/kamiya-hiroshi.html">Aoni</a><br>
  <a href="https://kiramune.jp/artist/kamiya/">Kiramune</a><br>
  X (Music): @Utahiroshi15th<br>
  Instagram: @hiroshi1975kamiya
</div>
</div></body></html>''';
      final parsed = parseMalPersonPage(html);
      expect(parsed['website_url'], 'https://www.aoni.co.jp/search/kamiya-hiroshi.html');
      final about = parsed['about'] as String;
      expect(about, contains('[Aoni](https://www.aoni.co.jp/search/kamiya-hiroshi.html)'));
      expect(about, contains('[Kiramune](https://kiramune.jp/artist/kamiya/)'));

      final tokens = parseAboutLinks(about);
      final links = [for (final t in tokens) if (t.url != null) (t.text, t.url!)];
      expect(links, [
        ('Aoni', 'https://www.aoni.co.jp/search/kamiya-hiroshi.html'),
        ('Kiramune', 'https://kiramune.jp/artist/kamiya/'),
        ('@Utahiroshi15th', 'https://x.com/Utahiroshi15th'),
        ('@hiroshi1975kamiya', 'https://www.instagram.com/hiroshi1975kamiya'),
      ]);
    });
  });
}
