import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/nepali_text.dart';
import 'chat_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/suggested_questions.dart';
import 'widgets/typing_indicator.dart';

class ChatScreen extends GetView<ChatController> {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const NepaliText('AI Tutor')),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.messages.isEmpty) {
                return const Center(child: Text('Start a conversation'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.messages.length,
                itemBuilder: (context, i) => ChatBubble(
                  text: controller.messages[i],
                  isUser: i.isOdd,
                ),
              );
            }),
          ),
          Obx(
            () => controller.isTyping.value
                ? const TypingIndicator()
                : const SizedBox.shrink(),
          ),
          const SuggestedQuestions(),
        ],
      ),
    );
  }
}
