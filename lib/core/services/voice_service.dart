import 'package:flutter_tts/flutter_tts.dart';
import 'activity_detector_service.dart';

class VoiceService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> init() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5); // Velocidad normal de habla
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> announceActivity(ActivityState state) async {
    String message = "";
    switch (state) {
      case ActivityState.stationary:
        message = "Te has detenido. Estás quieto.";
        break;
      case ActivityState.walking:
        message = "Has empezado a caminar.";
        break;
      case ActivityState.running:
        message = "Estás corriendo. ¡Buen ritmo!";
        break;
    }
    await _flutterTts.speak(message);
  }

  Future<void> announceFall() async {
    await _flutterTts.speak("Peligro. Posible caída detectada. ¿Estás bien?");
  }
  
  Future<void> announceFallEmergency() async {
    await _flutterTts.speak("Alerta. No se detectó respuesta. Llamando a emergencias o contacto asignado.");
  }
}
