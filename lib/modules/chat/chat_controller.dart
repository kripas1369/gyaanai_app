import 'package:get/get.dart';

class ChatController extends GetxController {
  final messages = <String>[].obs;
  final isTyping = false.obs;

  void send(String text) {
    messages.add(text);
  }
}
