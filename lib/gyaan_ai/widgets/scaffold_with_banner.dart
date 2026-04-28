import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/gyaan_ai_theme.dart';
import 'gyaan_ai_connection_banner.dart';

/// Scaffold that injects the compact status pill into the AppBar actions.
/// If no AppBar is provided it falls back to a plain scaffold.
class ScaffoldWithBanner extends ConsumerWidget {
  const ScaffoldWithBanner({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  /// Inject the status pill as the first action in the given AppBar's actions.
  PreferredSizeWidget? _withPill(PreferredSizeWidget? bar) {
    if (bar == null) return null;
    if (bar is! AppBar) return bar;

    final existing = bar.actions ?? <Widget>[];
    // Avoid double-injection
    if (existing.any((w) => w is GyaanAiStatusPill)) return bar;

    return AppBar(
      key: bar.key,
      leading: bar.leading,
      automaticallyImplyLeading: bar.automaticallyImplyLeading,
      title: bar.title,
      actions: [const GyaanAiStatusPill(), ...existing],
      bottom: bar.bottom,
      elevation: bar.elevation,
      backgroundColor: bar.backgroundColor,
      foregroundColor: bar.foregroundColor,
      centerTitle: bar.centerTitle,
      titleSpacing: bar.titleSpacing,
      toolbarHeight: bar.toolbarHeight,
      scrolledUnderElevation: bar.scrolledUnderElevation,
      shadowColor: bar.shadowColor,
      surfaceTintColor: bar.surfaceTintColor,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: GyaanAiColors.background,
      appBar: _withPill(appBar),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
    );
  }
}
