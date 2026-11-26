import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_images.dart';
import 'package:mywatchlist/screens/search/search_articles_parser.dart';
import 'package:mywatchlist/screens/search/search_queries.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_animeuserupdate.dart'
    as user_updates;
import 'package:mywatchlist/services/api/MAL/scrapper/title_clubs.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';
import 'package:mywatchlist/user/preferences/general_preferences.dart';
import 'package:mywatchlist/user/preferences/sidebar_preferences.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/edit_swipe.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../edit-sheet/fixtures.dart';

class _StubEntryService implements ListEntryService {
  final patches = <EntryPatch>[];

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
    patches.add(patch);
    final p = previous ?? const ListEntry(status: 'completed');
    final next = ListEntry(
      status: patch.status ?? p.status,
      score: patch.score ?? p.score,
      progress: patch.progress ?? p.progress,
      comments: patch.comments ?? p.comments,
    );
    return EntryUpdate(next, next);
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

  group('DataSource & JikanMuteDuration', () {
    test('uses Jikan label and 1d/3d/1w durations defaulting to oneDay', () {
      expect(DataSource.jikan.label, 'Jikan');
      expect(
        JikanMuteDuration.values,
        [JikanMuteDuration.oneDay, JikanMuteDuration.threeDays, JikanMuteDuration.oneWeek],
      );
      expect(JikanMuteDuration.fallback, JikanMuteDuration.oneDay);
      expect(JikanMuteDuration.byName(null), JikanMuteDuration.oneDay);
      expect(JikanMuteDuration.byName('oneMonth'), JikanMuteDuration.oneDay);
      expect(JikanMuteDuration.oneDay.duration, const Duration(days: 1));
      expect(JikanMuteDuration.threeDays.duration, const Duration(days: 3));
      expect(JikanMuteDuration.oneWeek.duration, const Duration(days: 7));
    });
  });

  group('MalListEntryService.extractClearDateForm', () {
    test('extracts form#main-form and clears start/finish date fields with submitIt=1', () {
      const html = '''
<html><body>
<form id="main-form" action="https://myanimelist.net/ownlist/anime/5114/edit?hideLayout=1" method="post">
  <input type="hidden" name="csrf_token" value="tok123">
  <select name="add_anime[status]"><option value="2" selected>Completed</option></select>
  <select name="add_anime[start_date][month]"><option value="">--</option><option value="1" selected>Jan</option></select>
  <select name="add_anime[start_date][day]"><option value="">--</option><option value="5" selected>5</option></select>
  <select name="add_anime[start_date][year]"><option value="">--</option><option value="2019" selected>2019</option></select>
  <select name="add_anime[finish_date][month]"><option value="">--</option><option value="3" selected>Mar</option></select>
  <select name="add_anime[finish_date][day]"><option value="">--</option><option value="10" selected>10</option></select>
  <select name="add_anime[finish_date][year]"><option value="">--</option><option value="2019" selected>2019</option></select>
</form>
</body></html>''';
      final extracted = MalListEntryService.extractClearDateForm(
        html,
        isAnime: true,
        clearStart: true,
        clearFinish: false,
        fallbackPath: '/ownlist/anime/5114/edit',
      );
      expect(extracted, isNotNull);
      expect(extracted!.actionPath, '/ownlist/anime/5114/edit?hideLayout=1');
      expect(extracted.fields['csrf_token'], 'tok123');
      expect(extracted.fields['add_anime[status]'], '2');
      expect(extracted.fields['add_anime[start_date][month]'], '');
      expect(extracted.fields['add_anime[start_date][day]'], '');
      expect(extracted.fields['add_anime[start_date][year]'], '');
      expect(extracted.fields['add_anime[finish_date][month]'], '3');
      expect(extracted.fields['add_anime[finish_date][day]'], '10');
      expect(extracted.fields['add_anime[finish_date][year]'], '2019');
      expect(extracted.fields['submitIt'], '1');
    });
  });

  group('External browser default', () {
    tearDown(() {
      WebLauncher.opener = defaultUrlOpener;
    });

    testWidgets('launchWebView passes external: true by default', (tester) async {
      bool? capturedExternal;
      WebLauncher.opener = (uri, {barColor, onBarColor, external = false}) async {
        capturedExternal = external;
        return true;
      };
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));
      await launchWebView('https://example.com', context: ctx);
      expect(capturedExternal, isTrue);
    });
  });

  group('parseLatestArticles', () {
    test('parses .box-unit3 cards when present', () {
      const html = '''
<html><body>
<div class="box-unit3">
  <a href="https://myanimelist.net/news/888"><img src="https://cdn.example/a.jpg"></a>
  <div class="title"><a href="https://myanimelist.net/news/888">Spring Lineup</a></div>
  <div class="text">Lots of new shows.</div>
</div>
</body></html>''';
      final res = parseLatestArticles(html);
      expect(res.newsorfeatured, hasLength(1));
      expect(res.newsorfeatured.single.id, 888);
      expect(res.newsorfeatured.single.title, 'Spring Lineup');
    });
  });

  group('Server-side MAL reviews mapping', () {
    test('exposes only MAL-supported sorts and maps tags/flags to query params', () {
      expect(ReviewSort.values, [ReviewSort.helpful, ReviewSort.newest, ReviewSort.oldest]);
      expect(ReviewSort.helpful.malParam, 'mostvoted');
      expect(ReviewSort.newest.malParam, 'newest');
      expect(ReviewSort.oldest.malParam, 'oldest');
      expect(malReviewAllTags, containsAll(['Recommended', 'Mixed Feelings', 'Not Recommended', 'Preliminary', 'Spoiler']));
      final mapped = malReviewQueryForTags({'Creative', 'Not Recommended', 'Preliminary (4/12 eps)'});
      expect(mapped.filterCheck, '3,7');
      expect(mapped.preliminary, 'on');
      expect(mapped.spoiler, isNull);
    });
  });

  group('QuickEditModalSheet & plain inline comments', () {
    testWidgets('uses DraggableScrollableSheet without EditSwipeArea and renders inline comments TextField',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final service = _StubEntryService();
      await tester.pumpWidget(_app(QuickEditModalSheet.editor(
        editorBuilder: (context, expanded, onExpandedChanged) => ContentEditWidget(
          id: 5114,
          category: 'anime',
          service: service,
          enableSwipe: false,
          expanded: expanded,
          onExpandedChanged: onExpandedChanged,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byType(EditSwipeArea), findsNothing);

      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Others'));
      await tester.pumpAndSettle();

      final commentsField = find.byKey(const ValueKey('edit-comments'));
      expect(commentsField, findsOneWidget);
      expect(tester.widget(commentsField), isA<TextField>());
      await tester.enterText(commentsField, 'Updated note');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(service.patches.any((p) => p.comments == 'Updated note'), isTrue);
    });
  });

  group('ClubPictures lazy resolver', () {
    tearDown(() => ClubPictures.instance.reset());

    test('caches resolved club URLs and caps concurrency at 3', () async {
      final completers = <int, Completer<String?>>{};
      var currentInFlight = 0;
      var maxInFlight = 0;
      ClubPictures.instance.fetcher = (id) {
        currentInFlight++;
        if (currentInFlight > maxInFlight) maxInFlight = currentInFlight;
        final c = Completer<String?>();
        completers[id] = c;
        return c.future.whenComplete(() => currentInFlight--);
      };

      for (final id in [1, 2, 3, 4, 5]) {
        ClubPictures.instance.ensure(id);
      }
      expect(maxInFlight, 3);
      expect(completers.keys, unorderedEquals([1, 2, 3]));

      completers[1]!.complete('https://cdn.example/c1.jpg');
      await Future<void>.delayed(Duration.zero);
      expect(ClubPictures.instance.pictureOf(1), 'https://cdn.example/c1.jpg');
      expect(completers.containsKey(4), isTrue);

      for (final id in [2, 3, 4]) {
        completers[id]!.complete('https://cdn.example/c$id.jpg');
      }
      await Future<void>.delayed(Duration.zero);
      completers[5]!.complete('https://cdn.example/c5.jpg');
      await Future<void>.delayed(Duration.zero);
      expect(ClubPictures.instance.pictureOf(5), 'https://cdn.example/c5.jpg');
    });
  });

  group('UserUpdatesGrid total episodes fallback', () {
    testWidgets('shows 0/25 instead of -/- when episodesSeen is null and totalEpisodes is known',
        (tester) async {
      await tester.pumpWidget(_app(UserUpdatesGrid(
        updates: [
          user_updates.AnimeUserUpdate(
            user: user_updates.User(username: 'alice'),
            status: 'Watching',
            episodesSeen: null,
            episodesTotal: null,
          ),
        ],
        category: 'anime',
        horizPadding: 0,
        totalEpisodes: 25,
      )));
      expect(find.text('0/25'), findsOneWidget);
      expect(find.text('-/-'), findsNothing);
    });
  });

  group('StatusPill merged rewatch indicator', () {
    testWidgets('renders Completed and replay ×N in one pill when includeRewatch is true',
        (tester) async {
      const entry = ListEntryView(
        id: 1,
        category: 'anime',
        title: 'Frieren',
        status: ListEntryStatus.completed,
        timesRewatched: 2,
      );
      await tester.pumpWidget(_app(const StatusPill(entry: entry, includeRewatch: true)));
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
    });
  });

  group('SidebarPreferences', () {
    test('defaults match master order, normalize deduplicates and appends missing items, JSON round-trips', () {
      expect(
        defaultSidebarItems.map((e) => e.item).toList(),
        [
          SidebarItem.stats,
          SidebarItem.about,
          SidebarItem.friends,
          SidebarItem.clubs,
          SidebarItem.favorites,
          SidebarItem.history,
          SidebarItem.bookmarks,
          SidebarItem.calendar,
          SidebarItem.notifications,
          SidebarItem.messages,
        ],
      );
      final normalized = normalizeSidebarItems([
        const SidebarItemPreference(SidebarItem.calendar, visible: false),
        const SidebarItemPreference(SidebarItem.calendar, visible: true),
      ]);
      expect(normalized.first, const SidebarItemPreference(SidebarItem.calendar, visible: false));
      expect(normalized, hasLength(SidebarItem.values.length));

      final encoded = encodeSidebarItems(normalized);
      expect(decodeSidebarItems(encoded), normalized);
    });
  });

  group('Search tag suggestions preference', () {
    test('showTagSuggestions defaults to false and survives JSON round-trip', () {
      const defaults = GeneralPreferences();
      expect(defaults.showTagSuggestions, isFalse);
      final enabled = defaults.copyWith(showTagSuggestions: true);
      expect(GeneralPreferences.fromJson(enabled.toJson()).showTagSuggestions, isTrue);

      final matches = SpecialQuery.suggestions('#air', DateTime(2026));
      expect(matches.any((m) => m.query == '#airing'), isTrue);
      expect(SpecialQuery.suggestions('plain'), isEmpty);
    });
  });

  group('InterestStackPictures decorative stack', () {
    testWidgets('is non-interactive (IgnorePointer) and renders layered covers', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(
        width: 140,
        height: 200,
        child: InterestStackPictures(images: ['https://cdn.example/1.jpg', 'https://cdn.example/2.jpg']),
      )));
      expect(
        find.descendant(
          of: find.byType(InterestStackPictures),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(InterestStackPictures),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });
  });

  group('ExploreImages aliases', () {
    test('resolves Urban Fantasy and Villainess artwork', () {
      expect(ExploreImages.genre(82, 'anime'), isNotNull);
      expect(ExploreImages.genre(83, 'anime'), isNotNull);
      expect(ExploreImages.genre(83, 'manga'), isNotNull);
    });
  });
}
