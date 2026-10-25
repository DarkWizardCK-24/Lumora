import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import '../models/enums.dart';
import '../services/coach_service.dart';
import '../services/goal_analyzer.dart';

Color statusColor(GoalStatus s) => switch (s) {
      GoalStatus.notStarted => Palette.muted,
      GoalStatus.inProgress => Palette.brandBlue,
      GoalStatus.paused => Palette.warning,
      GoalStatus.completed => Palette.success,
      GoalStatus.archived => Palette.muted,
    };

Color tipColor(TipSeverity s) => switch (s) {
      TipSeverity.info => Palette.brandBlue,
      TipSeverity.positive => Palette.success,
      TipSeverity.warning => Palette.warning,
      TipSeverity.critical => Palette.danger,
    };

Color deadlineColor(DeadlineStatus d) => switch (d) {
      DeadlineStatus.onTrack || DeadlineStatus.completed => Palette.success,
      DeadlineStatus.adjustments => Palette.brandBlue,
      DeadlineStatus.atRisk => Palette.warning,
      DeadlineStatus.unlikely || DeadlineStatus.passed => Palette.danger,
      _ => Palette.muted,
    };

Color activityKindColor(ActivityKind k) => switch (k) {
      ActivityKind.study => Palette.brandBlue,
      ActivityKind.revision => Palette.warning,
      ActivityKind.practice => Palette.success,
      ActivityKind.project => const Color(0xFF7C3AED),
      ActivityKind.assessment => const Color(0xFFDB2777),
      ActivityKind.deadline => Palette.danger,
      ActivityKind.milestone => const Color(0xFFD97706),
    };

Color resultColor(ProblemResult r) => switch (r) {
      ProblemResult.solved => Palette.success,
      ProblemResult.attempted => Palette.brandBlue,
      ProblemResult.needsRevision => Palette.warning,
      ProblemResult.unsolved => Palette.danger,
    };
