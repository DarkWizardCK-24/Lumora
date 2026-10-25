import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/coach_service.dart';
import '../../core/utils/format.dart';
import 'empty_state.dart';
import 'tip_card.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => showNotificationCenter(context),
      icon: Badge(
        isLabelVisible: tips.isNotEmpty,
        label: Text('${tips.length}'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

Future<void> showNotificationCenter(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Consumer(builder: (c, ref, _) {
          final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
          final snap = ref.watch(snapshotProvider).value;
          final upcoming = snap == null
              ? <dynamic>[]
              : (snap.activities
                  .where((a) => !a.done && a.status != 'skipped' && a.start.isAfter(snap.now) &&
                      a.start.isBefore(snap.now.add(const Duration(days: 2))))
                  .take(5)
                  .toList());
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(children: [
                const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),
              ]),
            ),
            Flexible(
              child: (tips.isEmpty && upcoming.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyState(
                          icon: Icons.notifications_off_outlined,
                          title: 'All caught up',
                          message: 'Coaching tips and reminders will show up here.'))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), shrinkWrap: true, children: [
                      for (final a in upcoming)
                        ListTile(
                          leading: Icon(Icons.alarm_rounded, color: Theme.of(context).colorScheme.primary),
                          title: Text(a.title as String),
                          subtitle: Text('Scheduled ${fmtDateTime(a.start)}'),
                        ),
                      for (final tip in tips) TipTile(tip, onDone: () => Navigator.pop(c)),
                    ]),
            ),
          ]);
        }),
      ),
    ),
  );
}
