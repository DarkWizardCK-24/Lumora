import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String l, String p) => OutlinedButton.icon(
        onPressed: () => context.go(p), icon: Icon(i, size: 18), label: Text(l, overflow: TextOverflow.ellipsis));
    return Wrap(spacing: 8, runSpacing: 8, children: [
      b(Icons.play_arrow_rounded, 'Start session', '/sessions'),
      b(Icons.flag_outlined, 'Add goal', '/goals?new=1'),
      b(Icons.sticky_note_2_outlined, 'Add note', '/notes?new=1'),
      b(Icons.code, 'Log practice', '/coding?new=1'),
      b(Icons.event_outlined, 'Schedule', '/calendar?new=1'),
      b(Icons.emoji_events_outlined, 'Milestone', '/milestones?new=1'),
    ]);
  }
}
