import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/services/snapshot.dart';
import 'calendar_item.dart';
import 'section_card.dart';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView(this.focus, this.selected, this.items, this.s, this.compact, this.onSelect, {super.key});
  final DateTime focus, selected;
  final List<CalendarItem> items;
  final Snapshot s;
  final bool compact;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(focus.year, focus.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final weeks = ((first.weekday - 1 + DateUtils.getDaysInMonth(focus.year, focus.month)) / 7).ceil();
    return SectionCard(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Row(children: [
          for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(compact ? d[0] : d, style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w700))))),
        ]),
        for (var w = 0; w < weeks; w++)
          Row(children: [
            for (var d = 0; d < 7; d++)
              Expanded(child: _cell(context, DateTime(start.year, start.month, start.day + w * 7 + d))),
          ]),
      ]),
    );
  }

  Widget _cell(BuildContext context, DateTime day) {
    final inMonth = day.month == focus.month;
    final todayCell = sameDay(day, s.today);
    final sel = sameDay(day, selected);
    final dayItems = items.where((i) => sameDay(i.when, day)).toList();
    return InkWell(
      onTap: () => onSelect(day),
      child: Container(
        height: compact ? 54 : 96,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: sel ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : null,
          border: Border.all(color: todayCell ? Theme.of(context).colorScheme.primary : Palette.border.withValues(alpha: 0.6), width: todayCell ? 1.6 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: inMonth ? null : Palette.muted.withValues(alpha: 0.5))),
          const SizedBox(height: 2),
          if (compact)
            Wrap(spacing: 2, runSpacing: 2, children: [for (final i in dayItems.take(4)) Container(width: 6, height: 6, decoration: BoxDecoration(color: i.color, shape: BoxShape.circle))])
          else
            Expanded(
              child: ClipRect(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final i in dayItems.take(3))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: i.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
                      child: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: i.color, fontWeight: FontWeight.w600)),
                    ),
                  if (dayItems.length > 3) Text('+${dayItems.length - 3} more', style: const TextStyle(fontSize: 10, color: Palette.muted)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
