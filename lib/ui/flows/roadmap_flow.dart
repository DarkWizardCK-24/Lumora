import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/roadmap_python_mastery.dart';
import '../utils/app_snack.dart';
import '../widgets/confirmation_dialog.dart';

/// Asks first, then adds the Python Mastery roadmap to the current account.
Future<void> importRoadmap(BuildContext context, WidgetRef ref) async {
  final ok = await confirm(
      context,
      'Add the Python Mastery roadmap?',
      'Adds your Oct 2026 – Sep 2027 plan to this account:\n\n'
      '• 8 phase goals with milestones and assessments\n'
      '• A master goal with the 6 projects and final interview simulation\n'
      '• A goal for 250–350 DSA problems\n'
      '• The 42-topic syllabus under Python, DSA, SQL, FastAPI and DevOps\n'
      '• 3 notes: routine, pass rules and the AI-independence protocol\n\n'
      'Everything can be edited or deleted. It is added only once.',
      action: 'Add roadmap',
      destructive: false);
  if (!ok) return;
  final r = await importPythonMasteryRoadmap(ref.read(repoProvider));
  if (!context.mounted) return;
  toast(
      context,
      r.alreadyImported
          ? 'The Python roadmap is already in this account'
          : 'Added ${r.goals} goals, ${r.milestones} milestones, ${r.topics} topics and ${r.notes} notes');
}
