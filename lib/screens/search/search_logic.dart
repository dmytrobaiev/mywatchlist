part of 'general_search_screen.dart';

/// The search flow: running a search, loading the next page, autocomplete, applying the panel.
extension _SearchLogic on _GeneralSearchScreenState {
  void _onTextChanged() {
    final text = _searchController.text;
    final prev = _lastQueryText;
    // Two-step backspace on an active `#...` special tag: `#favorite@manga`
    // strips `@manga` first, and a second backspace clears `#favorite`.
    final stepped = SpecialQuery.stepBackspace(
      prev,
      text,
      wasSpecialTag: _specialQuery || _specialTagBackspace,
    );
    if (stepped != null) {
      _lastQueryText = stepped;
      _searchController.value = stepped.isEmpty
          ? const TextEditingValue()
          : TextEditingValue(
              text: stepped,
              selection: TextSelection.collapsed(offset: stepped.length),
            );
      final stillSpecial =
          stepped.startsWith('#') && SpecialQuery.parse(stepped.substring(1)) != null;
      _set(() {
        _specialQuery = stillSpecial;
        _specialTagBackspace = stepped.startsWith('#');
        _filters = SearchFilters.empty;
      });
      if (_stage != SearchStage.notStarted) _resetResults();
      _scheduleSuggestions(stepped);
      return;
    }
    _lastQueryText = text;
    final special = text.startsWith('#') && SpecialQuery.parse(text.substring(1)) != null;
    if (special) {
      _specialTagBackspace = true;
    } else if (!text.startsWith('#')) {
      _specialTagBackspace = false;
    }
    if (special != _specialQuery) _set(() => _specialQuery = special);
    if (text.isEmpty && _stage != SearchStage.notStarted) {
      _resetResults();
    }
    _scheduleSuggestions(text);
  }

  void _resetResults() {
    _searchToken++;
    _set(() {
      _stage = SearchStage.notStarted;
      _loadMoreStage = SearchStage.notStarted;
      _page = null;
      _request = null;
    });
  }

  /// Autocomplete: anime and manga titles for three letters or more, after a pause in typing,
  /// only while no search is showing. When `showTagSuggestions` is enabled in Settings, also
  /// suggests matching `#...` special tags while typing `#...`.
  void _scheduleSuggestions(String text) {
    _suggestTimer?.cancel();
    final query = text.trim();
    if (_stage == SearchStage.notStarted &&
        query.startsWith('#') &&
        Preferences.general.showTagSuggestions) {
      final specials = SpecialQuery.suggestions(query);
      if (specials.isEmpty) {
        if (_suggestions.value.isActive) _suggestions.value = SuggestionState.idle;
      } else {
        _suggestions.value = SuggestionState(
          query: query,
          category: _category,
          specials: specials,
        );
      }
      return;
    }
    final category = _category == SearchCategory.manga ? SearchCategory.manga : SearchCategory.anime;
    final eligible = _stage == SearchStage.notStarted &&
        query.length >= 3 &&
        !query.startsWith('#') &&
        (_category == SearchCategory.all || SearchCategory.isMedia(_category));
    if (!eligible) {
      if (_suggestions.value.isActive) _suggestions.value = SuggestionState.idle;
      return;
    }
    _suggestions.value = SuggestionState(query: query, category: category, items: _suggestions.value.items, loading: true);
    final token = ++_suggestToken;
    _suggestTimer = Timer(_GeneralSearchScreenState._suggestDelay, () async {
      List<Anime> items;
      try {
        items = await _GeneralSearchScreenState._service.suggest(category, query);
      } catch (_) {
        items = const [];
      }
      if (!mounted || token != _suggestToken) return;
      _suggestions.value = SuggestionState(query: query, category: category, items: items);
    });
  }

  ({String category, SearchFilters filters})? _presetForQuery(String query) {
    if (!query.startsWith('#')) return null;
    final special = SpecialQuery.parse(query.substring(1));
    if (special is RankingQuery) {
      return (category: special.category, filters: SearchFilters.forAnimeRanking(special.type));
    }
    if (special is MangaRankingQuery) {
      return (category: SearchCategory.manga, filters: SearchFilters.forMangaRanking(special.type));
    }
    if (special is SeasonQuery) {
      return (category: SearchCategory.anime, filters: SearchFilters.forSeason(special.season, special.year));
    }
    return null;
  }

  Future<void> _runSearch(String raw) async {
    var query = raw.trim();
    final preset = _presetForQuery(query);
    var effectiveCategory = _category;
    var effectiveFilters = _filters;
    var requestQuery = query;
    if (preset != null) {
      // Keep `#...` in the bar as a named preset backed by native SearchFilters.
      effectiveCategory = preset.category;
      effectiveFilters = preset.filters;
      requestQuery = '';
      _set(() {
        _specialQuery = true;
        _category = preset.category;
        _filters = preset.filters;
      });
    }
    if (requestQuery.isEmpty && effectiveFilters.isEmpty && !SearchCategory.isBrowsable(effectiveCategory)) return;
    _suggestTimer?.cancel();
    _suggestToken++;
    _suggestions.value = SuggestionState.idle;
    _focusNode.unfocus();
    if (query.isNotEmpty && preset == null) _history.addQuery(query);

    final request = SearchRequest(category: effectiveCategory, query: requestQuery, filters: effectiveFilters);
    final token = ++_searchToken;
    _set(() {
      _showPanel = false;
      _stage = SearchStage.started;
      _loadMoreStage = SearchStage.notStarted;
      _request = request;
    });
    try {
      final page = await _GeneralSearchScreenState._service.search(request);
      if (!mounted || token != _searchToken) return;
      _setupTabs(page);
      _set(() {
        _page = page;
        if (page.category != _category) {
          // A special query decides its own category (a manga ranking is a manga search).
          _category = page.category;
          _filters = SearchFilters.empty;
        }
        _stage = page.hasResults ? SearchStage.loaded : SearchStage.empty;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      final kind = await SearchFailures.classify(e);
      if (!mounted || token != _searchToken) return;
      _set(() {
        _failure = kind;
        _stage = SearchStage.error;
      });
    }
  }

  void _setupTabs(SearchPage page) {
    _tabController?.dispose();
    _tabController = null;
    _allTabs = const [];
    final all = page.all;
    if (page.category != SearchCategory.all || all == null) return;
    final tabs = [
      for (final entry in all.categories.entries)
        if (entry.value.isNotEmpty) entry.key,
    ];
    if (tabs.isEmpty) return;
    _allTabs = tabs;
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  bool get _canLoadMore {
    final page = _page;
    return page != null && page.category != SearchCategory.all && page.hasMore;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) _loadMore();
  }

  Future<void> _loadMore() async {
    final page = _page;
    final request = _request;
    if (page == null || request == null || !_canLoadMore) return;
    if (_loadMoreStage == SearchStage.started || _stage != SearchStage.loaded) return;
    final token = _searchToken;
    _set(() => _loadMoreStage = SearchStage.started);
    try {
      await _GeneralSearchScreenState._service.loadMore(page, request);
      if (!mounted || token != _searchToken) return;
      _set(() => _loadMoreStage = SearchStage.loaded);
    } catch (e) {
      debugPrint('Load more error: $e');
      if (!mounted || token != _searchToken) return;
      page.hasMore = false;
      _set(() => _loadMoreStage = SearchStage.error);
    }
  }

  void _applyPanel(SearchPanelResult result) {
    _history
      ..displayType = result.display.type
      ..displaySubType = result.display.subType
      ..gridAxisCount = result.display.gridColumns
      ..gridHeight = result.display.gridHeight
      ..saveHeightPerLayout = result.display.saveHeightPerLayout
      ..gridHeights = Map.of(result.display.gridHeights)
      ..saveDisplaySettings();
    final currentText = _searchController.text.trim();
    final currentPreset = _presetForQuery(currentText);
    final keepSpecialPreset = currentPreset != null &&
        currentPreset.category == result.category &&
        currentPreset.filters == result.filters;
    final clearSpecial = currentText.startsWith('#') && !keepSpecialPreset;
    if (clearSpecial) _searchController.clear();
    _set(() {
      if (clearSpecial) _specialQuery = false;
      _category = result.category;
      _filters = result.filters;
      _display = result.display;
      _showPanel = false;
    });
    final text = _searchController.text;
    if (text.trim().isNotEmpty || _filters.isNotEmpty || SearchCategory.isBrowsable(_category)) {
      _runSearch(text);
    } else {
      _resetResults();
    }
  }

  void _clearAll() {
    _searchController.clear();
    _set(() {
      _filters = SearchFilters.empty;
      _specialQuery = false;
    });
    _resetResults();
  }

  void _removeFilter(List<String> keys) {
    var next = _filters;
    for (final key in keys) {
      next = next.remove(key);
    }
    _set(() => _filters = next);
    final text = _searchController.text;
    if (text.trim().isNotEmpty || next.isNotEmpty || SearchCategory.isBrowsable(_category)) {
      _runSearch(text);
    } else {
      _resetResults();
    }
  }

  void _setGenreOff(int id) {
    final next = _filters
        .set(FilterKey.genresIn, [..._filters.genresIn]..remove(id))
        .set(FilterKey.genresOut, [..._filters.genresOut]..remove(id));
    _set(() => _filters = next);
    final text = _searchController.text;
    if (text.trim().isNotEmpty || next.isNotEmpty || SearchCategory.isBrowsable(_category)) {
      _runSearch(text);
    } else {
      _resetResults();
    }
  }

  /// Runs [query] typed from the history or a shortcut chip.
  void _searchFrom(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _runSearch(query);
  }

  /// Inserts [query] into the search field without submitting so the user can
  /// edit it first (e.g. long-pressing a tag suggestion).
  void _fillFrom(String query) {
    _lastQueryText = query;
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    final isSpecial = query.startsWith('#') && SpecialQuery.parse(query.substring(1)) != null;
    _set(() {
      _specialQuery = isSpecial;
      _specialTagBackspace = query.startsWith('#');
    });
    _focusNode.requestFocus();
    _scheduleSuggestions(query);
  }

  /// Filters News / Featured results by tapping a tag chip on an [ArticleTile].
  void _applyArticleTag(String rawTag, {required bool isNews}) {
    final clean = rawTag.trim();
    if (clean.isEmpty) return;
    final lower = clean.toLowerCase();
    if (lower == 'all' || lower == 'spoiler') return;
    final options = isNews ? SearchOptions.newsTags() : SearchOptions.featuredTags();
    var resolved = clean;
    for (final opt in options) {
      if (opt.value.toLowerCase() == lower || opt.label.toLowerCase() == lower) {
        resolved = opt.value;
        break;
      }
    }
    _set(() => _filters = _filters.set(FilterKey.tag, resolved));
    _runSearch(_searchController.text);
  }
}
