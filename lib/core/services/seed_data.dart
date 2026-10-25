import '../models/subject.dart';
import '../models/topic.dart';
import 'repository.dart';

class _T {
  const _T(this.name, this.category, this.icon, this.color, this.topics, {this.hours = 20});
  final String name, category, icon;
  final int color;
  final double hours;
  final List<String> topics;
}

const _templates = <_T>[
  _T('Python', 'Programming', 'code', 0xFF2563EB,
      ['Variables & types', 'Loops & conditions', 'Patterns', 'Functions', 'OOP', 'File handling', 'Exceptions']),
  _T('Data Structures & Algorithms', 'Problem solving', 'psychology', 0xFF7C3AED,
      ['Arrays & strings', 'Linked lists', 'Stacks & queues', 'Trees', 'Graphs', 'Sorting & searching', 'Dynamic programming'],
      hours: 60),
  _T('SQL & Databases', 'Data', 'data', 0xFF0E7490,
      ['SELECT & filtering', 'Joins', 'Aggregation', 'Indexes', 'Normalisation', 'MySQL basics']),
  _T('FastAPI & Backend', 'Backend', 'api', 0xFF059669,
      ['Routing', 'Pydantic models', 'Database access', 'Authentication', 'Testing & deployment']),
  _T('Linux', 'Systems', 'terminal', 0xFF475569,
      ['Shell basics', 'Files & permissions', 'Processes', 'Networking', 'Shell scripting']),
  _T('DevOps', 'Systems', 'build', 0xFFEA580C,
      ['Git workflows', 'Docker', 'CI/CD', 'Infrastructure as code', 'Monitoring']),
  _T('Cybersecurity', 'Security', 'shield', 0xFFDC2626,
      ['Threat modelling', 'Web security', 'Cryptography basics', 'Network security']),
  _T('Cloud Computing', 'Cloud', 'cloud', 0xFF0284C7,
      ['Compute & storage', 'Networking', 'Identity & access', 'Serverless']),
  _T('Flutter', 'Mobile', 'phone', 0xFF0891B2,
      ['Widgets & layout', 'State management', 'Navigation', 'Local storage', 'Testing & release']),
];

/// Optional onboarding templates — everything can be edited or removed later.
/// Skips subjects that already exist by name so it is safe to run twice.
Future<int> addStarterSubjects(Repository repo) async {
  final existing = (await repo.subjects()).map((s) => s.name.toLowerCase()).toSet();
  var added = 0;
  for (final t in _templates) {
    if (existing.contains(t.name.toLowerCase())) continue;
    final s = Subject(
        name: t.name, category: t.category, icon: t.icon, color: t.color, targetHours: t.hours);
    await repo.saveSubject(s);
    for (final name in t.topics) {
      await repo.saveTopic(Topic(subjectId: s.id, name: name, estimatedMinutes: 90));
    }
    added++;
  }
  return added;
}
