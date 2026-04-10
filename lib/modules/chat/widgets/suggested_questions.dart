import 'package:flutter/material.dart';

class SuggestedQuestions extends StatelessWidget {
  const SuggestedQuestions({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          for (final q in const ['Explain this', 'Give an example', 'Quiz me'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(label: Text(q), onPressed: () {}),
            ),
        ],
      ),
    );
  }
}
