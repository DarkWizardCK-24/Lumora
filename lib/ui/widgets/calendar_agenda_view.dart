import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/snapshot.dart';
import 'calendar_day_list.dart';
import 'calendar_item.dart';
import 'empty_state.dart';
import 'section_card.dart';

class CalendarAgendaView extends StatelessWidget {
  const CalendarAgendaView(this.from, this.items, this.s, {super.key});
  final DateTime from;
  final List<CalendarItem> items;
  final Snapshot s;
  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 14; i++) from.add(Duration(days: i))].where((d) => items.any((i) => sameDay(i.when, d))).toList();
    if (days.isEmpty) {
      return const SizedBox(height: 280, child: EmptyState(icon: Icons.event_available_outlined, title: 'Nothing scheduled', message: 'Schedule an activity, or generate a plan from Smart Analysis.'));
    }
    return Column(children: [
      for (final d in days)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SectionCard(title: DateFormat('EEEE, d MMM').format(d), child: CalendarDayList(d, items, s, bare: true)),
        ),
    ]);
  }
}
