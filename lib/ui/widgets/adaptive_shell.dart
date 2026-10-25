import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/xp_engine.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/utils/responsive.dart';
import 'global_search_dialog.dart';
import 'level_card.dart';
import 'lumora_logo.dart';
import 'new_action_scope.dart';
import 'notification_center.dart';
import 'sync_chip.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon, this.selectedIcon);
  final String path, label;
  final IconData icon, selectedIcon;
}

const navItems = <NavItem>[
  NavItem(
    '/',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard_rounded,
  ),
  NavItem('/goals', 'My Learning', Icons.flag_outlined, Icons.flag_rounded),
  NavItem(
    '/subjects',
    'Subjects',
    Icons.library_books_outlined,
    Icons.library_books_rounded,
  ),
  NavItem(
    '/sessions',
    'Study Sessions',
    Icons.timer_outlined,
    Icons.timer_rounded,
  ),
  NavItem(
    '/focus',
    'Focus Mode',
    Icons.self_improvement_outlined,
    Icons.self_improvement_rounded,
  ),
  NavItem(
    '/flashcards',
    'Flashcards',
    Icons.style_outlined,
    Icons.style_rounded,
  ),
  NavItem(
    '/coding',
    'Coding Practice',
    Icons.code_outlined,
    Icons.code_rounded,
  ),
  NavItem(
    '/notes',
    'Notes',
    Icons.sticky_note_2_outlined,
    Icons.sticky_note_2_rounded,
  ),
  NavItem(
    '/calendar',
    'Calendar',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  NavItem(
    '/milestones',
    'Milestones',
    Icons.emoji_events_outlined,
    Icons.emoji_events_rounded,
  ),
  NavItem(
    '/analysis',
    'Smart Analysis',
    Icons.auto_awesome_outlined,
    Icons.auto_awesome_rounded,
  ),
  NavItem(
    '/analytics',
    'Analytics',
    Icons.insights_outlined,
    Icons.insights_rounded,
  ),
  NavItem(
    '/insights',
    'Study Insights',
    Icons.lightbulb_outline_rounded,
    Icons.lightbulb_rounded,
  ),
  NavItem(
    '/review',
    'Weekly Review',
    Icons.event_note_outlined,
    Icons.event_note_rounded,
  ),
  NavItem(
    '/settings',
    'Settings',
    Icons.settings_outlined,
    Icons.settings_rounded,
  ),
];

const _mobileTabs = <NavItem>[
  NavItem('/', 'Home', Icons.home_outlined, Icons.home_rounded),
  NavItem('/goals', 'Learning', Icons.flag_outlined, Icons.flag_rounded),
  NavItem(
    '/calendar',
    'Planner',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  NavItem(
    '/analytics',
    'Insights',
    Icons.insights_outlined,
    Icons.insights_rounded,
  ),
  NavItem('/more', 'More', Icons.apps_outlined, Icons.apps_rounded),
];

String _titleFor(String loc) {
  for (final n in navItems) {
    if (n.path == '/' ? loc == '/' : loc.startsWith(n.path)) return n.label;
  }
  return loc == '/more' ? 'More' : 'Lumora';
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(remoteProvider).restore();
      await ref.read(syncProvider).syncNow();
    });
  }

  /// Celebrates a new all-time-high level once. The first value seen is stored silently,
  /// so existing data never triggers a surprise celebration on upgrade.
  Future<void> _onXp(XpInfo? xp) async {
    // Listeners can fire after the shell is gone (e.g. while the full-screen focus page is open).
    if (xp == null || !mounted) return;
    final db = ref.read(dbProvider);
    final seen = int.tryParse(await db.pref('maxLevelSeen') ?? '');
    if (seen != null && xp.level <= seen) return;
    await db.setPref('maxLevelSeen', '${xp.level}');
    if (seen != null && mounted) await showLevelUp(context, xp);
  }

  void _quickAdd(String path) => context.go('$path?new=1');

  @override
  Widget build(BuildContext context) {
    ref.watch(connectivityBinder);
    ref.listen<XpInfo?>(xpProvider, (prev, next) => _onXp(next));
    final loc = GoRouterState.of(context).uri.path;
    final layout = Responsive.ctx(context);
    final compact = layout == Layout.compact;

    final content = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewIntent(),
      },
      child: Actions(
        actions: {
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              showGlobalSearch(context);
              return null;
            },
          ),
          _NewIntent: CallbackAction<_NewIntent>(
            onInvoke: (_) {
              pageNewAction.value?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: compact ? _mobile(loc) : _desktop(loc, layout),
        ),
      ),
    );
    return content;
  }

  // ------------------------------------------------------------- mobile ---
  Widget _mobile(String loc) {
    final idx = () {
      for (var i = 0; i < 4; i++) {
        final p = _mobileTabs[i].path;
        if (p == '/' ? loc == '/' : loc.startsWith(p)) return i;
      }
      return 4;
    }();
    final onRoot = _mobileTabs.any((t) => t.path == loc);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        titleSpacing: onRoot || loc == '/more' ? 16 : 0,
        automaticallyImplyLeading: false,
        leading: (!onRoot && loc != '/more')
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/more'),
              )
            : null,
        title: Row(
          children: [
            if (onRoot || loc == '/more') ...[
              const LumoraLogo(size: 30),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                onRoot && loc == '/' ? 'Lumora' : _titleFor(loc),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => showGlobalSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
          const SyncChip(compact: true),
          const NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(top: false, child: widget.child),
      floatingActionButton: loc == '/' || loc == '/goals'
          ? FloatingActionButton.extended(
              onPressed: () => _showQuickAddSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Quick add'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_mobileTabs[i].path),
        destinations: [
          for (final t in _mobileTabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }

  void _showQuickAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final q in _quickActions)
                ListTile(
                  leading: Icon(
                    q.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(q.label),
                  onTap: () {
                    Navigator.pop(c);
                    _quickAdd(q.path);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ desktop ---
  Widget _desktop(String loc, Layout layout) {
    final settings = ref.watch(settingsProvider);
    final collapsed = layout == Layout.medium || settings.sidebarCollapsed;
    final width = collapsed ? 76.0 : 248.0;
    final t = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: t.dividerTheme.color ?? Palette.border,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      collapsed ? 20 : 18,
                      18,
                      12,
                      14,
                    ),
                    child: Row(
                      children: [
                        const LumoraLogo(size: 36),
                        if (!collapsed) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lumora',
                                  style: t.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Learning Tracker',
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: Palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final n in navItems) _sideTile(n, loc, collapsed),
                      ],
                    ),
                  ),
                  if (layout == Layout.expanded)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Tooltip(
                        message: collapsed
                            ? 'Expand sidebar'
                            : 'Collapse sidebar',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          onTap: () => ref
                              .read(settingsProvider.notifier)
                              .update(
                                settings.copyWith(
                                  sidebarCollapsed: !settings.sidebarCollapsed,
                                ),
                              ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Icon(
                                  collapsed
                                      ? Icons.keyboard_double_arrow_right
                                      : Icons.keyboard_double_arrow_left,
                                  color: Palette.muted,
                                ),
                                if (!collapsed) ...[
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Collapse',
                                    style: TextStyle(color: Palette.muted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _topBar(loc),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideTile(NavItem n, String loc, bool collapsed) {
    final selected = n.path == '/' ? loc == '/' : loc.startsWith(n.path);
    final t = Theme.of(context);
    final color = selected ? t.colorScheme.primary : Palette.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: n.label,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: selected
              ? t.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => context.go(n.path),
            child: Container(
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!collapsed)
                    Container(
                      width: 3,
                      height: 20,
                      margin: const EdgeInsets.only(right: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  Icon(
                    selected ? n.selectedIcon : n.icon,
                    size: 22,
                    color: color,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? t.colorScheme.primary
                              : t.colorScheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(String loc) {
    final t = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: t.dividerTheme.color ?? Palette.border),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lumora  ›  ${_titleFor(loc)}',
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall?.copyWith(color: Palette.muted),
                ),
                Text(
                  _titleFor(loc),
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  onTap: () => showGlobalSearch(context),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: t.inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(
                        color: t.dividerTheme.color ?? Palette.border,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Palette.muted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search goals, notes, subjects…',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Palette.muted),
                          ),
                        ),
                        Text(
                          'Ctrl K',
                          style: TextStyle(color: Palette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Quick add (Ctrl+N adds in this page)',
            onSelected: _quickAdd,
            itemBuilder: (c) => [
              for (final q in _quickActions)
                PopupMenuItem(
                  value: q.path,
                  child: Row(
                    children: [
                      Icon(q.icon, size: 18),
                      const SizedBox(width: 10),
                      Text(q.label),
                    ],
                  ),
                ),
            ],
            child: IgnorePointer(
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded),
                label: const Text('Quick add'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const SyncChip(),
          const NotificationBell(),
          const SizedBox(width: 6),
          Tooltip(
            message: settings.profileName.isEmpty
                ? 'Local profile'
                : settings.profileName,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go('/settings'),
              child: TierAvatar(
                tier: ref.watch(xpProvider)?.tier ?? AvatarTier.starter,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: t.colorScheme.primary.withValues(
                    alpha: 0.14,
                  ),
                  child: Text(
                    settings.profileName.isEmpty
                        ? 'L'
                        : settings.profileName.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: t.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _NewIntent extends Intent {
  const _NewIntent();
}

class _Quick {
  const _Quick(this.label, this.path, this.icon);
  final String label, path;
  final IconData icon;
}

const _quickActions = [
  _Quick('Start study session', '/sessions', Icons.play_circle_outline),
  _Quick('Focus mode', '/focus', Icons.self_improvement_rounded),
  _Quick('Add flashcard', '/flashcards', Icons.style_outlined),
  _Quick('Add goal', '/goals', Icons.flag_outlined),
  _Quick('Add note', '/notes', Icons.sticky_note_2_outlined),
  _Quick('Log coding practice', '/coding', Icons.code_rounded),
  _Quick('Schedule activity', '/calendar', Icons.event_available_outlined),
  _Quick('Add milestone', '/milestones', Icons.emoji_events_outlined),
];
