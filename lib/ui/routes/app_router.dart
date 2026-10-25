import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/settings_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/coding_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/flashcard_review_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/focus_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/milestones_screen.dart';
import '../screens/more_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/review_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/subjects_screen.dart';
import '../widgets/adaptive_shell.dart';

final appRouter = GoRouter(
  // LUMORA_ROUTE lets the screenshot tool open a specific page (developer use).
  initialLocation: Platform.environment['LUMORA_ROUTE'] ?? '/',
  routes: [
    // Full-screen and outside the shell so nothing else competes for attention.
    GoRoute(path: '/focus', pageBuilder: (c, s) => _fadePage(s, const FocusScreen())),
    ShellRoute(
      builder: (c, s, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const DashboardScreen())),
        GoRoute(path: '/goals', pageBuilder: (c, s) => _page(s, const GoalsScreen()), routes: [
          GoRoute(
              path: ':id',
              pageBuilder: (c, s) => _fadePage(s, GoalDetailScreen(goalId: s.pathParameters['id']!))),
        ]),
        GoRoute(path: '/subjects', pageBuilder: (c, s) => _page(s, const SubjectsScreen())),
        GoRoute(path: '/sessions', pageBuilder: (c, s) => _page(s, const SessionsScreen())),
        GoRoute(path: '/coding', pageBuilder: (c, s) => _page(s, const CodingScreen())),
        GoRoute(path: '/flashcards', pageBuilder: (c, s) => _page(s, const FlashcardsScreen()), routes: [
          GoRoute(
              path: 'review',
              pageBuilder: (c, s) => _page(s, FlashcardReviewScreen(deck: s.uri.queryParameters['deck']))),
        ]),
        GoRoute(path: '/notes', pageBuilder: (c, s) => _page(s, const NotesScreen())),
        GoRoute(path: '/calendar', pageBuilder: (c, s) => _page(s, const CalendarScreen())),
        GoRoute(path: '/milestones', pageBuilder: (c, s) => _page(s, const MilestonesScreen())),
        GoRoute(path: '/analysis', pageBuilder: (c, s) => _page(s, const AnalysisScreen())),
        GoRoute(path: '/insights', pageBuilder: (c, s) => _page(s, const InsightsScreen())),
        GoRoute(path: '/analytics', pageBuilder: (c, s) => _page(s, const AnalyticsScreen())),
        GoRoute(path: '/review', pageBuilder: (c, s) => _page(s, const ReviewScreen())),
        GoRoute(path: '/settings', pageBuilder: (c, s) => _page(s, const SettingsScreen())),
        GoRoute(path: '/more', pageBuilder: (c, s) => _page(s, const MoreScreen())),
      ],
    ),
  ],
);

Page<void> _page(GoRouterState s, Widget child) => NoTransitionPage(key: s.pageKey, child: child);

Page<void> _fadePage(GoRouterState s, Widget child) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (c, a, _, w) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: w),
    );
