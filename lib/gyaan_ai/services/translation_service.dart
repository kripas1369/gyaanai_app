import 'package:translator/translator.dart';

/// Fast translation service using Google Translate API (via translator package).
/// Much faster than AI-based translation for simple English <-> Nepali.
class TranslationService {
  TranslationService._();
  static final instance = TranslationService._();

  final _translator = GoogleTranslator();

  /// Translate text from English to Nepali.
  /// Preserves math expressions and LaTeX by splitting on them.
  Future<String> toNepali(String text) async {
    if (text.trim().isEmpty) return text;

    // If mostly math/symbols, return as-is
    if (_isMostlyMath(text)) return text;

    try {
      // Split text to preserve math expressions
      final parts = _splitPreservingMath(text);
      final translated = <String>[];

      for (final part in parts) {
        if (part.isMath) {
          translated.add(part.text);
        } else if (part.text.trim().isNotEmpty) {
          final result = await _translator.translate(
            part.text,
            from: 'en',
            to: 'ne',
          );
          translated.add(result.text);
        } else {
          translated.add(part.text);
        }
      }

      return translated.join('');
    } catch (e) {
      // Fallback: return original on error
      return text;
    }
  }

  /// Translate text from Nepali to English.
  Future<String> toEnglish(String text) async {
    if (text.trim().isEmpty) return text;

    try {
      final result = await _translator.translate(
        text,
        from: 'ne',
        to: 'en',
      );
      return result.text;
    } catch (e) {
      return text;
    }
  }

  /// Check if text is mostly math expressions.
  bool _isMostlyMath(String text) {
    final mathChars = RegExp(r'[\d\+\-\*\/\=\^\(\)\[\]\{\}\<\>]');
    final matches = mathChars.allMatches(text).length;
    final ratio = matches / text.length;
    return ratio > 0.5;
  }

  /// Split text into math and non-math parts.
  List<_TextPart> _splitPreservingMath(String text) {
    // Match: LaTeX ($...$, $$...$$), equations, expressions with operators
    final mathPattern = RegExp(
      r'(\$\$[\s\S]*?\$\$|\$[^\$]+\$|[a-zA-Z]?\^[\d\w]+|[\d\+\-\*\/\=\^\(\)\[\]\{\}]+)',
    );

    final parts = <_TextPart>[];
    var lastEnd = 0;

    for (final match in mathPattern.allMatches(text)) {
      // Add non-math text before this match
      if (match.start > lastEnd) {
        parts.add(_TextPart(text.substring(lastEnd, match.start), false));
      }
      // Add math part
      parts.add(_TextPart(match.group(0)!, true));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      parts.add(_TextPart(text.substring(lastEnd), false));
    }

    return parts.isEmpty ? [_TextPart(text, false)] : parts;
  }
}

class _TextPart {
  final String text;
  final bool isMath;
  _TextPart(this.text, this.isMath);
}
