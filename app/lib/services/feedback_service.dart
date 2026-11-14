import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Áudio (TTS do próprio aparelho) e vibração para mudanças de direção.
class FeedbackService {
  final FlutterTts _tts = FlutterTts();

  Future<void> falar(String texto, String idioma) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(const {'pt': 'pt-BR', 'en': 'en-US', 'es': 'es-ES'}[idioma] ?? 'pt-BR');
      await _tts.setSpeechRate(0.48);
      await _tts.speak(texto);
    } catch (_) {
      // Sem voz instalada: o texto continua na tela e no leitor de tela.
    }
  }

  /// Padrões distintos: esquerda = 2 pulsos, direita = 3, chegada = longo.
  Future<void> vibrar(String icone) async {
    final pulsos = switch (icone) { 'esquerda' => 2, 'direita' => 3, _ => 1 };
    if (icone == 'chegada') {
      await HapticFeedback.heavyImpact();
      return;
    }
    for (var i = 0; i < pulsos; i++) {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
  }

  Future<void> parar() => _tts.stop();
}
