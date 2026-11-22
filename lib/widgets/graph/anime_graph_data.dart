import 'package:flutter/foundation.dart';

/// How two titles of a franchise relate, as the graph backend names it.
enum GraphRelation {
  sequel('sequel'),
  prequel('prequel'),
  alternativeSetting('alternative_setting'),
  alternativeVersion('alternative_version'),
  sideStory('side_story'),
  parentStory('parent_story'),
  summary('summary'),
  fullStory('full_story'),
  spinOff('spin_off'),
  character('character'),
  other('other');

  const GraphRelation(this.wire);

  /// The word the backend sends.
  final String wire;

  /// An unknown word is [other]: a new relation never breaks the graph.
  static GraphRelation parse(Object? word) {
    for (final relation in values) {
      if (relation.wire == word) return relation;
    }
    return other;
  }
}

/// How the graph's edges are oriented before the layout runs.
enum GraphOrder {
  /// Edges as the backend sends them: the layout grows out of the title that was opened.
  fromSelected,

  /// Every edge points from the older title to the newer one.
  bySequel,
}

@immutable
class GraphNodeData {
  final int id;
  final String title;
  final String? imageUrl;
  final double? mean;
  final String? mediaType;
  final String? status;
  final int? year;

  /// `winter`, `spring`, `summer` or `fall`.
  final String? season;

  const GraphNodeData({
    required this.id,
    required this.title,
    this.imageUrl,
    this.mean,
    this.mediaType,
    this.status,
    this.year,
    this.season,
  });

  /// `null` when the node has no usable id.
  static GraphNodeData? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! int) return null;
    final picture = json['main_picture'];
    final start = json['start_season'];
    final mean = json['mean'];
    final year = start is Map ? start['year'] : null;
    final season = start is Map ? start['season'] : null;
    String? imageUrl;
    if (picture is Map) {
      imageUrl = (picture['large'] ?? picture['medium']) as String?;
    }
    return GraphNodeData(
      id: id,
      title: (json['title'] as String?) ?? '',
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      mean: mean is num ? mean.toDouble() : null,
      mediaType: json['media_type'] as String?,
      status: json['status'] as String?,
      year: year is int ? year : null,
      season: season is String ? season : null,
    );
  }

  /// A sortable moment (`year * 12 + month`), `null` when the year is unknown.
  /// A known year with an unknown season counts as its first month.
  int? get releaseKey {
    final y = year;
    if (y == null) return null;
    return y * 12 + (_seasonMonth[season] ?? 0);
  }

  static const Map<String, int> _seasonMonth = {
    'winter': 0,
    'spring': 3,
    'summer': 6,
    'fall': 9
  };
}

@immutable
class GraphEdgeData {
  final int source;
  final int target;
  final GraphRelation relation;

  const GraphEdgeData(this.source, this.target, this.relation);

  static GraphEdgeData? fromJson(Object? json) {
    if (json is! Map) return null;
    final source = json['source'];
    final target = json['target'];
    if (source is! int || target is! int) return null;
    return GraphEdgeData(
        source, target, GraphRelation.parse(json['relation_type']));
  }

  @override
  bool operator ==(Object other) =>
      other is GraphEdgeData &&
      other.source == source &&
      other.target == target &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(source, target, relation);
}

/// The relation graph of one title: titles and the edges between them.
@immutable
class AnimeGraphData {
  final Map<int, GraphNodeData> nodes;
  final List<GraphEdgeData> edges;

  /// False when the graph was cut short (node bound or MAL rate limit): shown, never cached.
  final bool complete;

  /// The graph was cut short because MyAnimeList answered 429.
  final bool rateLimited;

  const AnimeGraphData(this.nodes, this.edges,
      {this.complete = true, this.rateLimited = false});

  /// The same graph marked as cut short or not.
  AnimeGraphData withCompleteness(
          {required bool complete, bool rateLimited = false}) =>
      AnimeGraphData(nodes, edges,
          complete: complete, rateLimited: rateLimited);

  static const AnimeGraphData empty = AnimeGraphData({}, []);

  /// Reads the backend answer (`{nodes: [...], edges: [...]}`); anything malformed gives [empty].
  /// Edges whose ends are not in the node list are dropped, so the layout never meets a node
  /// it cannot draw.
  factory AnimeGraphData.fromJson(Object? json) {
    if (json is! Map) return empty;
    final nodes = <int, GraphNodeData>{};
    final rawNodes = json['nodes'];
    if (rawNodes is List) {
      for (final raw in rawNodes) {
        final node = GraphNodeData.fromJson(raw);
        if (node != null) nodes[node.id] = node;
      }
    }
    final edges = <GraphEdgeData>[];
    final rawEdges = json['edges'];
    if (rawEdges is List) {
      for (final raw in rawEdges) {
        final edge = GraphEdgeData.fromJson(raw);
        if (edge != null &&
            edge.source != edge.target &&
            nodes.containsKey(edge.source) &&
            nodes.containsKey(edge.target)) {
          edges.add(edge);
        }
      }
    }
    return AnimeGraphData(nodes, edges);
  }

  /// A graph with no edge has nothing to draw.
  bool get isEmpty => edges.isEmpty;

  /// The edges to lay out for [order].
  ///
  /// [GraphOrder.fromSelected] keeps them as sent (deterministically sorted).
  /// [GraphOrder.bySequel] orients edges by semantic relation hierarchy first
  /// (prequel → reversed sequel, parentStory → reversed sideStory, fullStory →
  /// reversed summary, derivative relations kept parent → derivative, symmetric
  /// relations ordered older → newer with ID tie-breaker), deduplicates per
  /// unordered node pair preferring `sequel`, and sorts the primary spine first
  /// so Sugiyama layout minimizes crossings.
  List<GraphEdgeData> orderedEdges(GraphOrder order) {
    if (order == GraphOrder.fromSelected) {
      return edges;
    }
    final byPair = <(int, int), GraphEdgeData>{};
    for (final edge in edges) {
      final GraphEdgeData oriented;
      switch (edge.relation) {
        case GraphRelation.prequel:
          oriented = GraphEdgeData(edge.target, edge.source, GraphRelation.sequel);
        case GraphRelation.sequel:
          oriented = edge;
        case GraphRelation.parentStory:
          oriented = GraphEdgeData(edge.target, edge.source, GraphRelation.sideStory);
        case GraphRelation.fullStory:
          oriented = GraphEdgeData(edge.target, edge.source, GraphRelation.summary);
        case GraphRelation.sideStory:
        case GraphRelation.summary:
        case GraphRelation.spinOff:
          oriented = edge;
        case GraphRelation.alternativeVersion:
        case GraphRelation.alternativeSetting:
        case GraphRelation.character:
        case GraphRelation.other:
          final a = nodes[edge.source]?.releaseKey;
          final b = nodes[edge.target]?.releaseKey;
          final flip = (a != null && b != null)
              ? (a != b ? a > b : edge.source > edge.target)
              : false;
          oriented = flip
              ? GraphEdgeData(edge.target, edge.source, edge.relation)
              : edge;
      }
      final pair = oriented.source < oriented.target
          ? (oriented.source, oriented.target)
          : (oriented.target, oriented.source);
      final existing = byPair[pair];
      if (existing == null ||
          _edgeRank(oriented.relation) < _edgeRank(existing.relation)) {
        byPair[pair] = oriented;
      }
    }
    return _sortDeterministic(byPair.values.toList());
  }

  static int _edgeRank(GraphRelation r) => switch (r) {
        GraphRelation.sequel => 0,
        GraphRelation.prequel => 1,
        GraphRelation.sideStory => 2,
        GraphRelation.parentStory => 3,
        GraphRelation.summary => 4,
        GraphRelation.fullStory => 5,
        GraphRelation.spinOff => 6,
        GraphRelation.alternativeVersion => 7,
        GraphRelation.alternativeSetting => 8,
        GraphRelation.character => 9,
        GraphRelation.other => 10,
      };

  List<GraphEdgeData> _sortDeterministic(List<GraphEdgeData> list) {
    final sorted = List<GraphEdgeData>.of(list);
    int relKey(int id) => nodes[id]?.releaseKey ?? 999999;
    sorted.sort((a, b) {
      final aPrimary = a.relation == GraphRelation.sequel || a.relation == GraphRelation.prequel ? 0 : 1;
      final bPrimary = b.relation == GraphRelation.sequel || b.relation == GraphRelation.prequel ? 0 : 1;
      if (aPrimary != bPrimary) return aPrimary.compareTo(bPrimary);
      final bySourceDate = relKey(a.source).compareTo(relKey(b.source));
      if (bySourceDate != 0) return bySourceDate;
      final byTargetDate = relKey(a.target).compareTo(relKey(b.target));
      if (byTargetDate != 0) return byTargetDate;
      final bySourceId = a.source.compareTo(b.source);
      if (bySourceId != 0) return bySourceId;
      return a.target.compareTo(b.target);
    });
    return sorted;
  }
}
