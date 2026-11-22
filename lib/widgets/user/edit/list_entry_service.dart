import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart';
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';

/// The list entry could not be loaded (HTTP error or unreadable answer).
class EntryLoadFailed implements Exception {
  final Object cause;
  const EntryLoadFailed(this.cause);
  @override
  String toString() => 'EntryLoadFailed: $cause';
}

/// Result of a list write: the new entry and the tracker status given as is
/// to `ContentEditWidget.onListStatusChange` (`MyAnimeListStatus` or
/// `MyMangaListStatus` for MAL, dates kept as MAL text).
class EntryUpdate {
  final ListEntry entry;
  final Object status;
  const EntryUpdate(this.entry, this.status);
}

/// Reads and writes the user's list entry on one tracker.
///
/// Every method may throw [MalSessionExpired] when the session is dead.
abstract class ListEntryService {
  /// False when the selected account cannot edit this list.
  bool get canEdit;

  Future<EditableContent> load(int id, {required bool isAnime});

  Future<EntryUpdate> update(int id,
      {required bool isAnime, required EntryPatch patch, ListEntry? previous});

  Future<void> delete(int id, {required bool isAnime});
}

/// [ListEntryService] on MyAnimeList, through [MalApi] (token refresh and
/// session-expired signal included).
class MalListEntryService implements ListEntryService {
  const MalListEntryService({ListStatusCache? cache}) : _cache = cache;

  final ListStatusCache? _cache;

  /// The user's statuses, updated after each write.
  ListStatusCache get statusCache => _cache ?? ListStatusCache.instance;

  // Every list field, so the sheet is pre-filled exactly as on MAL (the detail
  // page's MalAnime keeps only status, score, episodes and rewatching).
  static const String animeFields = 'id,num_episodes,status,start_date,'
      'start_season,my_list_status{status,score,num_episodes_watched,'
      'is_rewatching,num_times_rewatched,rewatch_value,priority,start_date,'
      'finish_date,tags,comments,updated_at}';
  static const String mangaFields = 'id,num_chapters,num_volumes,status,'
      'start_date,my_list_status{status,score,num_chapters_read,'
      'num_volumes_read,is_rereading,num_times_reread,reread_value,priority,'
      'start_date,finish_date,tags,comments,updated_at}';

  @override
  bool get canEdit =>
      AccountManagerSingleton().selectedAcc == AccountType.myanimelist;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) async {
    final base =
        isAnime ? Constants.malanimeEndPoint : Constants.malmangaEndPoint;
    final fields = isAnime ? animeFields : mangaFields;
    final response = await MalApi.authorizedGet('$base/$id?fields=$fields');
    // A dead session is replayed publicly: the answer then has no list
    // status, which would wrongly read as "not on the list".
    if (MalApi.sessionExpired.value) throw const MalSessionExpired();
    if (response.statusCode != 200) {
      throw EntryLoadFailed('HTTP ${response.statusCode}');
    }
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return EditableContent.fromMalJson(data, isAnime: isAnime);
    } catch (e) {
      throw EntryLoadFailed(e);
    }
  }

  @override
  Future<EntryUpdate> update(int id,
      {required bool isAnime,
      required EntryPatch patch,
      ListEntry? previous}) async {
    if (patch.clearStartDate || patch.clearFinishDate) {
      return _clearDatesViaWeb(
        id,
        isAnime: isAnime,
        clearStart: patch.clearStartDate,
        clearFinish: patch.clearFinishDate,
        previous: previous,
      );
    }
    // save*ListStatus sends the dates as given and answers the whole entry
    // with MAL's text dates, so a partial date (`2019-03`, `2019`) survives.
    final MyListStatus answer;
    if (isAnime) {
      answer = await MalApi().saveAnimeListStatus(
        animeId: id,
        status: patch.status,
        score: patch.score,
        numWatchedEpisodes: patch.progress,
        isRewatching: patch.isRepeating,
        numTimesRewatched: patch.timesRepeated,
        rewatchValue: patch.repeatValue,
        priority: patch.priority,
        startDate: patch.startDate,
        finishDate: patch.finishDate,
        tags: patch.tags,
        comments: patch.comments,
      );
    } else {
      answer = await MalApi().saveMangaListStatus(
        mangaId: id,
        status: patch.status,
        score: patch.score,
        numChaptersRead: patch.progress,
        numVolumesRead: patch.volumes,
        isRereading: patch.isRepeating,
        numTimesReread: patch.timesRepeated,
        rereadValue: patch.repeatValue,
        priority: patch.priority,
        startDate: patch.startDate,
        finishDate: patch.finishDate,
        tags: patch.tags,
        comments: patch.comments,
      );
    }
    final entry = ListEntry.fromListStatus(answer, isAnime: isAnime, previous: previous);
    // Every write keeps the user's statuses in step, wherever it comes from (detail page,
    // list, bulk edit): a title changed from its page shows its new status on every card.
    if (entry.status.isNotEmpty) {
      statusCache.put(
        id,
        CachedListStatus(status: entry.status, score: entry.score, progress: entry.progress),
        category: isAnime ? 'anime' : 'manga',
      );
    }
    return EntryUpdate(
      entry,
      // Callers of onListStatusChange (detail page) expect the typed models.
      isAnime
          ? MyAnimeListStatus.fromListStatus(answer)
          : MyMangaListStatus.fromListStatus(answer),
    );
  }

  /// Clears start and/or finish date via MAL's `/ownlist/{anime|manga}/{id}/edit` form
  /// (MAL API v2 strictly rejects empty date strings with HTTP 400).
  Future<EntryUpdate> _clearDatesViaWeb(
    int id, {
    required bool isAnime,
    required bool clearStart,
    required bool clearFinish,
    ListEntry? previous,
  }) async {
    final web = MalWebClient.instance;
    await web.session.ensureLoaded();
    if (!web.session.isConnected) {
      throw const MalWebNoSession();
    }
    final kind = isAnime ? 'anime' : 'manga';
    final prefix = isAnime ? 'add_anime' : 'add_manga';
    final editPath = '/ownlist/$kind/$id/edit';
    final pageResp = await web.get(editPath);
    if (pageResp.statusCode != 200) {
      throw MalWebActionFailed(statusCode: pageResp.statusCode);
    }
    final doc = html_parser.parse(pageResp.body);
    final form = doc.querySelector('form[name="main_form"]') ?? doc.querySelector('form');
    if (form == null) {
      throw const MalWebActionFailed(message: 'Edit form not found');
    }
    final fields = <String, String>{};
    for (final input in form.querySelectorAll('input')) {
      final name = input.attributes['name'];
      if (name == null || name.isEmpty || name == 'csrf_token') continue;
      final type = (input.attributes['type'] ?? 'text').toLowerCase();
      if ((type == 'checkbox' || type == 'radio') &&
          !input.attributes.containsKey('checked')) {
        continue;
      }
      if (type == 'submit' || type == 'button' || type == 'reset') continue;
      fields[name] = input.attributes['value'] ?? '';
    }
    for (final select in form.querySelectorAll('select')) {
      final name = select.attributes['name'];
      if (name == null || name.isEmpty) continue;
      final selected = select.querySelector('option[selected]');
      fields[name] = selected?.attributes['value'] ?? '';
    }
    for (final textarea in form.querySelectorAll('textarea')) {
      final name = textarea.attributes['name'];
      if (name == null || name.isEmpty) continue;
      fields[name] = textarea.text;
    }
    if (clearStart) {
      fields['$prefix[start_date][year]'] = '';
      fields['$prefix[start_date][month]'] = '';
      fields['$prefix[start_date][day]'] = '';
    }
    if (clearFinish) {
      fields['$prefix[finish_date][year]'] = '';
      fields['$prefix[finish_date][month]'] = '';
      fields['$prefix[finish_date][day]'] = '';
    }
    fields['submitIt'] = '0';

    final postResp = await web.postForm(
      editPath,
      fields,
      referer: '${MalWebClient.base}$editPath',
    );
    if (postResp.statusCode >= 400) {
      throw MalWebActionFailed(statusCode: postResp.statusCode);
    }
    final reloaded = await load(id, isAnime: isAnime);
    final prev = previous ?? const ListEntry(status: '');
    final updated = reloaded.entry ??
        ListEntry(
          status: prev.status,
          score: prev.score,
          progress: prev.progress,
          volumes: prev.volumes,
          isRepeating: prev.isRepeating,
          timesRepeated: prev.timesRepeated,
          repeatValue: prev.repeatValue,
          priority: prev.priority,
          startDate: clearStart ? null : prev.startDate,
          finishDate: clearFinish ? null : prev.finishDate,
          tags: prev.tags,
          comments: prev.comments,
        );
    final statusObj = isAnime
        ? MyAnimeListStatus(
            status: updated.status,
            score: updated.score,
            numEpisodesWatched: updated.progress,
            isRewatching: updated.isRepeating,
            startDate: updated.startDate,
            finishDate: updated.finishDate,
          )
        : MyMangaListStatus(
            status: updated.status,
            score: updated.score,
            numChaptersRead: updated.progress,
            numVolumesRead: updated.volumes,
            isRereading: updated.isRepeating,
            startDate: updated.startDate,
            finishDate: updated.finishDate,
          );
    return EntryUpdate(updated, statusObj);
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {
    await (isAnime ? MalApi().deleteAnimeFromList(id) : MalApi().deleteMangaFromList(id));
    statusCache.remove(id, category: isAnime ? 'anime' : 'manga');
  }
}
