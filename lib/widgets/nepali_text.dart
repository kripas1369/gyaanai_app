import 'package:flutter/material.dart';

/// Devanagari-friendly text (font fallbacks / line height can be tuned here).
class NepaliText extends StatelessWidget {
  const NepaliText(this.data, {super.key, this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }
}
