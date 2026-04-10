import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/padh_ai_theme.dart';
import 'padh_connection_banner.dart';

class ScaffoldWithBanner extends ConsumerWidget {
  const ScaffoldWithBanner({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PadhAiColors.background,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PadhConnectionBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
