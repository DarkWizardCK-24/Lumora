import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Lets a page register what Ctrl+N / the quick-add "new" action does.
final ValueNotifier<VoidCallback?> pageNewAction = ValueNotifier(null);

class NewActionScope extends StatefulWidget {
  const NewActionScope({super.key, required this.onNew, required this.child});
  final VoidCallback onNew;
  final Widget child;
  @override
  State<NewActionScope> createState() => _NewActionScopeState();
}

class _NewActionScopeState extends State<NewActionScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pageNewAction.value = widget.onNew;
      if (!mounted) return;
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters['new'] == '1') {
        context.replace(uri.path); // consume the flag so it only fires once
        widget.onNew();
      }
    });
  }

  @override
  void didUpdateWidget(covariant NewActionScope old) {
    super.didUpdateWidget(old);
    pageNewAction.value = widget.onNew;
  }

  @override
  void dispose() {
    if (pageNewAction.value == widget.onNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pageNewAction.value = null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
