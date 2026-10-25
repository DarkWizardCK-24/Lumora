import '../models/enums.dart';
import '../services/snapshot.dart';

Map<String, String> subjectOptions(Snapshot s) =>
    {for (final x in s.subjects.where((x) => !x.archived)) x.id: x.name};

Map<String, String> goalOptions(Snapshot s) => {
      for (final g in s.goals.where((g) => g.status != GoalStatus.completed && !g.archived)) g.id: g.title
    };

Map<String, String> topicOptions(Snapshot s, {String? subjectId}) => {
      for (final t in s.topics.where((t) => subjectId == null || t.subjectId == subjectId)) t.id: t.name
    };

Map<String, String> enumOptions<T extends Enum>(List<T> values, String Function(T) label) =>
    {for (final v in values) v.name: label(v)};

String? subjectNameOf(Snapshot s, String? id) =>
    s.subjects.where((x) => x.id == id).map((x) => x.name).firstOrNull;

String? goalTitleOf(Snapshot s, String? id) =>
    s.goals.where((x) => x.id == id).map((x) => x.title).firstOrNull;
