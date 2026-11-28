import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/content/animepictures.dart';
import 'package:mywatchlist/widgets/MAL/content/show_forum.dart';
import 'package:mywatchlist/widgets/MAL/content/synopsis_widget.dart';
import 'package:mywatchlist/widgets/MAL/home/show_news.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/translator.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../helpers/no_network.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
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
    forbidNetwork();
    await initializeDateFormatting();
    await S.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Forum reply count flush-right alignment', () {
    testWidgets('reply counts align flush right regardless of author name length',
        (tester) async {
      final original = JikanClient.instance;
      addTearDown(() => JikanClient.instance = original);

      JikanClient.instance = JikanClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'data': [
                  {
                    'mal_id': 101,
                    'title': 'Episode 1 Discussion',
                    'date': '2026-10-01T10:00:00+00:00',
                    'author_username': 'Al',
                    'comments': 12,
                  },
                  {
                    'mal_id': 102,
                    'title': 'Episode 2 Discussion',
                    'date': '2026-10-08T10:00:00+00:00',
                    'author_username': 'ExtremelyLongUsernameForTestingAlignment',
                    'comments': 1234,
                  },
                ],
              }),
              200,
            )),
        minInterval: Duration.zero,
      );

      await tester.pumpWidget(_app(const SizedBox(
        width: 390,
        child: ShowAnimeForum(animeId: 1),
      )));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final r1 = tester.getTopRight(find.text('12'));
      final r2 = tester.getTopRight(find.text('1234'));
      expect((r1.dx - r2.dx).abs(), lessThanOrEqualTo(1.0));
      expect(tester.takeException(), isNull);
    });
  });

  group('Synopsis tags-to-description gap', () {
    testWidgets('gap between genre tags and description is 12 dp', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: SysonpsisWidget(
          synopsis: 'A concise adventure synopsis.',
          genres: [Genre(id: 1, name: 'Action'), Genre(id: 8, name: 'Drama')],
          expanded: true,
        ),
      )));

      final wrapBottom = tester.getBottomLeft(find.byType(Wrap)).dy;
      final descTop = tester.getTopLeft(find.byType(TranslatorWidget)).dy;
      expect(descTop - wrapBottom, closeTo(12.0, 0.5));
    });
  });

  group('Details Pictures natural-aspect strip', () {
    testWidgets('uses 220 dp strip with BoxFit.fitHeight and opens tapped index',
        (tester) async {
      final pics = [
        Picture(large: 'https://cdn.myanimelist.net/images/anime/1/1.jpg'),
        Picture(large: 'https://cdn.myanimelist.net/images/anime/1/2.jpg'),
        Picture(large: 'https://cdn.myanimelist.net/images/anime/1/3.jpg'),
      ];
      await tester.pumpWidget(_app(AnimePictures(pictures: pics)));

      expect(AnimePictures.stripHeight, 220);
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(3));
      for (final img in images) {
        expect(img.fit, BoxFit.fitHeight);
        expect(img.height, 220);
      }

      await tester.tap(find.byType(InkWell).at(2));
      await tester.pump();
      expect(find.text('3 / 3'), findsOneWidget);
    });
  });

  group('Details News direct-MAL-first and compact card', () {
    tearDown(() {
      JikanFallbacks.reset();
      ShowAnimeNews.resetLoader();
    });

    testWidgets('prefers direct MAL news with date, comments, and 105x156 cover',
        (tester) async {
      final original = JikanClient.instance;
      addTearDown(() => JikanClient.instance = original);

      JikanClient.instance = JikanClient(
        client: MockClient((_) async => throw http.ClientException('unused')),
        minInterval: Duration.zero,
      );
      JikanFallbacks.news = (id, category) async => [
            AnimeNews(
              malId: 901,
              title: 'Season 2 Confirmed for Spring',
              excerpt: 'The official website announced a second cour.',
              authorUsername: 'Aiimee',
              date: '2026-06-30T09:26:00+00:00',
              comments: 42,
              images: Images(
                jpg: Jpg(imageUrl: 'https://cdn.myanimelist.net/r/100x156/s/common/news.jpg'),
              ),
            ),
          ];

      await tester.pumpWidget(_app(const SingleChildScrollView(
        child: ShowAnimeNews(animeId: 1),
      )));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Season 2 Confirmed for Spring'), findsOneWidget);
      expect(find.text('Aiimee'), findsOneWidget);
      expect(find.text('Jun 30, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      final cover = tester.widget<AppImage>(find.byType(AppImage).first);
      expect(cover.width, 105);
      expect(cover.height, 156);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to Jikan and keeps non-ISO date strings visible',
        (tester) async {
      final original = JikanClient.instance;
      addTearDown(() => JikanClient.instance = original);

      JikanFallbacks.news = (id, category) async => throw Exception('blocked');
      JikanClient.instance = JikanClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'pagination': {'has_next_page': false},
                'data': [
                  {
                    'mal_id': 902,
                    'title': 'Fallback Article',
                    'date': 'Jun 30, 9:26 AM',
                    'author_username': 'NewsBot',
                    'comments': 9,
                    'excerpt': 'Short fallback summary.',
                  },
                ],
              }),
              200,
            )),
        minInterval: Duration.zero,
      );

      await tester.pumpWidget(_app(const SingleChildScrollView(
        child: ShowAnimeNews(animeId: 1),
      )));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Fallback Article'), findsOneWidget);
      expect(find.text('Jun 30, 9:26 AM'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Grid airing band and Comfortable Grid bar', () {
    tearDown(() => AiringSchedule.instance.reset());

    test('gridAiringText returns compact weekday, time, and countdown without Ep prefix', () {
      final now = DateTime.utc(2026, 11, 20, 12, 0);
      final airsAt = now.add(const Duration(days: 5, hours: 2));
      AiringSchedule.instance.replace([
        LiveChartEpisode(
          timestamp: airsAt.millisecondsSinceEpoch ~/ 1000,
          episode: 8,
          malId: 52991,
        ),
      ], now: now);

      const entry = ListEntryView(
        id: 52991,
        malId: 52991,
        category: 'anime',
        title: 'Frieren',
        status: ListEntryStatus.current,
        progress: 7,
        total: 28,
        releaseState: ReleaseState.releasing,
      );

      final text = gridAiringText(entry, now, 'en')!;
      final local = airsAt.toLocal();
      final expectedDay = DateFormat.E('en').format(local);
      expect(text, startsWith(expectedDay));
      expect(text, contains(' · '));
      expect(text, contains('in 5d 2h'));
      expect(text, isNot(contains('Ep.')));
    });

    testWidgets('GridCardBar hides members count while keeping mean score', (tester) async {
      const entry = ListEntryView(
        id: 52991,
        malId: 52991,
        category: 'anime',
        title: 'Frieren',
        status: ListEntryStatus.current,
        meanScore: 8.5,
        members: 125000,
      );

      await tester.pumpWidget(_app(SizedBox(
        width: 150,
        child: GridCardBar(entry: entry, onEdit: () {}),
      )));

      expect(find.text('8.50'), findsOneWidget);
      expect(find.textContaining('125'), findsNothing);
    });
  });

  group('Search MediaTile overflow and unrated members alignment', () {
    testWidgets('renders compact, comfortable, and spacious without overflow',
        (tester) async {
      final item = Anime(
        id: 52991,
        title: 'Sousou no Frieren: A Very Long Title That Spans Two Lines Easily',
        imageUrl: '',
        score: 9.3,
        members: 1540000,
        numEpisodes: 28,
        mediaType: 'tv',
        status: 'currently_airing',
        synopsis: 'After a ten-year quest to defeat the Demon King, '
            'the elf mage Frieren begins a new journey to understand humanity.',
      );

      for (final size in MediaTileSize.values) {
        await tester.pumpWidget(_app(SizedBox(
          width: 360,
          child: MediaTile(
            item: item,
            category: SearchCategory.anime,
            size: size,
            index: 0,
          ),
        )));
        expect(tester.takeException(), isNull, reason: 'overflow in $size');
      }
    });

    testWidgets('shows flush-left people icon when score is zero', (tester) async {
      final unrated = Anime(
        id: 60000,
        title: 'Upcoming Original Anime',
        imageUrl: '',
        score: 0,
        members: 42500,
        mediaType: 'tv',
      );

      await tester.pumpWidget(_app(SizedBox(
        width: 360,
        child: MediaTile(
          item: unrated,
          category: SearchCategory.anime,
          size: MediaTileSize.comfortable,
          index: 0,
        ),
      )));

      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.textContaining('('), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Embedded video URL parsing', () {
    test('extracts video id from standard and short links', () {
      expect(
        YoutubePlayerController.convertUrlToId(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubePlayerController.convertUrlToId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });
  });
}
