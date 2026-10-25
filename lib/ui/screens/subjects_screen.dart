import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/subject.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/seed_data.dart';
import '../flows/subject_flow.dart';
import '../utils/app_snack.dart';
import '../widgets/empty_state.dart';
import '../widgets/new_action_scope.dart';
import '../widgets/page_layout.dart';
import '../widgets/subject_card.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});
  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  String query = '';
  bool showArchived = false;
  String sort = 'name';

  @override
  Widget build(BuildContext context) {
    return ref.watch(snapshotProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (s) {
            var list = s.subjects.where((x) => x.archived == showArchived).toList();
            if (query.isNotEmpty) {
              final q = query.toLowerCase();
              list = list.where((x) => x.name.toLowerCase().contains(q) || x.category.toLowerCase().contains(q)).toList();
            }
            int mins(Subject x) => s.sessions.where((e) => e.subjectId == x.id).fold(0, (a, e) => a + e.activeSeconds ~/ 60);
            list.sort((a, b) => sort == 'time' ? mins(b).compareTo(mins(a)) : a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            return NewActionScope(
              onNew: () => editSubject(context, ref),
              child: PageBody(children: [
                PageHeader(title: 'Subjects', subtitle: 'Topics, effort and progress per subject', actions: [
                  OutlinedButton.icon(
                      onPressed: () async {
                        final n = await addStarterSubjects(ref.read(repoProvider));
                        if (context.mounted) toast(context, n == 0 ? 'Starter subjects already added' : 'Added $n starter subjects');
                      },
                      icon: const Icon(Icons.library_add_outlined),
                      label: const Text('Starter templates')),
                  FilledButton.icon(
                      onPressed: () => editSubject(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('New subject')),
                ]),
                Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                      width: 280,
                      child: TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search subjects'),
                          onChanged: (v) => setState(() => query = v))),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'name', label: Text('A–Z')),
                      ButtonSegment(value: 'time', label: Text('Most time')),
                    ],
                    selected: {sort},
                    onSelectionChanged: (v) => setState(() => sort = v.first),
                  ),
                  FilterChip(
                      label: const Text('Archived'),
                      selected: showArchived,
                      onSelected: (v) => setState(() => showArchived = v)),
                ]),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  SizedBox(
                      height: 300,
                      child: EmptyState(
                          icon: Icons.library_books_outlined,
                          title: s.subjects.isEmpty ? 'No subjects yet' : 'Nothing here',
                          message: s.subjects.isEmpty
                              ? 'Add your own subjects, or start from the optional templates (Python, DSA, SQL, Flutter…).'
                              : 'No subjects match the current filter.',
                          action: s.subjects.isEmpty
                              ? FilledButton(
                                  onPressed: () => addStarterSubjects(ref.read(repoProvider)),
                                  child: const Text('Add starter templates'))
                              : null))
                else
                  for (final sub in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: SubjectCard(sub, s)),
              ]),
            );
          },
        );
  }
}
