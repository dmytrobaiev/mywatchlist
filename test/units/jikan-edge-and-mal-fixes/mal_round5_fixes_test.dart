import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mywatchlist/constants/constants.dart'
    show DisplaySubType, genresWidget;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/next_episode_card.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/screens/user_profile/sections/about_section.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Genre, Picture;
import 'package:mywatchlist/services/api/MAL/models/forum/forum_topics_data.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/widgets/MAL/content/animepictures.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/smooth_collapse.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/edit_swipe.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mwl_commons/mwl_commons.dart' show HtmlParsers;
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

  group('Quick Edit Round 5 polish', () {
    test('editSwipeFor dismisses directly on strong pull or fast flick when expanded', () {
      expect(
        editSwipeFor(dy: 200, velocity: 0, expanded: true),
        EditSwipe.dismiss,
      );
      expect(
        editSwipeFor(dy: 50, velocity: 800, expanded: true),
        EditSwipe.dismiss,
      );
      expect(
        editSwipeFor(dy: 60, velocity: 0, expanded: true),
        EditSwipe.collapse,
      );
      expect(
        editSwipeFor(dy: 60, velocity: 0, expanded: false),
        EditSwipe.dismiss,
      );
    });

    testWidgets('Delete button is plain error IconButton and handle has no chevron',
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

      final deleteFinder = find.byKey(const ValueKey('edit-delete'));
      expect(deleteFinder, findsOneWidget);
      expect(tester.widget(deleteFinder), isA<IconButton>());

      final handleFinder = find.byKey(const ValueKey('edit-handle'));
      expect(handleFinder, findsOneWidget);
      expect(
        find.descendant(of: handleFinder, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.byType(SmoothCollapse), findsWidgets);
    });
  });

  group('NextEpisodeCard (2026.11.4 style)', () {
    testWidgets('shows Ep N in dd · hh · mm · ss and Currently airing window',
        (tester) async {
      var now = DateTime.utc(2026, 11, 27, 12, 0, 0);
      final ep = NextEpisode(9, now.add(const Duration(days: 6, hours: 3, minutes: 33, seconds: 58)));

      await tester.pumpWidget(_app(NextEpisodeCard(episode: ep, now: () => now)));
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('06d · 03h · 33m · 58s'), findsOneWidget);

      now = ep.airingAt.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Currently airing'), findsOneWidget);

      now = ep.airingAt.add(const Duration(minutes: 31));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Card), findsNothing);
    });
  });

  group('Forum >999 comma-formatted replies', () {
    test('jikanInt and ForumTopicsData parse comma-separated counts', () {
      expect(jikanInt('1,234'), 1234);
      expect(jikanInt('12,345'), 12345);
      final topic = ForumTopicsData.fromJson({
        'id': 2151690,
        'title': 'Episode 28 Discussion',
        'replies': '1,200',
      });
      expect(topic.numberOfPosts, 1200);
    });
  });

  group('Profile About spoilers', () {
    testWidgets('AboutHtmlContent renders interactive MAL <div class="spoiler"> with 2026.11.4 style',
        (tester) async {
      const malHtml = '''
<p>Hello world</p>
<div class="spoiler">
  <input type="button" class="button show_button" data-showname="Show  " value="Show  ">
  <span class="spoiler_content" style="display:none">
    <input type="button" class="button hide_button" value="Hide  ">
    Hidden profile secret
  </span>
</div>
''';
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: AboutHtmlContent(html: formatAboutHtml(malHtml)),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Hello world', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.textContaining('Hidden profile secret', findRichText: true), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.textContaining('Hidden profile secret', findRichText: true), findsOneWidget);
    });

    test('formatAboutHtml converts plain [spoiler] BBCode into <div class="spoiler">', () {
      final html = formatAboutHtml('Intro\n[spoiler=Plot]Big twist[/spoiler]');
      expect(html, contains('class="spoiler"'));
      expect(html, contains('data-showname="Plot"'));
      expect(html, contains('Big twist'));
    });
  });

  group('Pictures index & BoxFit.contain', () {
    testWidgets('tapping second picture opens gallery at 2 / 3 with BoxFit.contain thumbnails',
        (tester) async {
      final pics = [
        Picture(large: 'https://cdn.myanimelist.net/images/anime/1/1.jpg'),
        Picture(large: 'https://cdn.myanimelist.net/images/anime/1/2.jpg'),
        Picture(large: 'https://cdn.myanimelist.net/images/anime/1/3.jpg'),
      ];
      await tester.pumpWidget(_app(AnimePictures(pictures: pics)));

      final avatars = tester.widgetList<AvatarWidget>(find.byType(AvatarWidget)).toList();
      expect(avatars.length, 3);
      for (final a in avatars) {
        expect(a.fit, BoxFit.contain);
        expect(a.height, 304);
      }

      await tester.tap(find.byType(AvatarWidget).at(1));
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);
    });
  });

  group('Wrapped clickable Details genre tags', () {
    testWidgets('genresWidget uses Wrap instead of SingleChildScrollView', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => genresWidget(
          [
            Genre(id: 1, name: 'Action'),
            Genre(id: 8, name: 'Drama'),
            Genre(id: 10, name: 'Fantasy'),
          ],
          'anime',
          context,
        ),
      )));
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('Interest Stacks 1-image neutral back layers & MAL author parser', () {
    testWidgets('1-image stack renders only 1 AppImage (no duplicated cover)', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(
        width: 130,
        height: 230,
        child: InterestStackPictures(
          images: ['https://cdn.myanimelist.net/images/anime/1/1.jpg'],
        ),
      )));
      expect(find.byType(AppImage), findsOneWidget);
    });

    test('parseInterestStackDetail parses plain-text "by MyAnimeList" in side list', () {
      const html = '''
<html><body>
<div class="stack-detail"><div class="detail-header"><h1 class="title">Root</h1></div></div>
<div class="content-right">
  <div class="side-list"></div>
  <div class="side-list"></div>
  <div class="side-list">
    <div class="column-item">
      <a href="https://myanimelist.net/stacks/90895">
        <div class="img"><img src="https://cdn.myanimelist.net/images/anime/1/1.jpg"></div>
      </a>
      <div class="detail">
        <a class="title" href="https://myanimelist.net/stacks/90895">Staff Picks</a>
        <div><span class="by">by</span> MyAnimeList</div>
        <span>10 Entries · 25 Restacks</span>
      </div>
    </div>
  </div>
</div>
</body></html>
''';
      final parsed = HtmlParsers.parseInterestStackDetail(html_parser.parse(html));
      final malStacks = parsed['myAnimeListStacks'] as List;
      expect(malStacks, hasLength(1));
      expect(malStacks.first['username'], 'MyAnimeList');
    });
  });

  group('My List Comfortable compact countdown badge', () {
    testWidgets('shows CompactAiringBadge on Comfortable List even with showAiringInfo false',
        (tester) async {
      final now = DateTime.utc(2026, 11, 27, 12, 0);
      final entry = ListEntryView(
        id: 52991,
        category: 'anime',
        title: 'Frieren',
        total: 28,
        progress: 10,
        status: ListEntryStatus.current,
        releaseState: ReleaseState.releasing,
        nextAiringAt: now.add(const Duration(days: 2, hours: 4)),
      );
      final busy = ValueNotifier<Set<int>>(const {});
      addTearDown(busy.dispose);
      final actions = EntryActions(
        onOpen: (_) {},
        onEdit: null,
        onStep: null,
        canStep: (_) => false,
        busy: busy,
      );
      await tester.pumpWidget(_app(SizedBox(
        width: 360,
        height: listRowExtent(DisplaySubType.comfortable),
        child: EntryListTile(
          entry: entry,
          subType: DisplaySubType.comfortable,
          actions: actions,
          style: const EntryCardStyle(showAiringInfo: false),
          now: now,
          locale: 'en',
        ),
      )));
      expect(find.byType(CompactAiringBadge), findsOneWidget);
      expect(find.text('2d 4h'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });
  });

  group('ArticleTile 2026.11.4 tags, ellipsis & per-density copy', () {
    testWidgets('ArticleTile renders primary dot-separated clickable tags and ellipsis text',
        (tester) async {
      String? tapped;
      final item = AnimeNewsOrFeaturedItem(
        id: 202,
        title: 'Big Announcement',
        text: 'A very long news description ' * 20,
        tags: 'Anime, Industry',
        imageUrl: '',
        url: 'https://myanimelist.net/news/202',
      );
      await tester.pumpWidget(_app(ArticleTile(
        item: item,
        isNews: true,
        onTagTap: (t) => tapped = t,
      )));
      expect(find.text('  ·  '), findsOneWidget);
      await tester.tap(find.text('Industry'));
      await tester.pump();
      expect(tapped, 'Industry');

      final descWidget = tester.widget<Text>(find.textContaining('A very long news description'));
      expect(descWidget.overflow, TextOverflow.ellipsis);
    });

    test('Display toggle uses updated per-density wording', () {
      expect(S.current.UserList_Save_Height_Per_Layout, 'Remember height per density');
      expect(
        S.current.UserList_Save_Height_Per_Layout_Desc,
        'Save a separate card height for each grid density',
      );
    });
  });
}
