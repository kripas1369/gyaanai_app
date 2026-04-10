/// Direct calls to a local or LAN Ollama server (offline / low-latency mode).
class OllamaService {
  OllamaService({this.baseUrl = 'http://127.0.0.1:11434'});

  String baseUrl;

  // Future<String> generate(String model, String prompt) async { ... }
}
