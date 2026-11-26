import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mwl_commons/mwl_commons.dart' show HtmlParsers;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_character.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_episode.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_picture.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_staff.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_animeuserupdate.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_characterfull.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_genre.dart' as jg;
import 'package:mywatchlist/services/api/Jikan/jikan_personfull.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_producer.dart' as jp;
import 'package:mywatchlist/services/api/Jikan/jikan_producerfull.dart' as jpf;
import 'package:mywatchlist/services/api/MAL/anime_graph_builder.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/forum/bbcode_widget.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';

void main() {
  group('jikan-edge v1 parsing + Tenrai backwards compatibility', () {
    test('JikanAnime & MalAnime & Anime parse jikan-edge camelCase, images, aired, volumes, serializations', () {
      final animeJson = {
        'malId': 16498,
        'url': 'https://myanimelist.net/anime/16498',
        'title': 'Shingeki no Kyojin',
        'titleEnglish': 'Attack on Titan',
        'titleJapanese': '進撃の巨人',
        'titleSynonyms': ['AoT'],
        'imageUrl': 'https://cdn.myanimelist.net/images/anime/10/47347.jpg',
        'images': {
          'small': 'https://cdn.myanimelist.net/images/anime/10/47347t.jpg',
          'medium': 'https://cdn.myanimelist.net/images/anime/10/47347.jpg',
          'large': 'https://cdn.myanimelist.net/images/anime/10/47347l.jpg',
        },
        'type': 'TV',
        'episodes': 25,
        'score': 8.55,
        'scoredBy': 2800000,
        'members': 4000000,
        'aired': {'from': '2013-04-07', 'to': '2013-09-29', 'string': 'Apr 7, 2013 to Sep 29, 2013'},
        'genres': [
          {'malId': 1, 'name': 'Action', 'url': 'https://myanimelist.net/anime/genre/1'}
        ],
        'studios': [
          {'malId': 858, 'name': 'Wit Studio', 'url': 'https://myanimelist.net/anime/producer/858'}
        ],
        'rating': 'R - 17+ (violence & profanity)',
      };
      final j = JikanAnime.fromJson(animeJson);
      expect(j.malId, 16498);
      expect(j.titleEnglish, 'Attack on Titan');
      expect(j.images?.jpg?.largeImageUrl, 'https://cdn.myanimelist.net/images/anime/10/47347l.jpg');
      expect(j.aired?.from, '2013-04-07');
      expect(j.aired?.string, 'Apr 7, 2013 to Sep 29, 2013');
      expect(j.studios?.single.name, 'Wit Studio');

      final mal = MalAnime.fromJikanFullById(animeJson);
      expect(mal.id, 16498);
      expect(mal.mainPicture?.large, 'https://cdn.myanimelist.net/images/anime/10/47347l.jpg');
      expect(mal.alternativeTitles?.en, 'Attack on Titan');

      final card = Anime.fromJikanJson({
        'malId': 2,
        'title': 'Berserk',
        'imageUrl': 'https://cdn.example/berserk.jpg',
        'volumes': 42,
        'startDate': '1989-08-25',
        'score': 9.47,
        'members': 700000,
      });
      expect(card.id, 2);
      expect(card.imageUrl, 'https://cdn.example/berserk.jpg');
      expect(card.numVolumes, 42);
      expect(card.startDate, '1989-08-25');

      final mangaFull = JikanAnime.fromJson({
        'malId': 2,
        'title': 'Berserk',
        'volumes': 42,
        'chapters': 376,
        'published': {'from': '1989-08-25', 'to': null, 'string': 'Aug 25, 1989 to ?'},
        'serializations': [
          {'malId': 2, 'name': 'Young Animal', 'url': 'https://myanimelist.net/manga/magazine/2'}
        ],
      });
      expect(mangaFull.volumes, 42);
      expect(mangaFull.serializations?.single.name, 'Young Animal');
      expect(mangaFull.aired?.from, '1989-08-25');
    });

    test('characters, staff, episodes, reviews, news, forum, videos, pictures, stats, userupdates parse jikan-edge', () {
      final ch = AnimeCharacter.fromJson({
        'malId': 46496,
        'name': 'Ral, Petra',
        'imageUrl': 'https://cdn.example/petra.jpg',
        'role': 'Supporting',
        'favorites': 1234,
        'voiceActors': [
          {'malId': 2123, 'name': 'Aikawa, Natsuki', 'language': 'Japanese', 'imageUrl': 'https://cdn.example/va.jpg'}
        ],
      });
      expect(ch.character.malId, 46496);
      expect(ch.character.images?.jpg?.imageUrl, 'https://cdn.example/petra.jpg');
      expect(ch.voiceActors?.single.person?.name, 'Aikawa, Natsuki');

      final st = AnimeStaff.fromJson({
        'malId': 5088,
        'name': 'Araki, Tetsurou',
        'imageUrl': 'https://cdn.example/araki.jpg',
        'role': 'Director, Storyboard',
      });
      expect(st.person.malId, 5088);
      expect(st.positions, ['Director', 'Storyboard']);

      final eps = AnimeEpisodesResponse.fromJson({
        'data': [
          {'number': 1, 'title': 'To You, 2,000 Years in the Future', 'url': 'https://mal/ep/1', 'filler': false, 'recap': false}
        ],
        'meta': {
          'cached': true,
          'stale': true,
          'pagination': {'page': 1, 'limit': 100, 'count': 1, 'total': null, 'hasNextPage': true}
        },
      });
      expect(eps.data.single.malId, 1);
      expect(eps.pagination.hasNextPage, isTrue);

      final rev = AnimeReviewsResponse.fromJson({
        'data': [
          {
            'username': 'alice',
            'imageUrl': 'https://cdn.example/u.jpg',
            'date': '2026-01-01',
            'tag': 'Recommended',
            'score': 9,
            'reviewText': 'Great show',
            'reviewId': 999,
            'isPreliminary': true,
            'isSpoiler': false,
            'episodesWatched': 12,
            'reactions': {'overall': 10, 'nice': 5, 'loveIt': 3, 'wellWritten': 2},
          }
        ],
        'meta': {
          'pagination': {'page': 1, 'limit': 20, 'count': 1, 'total': null, 'hasNextPage': false}
        },
      });
      expect(rev.data.single.user?.username, 'alice');
      expect(rev.data.single.review, 'Great show');
      expect(rev.data.single.tags, containsAll(['Recommended', 'Preliminary']));
      expect(rev.data.single.reactions?.loveIt, 3);
      expect(rev.pagination.hasNextPage, isFalse);

      final news = AnimeNewsResponse.fromJson({
        'data': [
          {'malId': 1, 'title': 'News 1', 'url': 'https://mal/news/1', 'imageUrl': 'https://cdn/n.jpg', 'author': 'bob'}
        ],
        'meta': {'cached': true},
      });
      expect(news.data.single.authorUsername, 'bob');
      expect(news.pagination.hasNextPage, isFalse);

      final forum = AnimeForumResponse.fromJson({
        'data': [
          {'topicId': 42, 'title': 'Ep 1 Discussion', 'startedBy': 'mod', 'replies': 500, 'lastPostBy': 'charlie'}
        ],
      });
      expect(forum.data.single.malId, 42);
      expect(forum.data.single.comments, 500);
      expect(forum.data.single.lastComment?.authorUsername, 'charlie');

      final videos = AnimeVideos.fromJson({
        'promos': [
          {'title': 'PV 1', 'videoUrl': 'https://www.youtube-nocookie.com/embed/LHtdKWJdif4?autoplay=1', 'imageUrl': 'https://i.ytimg.com/vi/LHtdKWJdif4/mqdefault.jpg'}
        ],
        'musicVideos': [
          {'title': 'ED 1', 'videoUrl': 'https://www.youtube-nocookie.com/embed/kgZRAyVMcB8?autoplay=1', 'imageUrl': 'https://i.ytimg.com/vi/kgZRAyVMcB8/mqdefault.jpg'}
        ],
        'episodes': [
          {'episode': 25, 'title': 'Finale', 'url': 'https://mal/ep/25', 'imageUrl': 'https://cdn/ep25.jpg'}
        ],
      });
      expect(videos.promo?.single.trailer?.youtubeId, 'LHtdKWJdif4');
      expect(videos.musicVideos?.single.video?.youtubeId, 'kgZRAyVMcB8');
      expect(videos.episodes?.single.episode, 'Episode 25');

      final pics = AnimePicturesResponse.fromJson({
        'data': [
          {'imageUrl': 'https://cdn/full.jpg', 'thumbnailUrl': 'https://cdn/thumb.jpg'}
        ],
      });
      expect(pics.data.single.jpg?.imageUrl, 'https://cdn/full.jpg');

      final stats = AnimeStatistics.fromJson({
        'status': {'inProgress': 10, 'completed': 20, 'onHold': 3, 'dropped': 4, 'planned': 5, 'total': 42},
        'scores': [
          {'score': 10, 'votes': 100, 'percentage': 50.0}
        ],
      });
      expect(stats.watching, 10);
      expect(stats.planToWatch, 5);
      expect(stats.total, 42);

      final updates = AnimeUserUpdatesResponse.fromJson({
        'data': [
          {'username': 'dave', 'imageUrl': 'https://cdn/d.jpg', 'score': 8, 'status': 'Watching', 'progress': 5, 'total': 12, 'date': '2026-01-01'}
        ],
      });
      expect(updates.data.single.user?.username, 'dave');
      expect(updates.data.single.episodesSeen, 5);
      expect(updates.pagination.hasNextPage, isFalse);

      final cf = CharacterFull.fromJson({
        'malId': 45627,
        'name': 'Levi',
        'nameKanji': 'リヴァイ',
        'images': {'small': null, 'medium': 'https://cdn/levi.jpg', 'large': null},
        'anime': [
          {'malId': 16498, 'title': 'SnK', 'imageUrl': 'https://cdn/snk.jpg', 'role': 'Main'}
        ],
        'voices': [
          {'malId': 118, 'name': 'Kamiya, Hiroshi', 'imageUrl': 'https://cdn/hk.jpg', 'language': 'Japanese'}
        ],
      });
      expect(cf.malId, 45627);
      expect(cf.anime?.single.anime?.title, 'SnK');
      expect(cf.voices?.single.person?.name, 'Kamiya, Hiroshi');

      final pf = PersonFull.fromJson({
        'malId': 118,
        'name': 'Kamiya, Hiroshi',
        'givenName': 'Hiroshi',
        'familyName': 'Kamiya',
        'imageUrl': 'https://cdn/hk.jpg',
        'voices': [
          {'animeId': 16498, 'animeTitle': 'SnK', 'characterId': 45627, 'characterName': 'Levi', 'characterRole': 'Main'}
        ],
      });
      expect(pf.givenName, 'Hiroshi');
      expect(pf.voices?.single.character?.name, 'Levi');

      final prod = jp.ProducersResponse.fromJson({
        'data': [
          {'malId': 569, 'name': 'MAPPA', 'count': 100, 'url': 'https://mal/producer/569'}
        ],
      });
      expect(prod.data.single.titles?.single.title, 'MAPPA');

      final prodFull = jpf.ProducerFull.fromJson({
        'malId': 569,
        'name': 'MAPPA',
        'imageUrl': 'https://cdn/mappa.jpg',
      });
      expect(prodFull.titles?.single.title, 'MAPPA');

      final genres = jg.GenreResponse.fromJson({
        'data': [
          {'malId': 1, 'name': 'Action', 'url': 'https://mal/genre/1', 'count': 5000}
        ],
      });
      expect(genres.data.single.malId, 1);

      final reco = CommunityRecommendation.fromJikan({
        'malId': 1,
        'title': 'Cowboy Bebop',
        'imageUrl': 'https://cdn/1.jpg',
        'recommendedMalId': 205,
        'recommendedTitle': 'Samurai Champloo',
        'recommendedImageUrl': 'https://cdn/205.jpg',
        'content': 'Same director',
        'username': 'xinil',
      });
      expect(reco?.first.id, 1);
      expect(reco?.second.id, 205);
      expect(reco?.username, 'xinil');

      final userStats = ListStats.fromJikan(
        {'meanScore': 7.5, 'totalEntries': 100, 'daysWatched': 50.0, 'episodesWatched': 1200, 'watching': 3, 'completed': 80, 'onHold': 2, 'dropped': 5, 'planToWatch': 10},
        manga: false,
      );
      expect(userStats.meanScore, 7.5);
      expect(userStats.onHold, 2);
      expect(userStats.planned, 10);

      final merged = UserProfileRepository.merge('Xinil', jikan: {
        'profile': {
          'username': 'Xinil',
          'avatarUrl': 'https://cdn/xinil.jpg',
          'location': 'USA',
          'joinedAt': '2004-11-05',
          'lastOnlineAt': 'Now',
        },
        'statistics': {
          'anime': {'watching': 1, 'completed': 233, 'onHold': 8, 'dropped': 93, 'planToWatch': 64, 'totalEntries': 399},
          'manga': {'reading': 15, 'completed': 10, 'onHold': 2, 'dropped': 1, 'planToRead': 20, 'totalEntries': 48},
        },
        'favorites': {
          'anime': [
            {'malId': 1, 'title': 'Cowboy Bebop', 'imageUrl': 'https://cdn/1.jpg'}
          ],
        },
      });
      expect(merged.pictureUrl, 'https://cdn/xinil.jpg');
      expect(merged.anime.completed, 233);
      expect(merged.manga.planned, 20);
      expect(merged.favorites.anime.single.title, 'Cowboy Bebop');
    });
  });

  group('Section 3: parseUserClubs excludes forum topicid= and about-me links', () {
    test('ignores forum/?topicid= links and deduplicates real club links', () {
      const html = '''
        <div class="user-profile-about">
          <ul>
            <li><a href="https://myanimelist.net/forum/?topicid=12345">Some Forum Thread</a></li>
            <li><a href="https://myanimelist.net/clubs.php?cid=777">Club Mentioned In Bio</a></li>
          </ul>
        </div>
        <div class="user-clubs">
          <ul>
            <li><a href="https://myanimelist.net/forum/?topicid=99999">Fake Club</a></li>
            <li><a href="https://myanimelist.net/clubs.php?cid=42">Real Club One</a></li>
            <li><a href="https://myanimelist.net/clubs.php?cid=42">Real Club One Duplicate</a></li>
            <li><a href="https://myanimelist.net/clubs/100">Real Club Two</a></li>
          </ul>
        </div>
      ''';
      final result = HtmlParsers.parseUserClubs(html_parser.parse(html));
      final clubs = (result['clubs'] as List).cast<Map<String, dynamic>>();
      expect(clubs, [
        {'id': 42, 'name': 'Real Club One'},
        {'id': 100, 'name': 'Real Club Two'},
      ]);
    });
  });

  group('Section 4: Native SearchFilters ranking and season presets', () {
    test('maps anime/manga rankings and seasons into composable filters', () {
      final airing = SearchFilters.forAnimeRanking(RankingType.AIRING);
      expect(airing.text(FilterKey.status), 'airing');
      expect(airing.text(FilterKey.orderBy), 'score');
      expect(airing.matchAnimeRanking(), RankingType.AIRING);

      // Adding a genre breaks the exact unmodified preset match so filtered search runs.
      final airingCgdct = airing.set(FilterKey.genresIn, [52]);
      expect(airingCgdct.matchAnimeRanking(), isNull);

      final season = SearchFilters.forSeason(SeasonType.WINTER, 2025);
      expect(season.matchSeason(), (season: SeasonType.WINTER, year: 2025));
      expect(season.seasonDateBounds, (start: '2025-01-01', end: '2025-03-31'));
      expect(season.toApiMap()['start_date'], '2025-01-01');
      expect(season.toApiMap()['end_date'], '2025-03-31');
    });
  });

  group('Section 6: Review tag normalization', () {
    test('collapses Preliminary (X/Y eps) into single Preliminary chip', () {
      final reviews = [
        AnimeReview(score: 8, tags: ['Recommended', 'Preliminary (6/28 eps)']),
        AnimeReview(score: 7, tags: ['Mixed Feelings', 'Preliminary (12/28 eps)']),
        AnimeReview(score: 9, tags: ['Recommended', 'Preliminary']),
      ];
      expect(reviewTags(reviews), ['Recommended', 'Preliminary', 'Mixed Feelings']);
      final prelim = filterReviews(reviews, tags: {'Preliminary'});
      expect(prelim, hasLength(3));
    });
  });

  group('Section 13: BBCode parser', () {
    test('preserves plain brackets, handles nested/repeated tags and strips img whitespace/br', () {
      const w = BbcodeWidget(body: '');
      expect(w.applyTransform('Item [1] [edit] [Level]'), 'Item [1] [edit] [Level]');

      final nested = w.applyTransform(
        '[color=red][img] https://cdn.example/a.png <br /> [/img][/color] [b]hi[/b] [b]hi[/b]',
      );
      expect(nested, contains('<span style="color: red;"><img src="https://cdn.example/a.png" /></span>'));
      expect(nested, contains('<b>hi</b> <b>hi</b>'));

      final spoiler = w.applyTransform('[spoiler=Ending]Secret [i]twist[/i][/spoiler]');
      expect(spoiler, '<spoiler name="Ending">Secret <i>twist</i></spoiler>');
    });
  });

  group('Section 14: Anime graph builder jikan-edge compatibility', () {
    test('AnimeGraphBuilder walks jikan-edge relations payloads', () async {
      final data = <int, Map<String, dynamic>>{
        1: {
          'malId': 1,
          'title': 'S1',
          'relations': [
            {
              'relation': 'Sequel',
              'entries': [
                {'malId': 2, 'type': 'anime', 'name': 'S2'},
              ],
            },
          ],
        },
        2: {
          'malId': 2,
          'title': 'S2',
          'relations': [
            {
              'relation': 'Prequel',
              'entries': [
                {'malId': 1, 'type': 'anime', 'name': 'S1'},
              ],
            },
          ],
        },
      };
      final builder = AnimeGraphBuilder(
        fetch: (id) async {
          final hit = data[id];
          return hit != null ? GraphFetch.ok(hit) : const GraphFetch.failed();
        },
      );
      final built = await builder.build(1);
      final graph = AnimeGraphData.fromJson(built.json);
      expect(graph.nodes.keys, containsAll([1, 2]));
      expect(graph.edges.any((e) => e.source == 1 && e.target == 2), isTrue);
    });
  });
}
