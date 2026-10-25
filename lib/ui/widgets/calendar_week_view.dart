import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/snapshot.dart';
import 'calendar_day_list.dart';
import 'calendar_item.dart';
import 'section_card.dart';

class CalendarWeekView extends StatelessWidget {
  const CalendarWeekView(this.start, this.items, this.s, this.compact, {super.key});
  final DateTime start;
  final List<CalendarItem> items;
  final Snapshot s;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    if (compact) {
      return Column(children: [for (final d in days) Padding(padding: const EdgeInsets.only(bottom: 10), child: _dayCard(d))]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final d in days) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _dayCard(d))),
    ]);
  }

  Widget _dayCard(DateTime d) => SectionCard(
        padding: const EdgeInsets.all(10),
        title: DateFormat('EEE d').format(d),
        child: CalendarDayList(d, items, s, bare: true),
      );
}
