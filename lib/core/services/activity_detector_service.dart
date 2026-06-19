import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:rxdart/rxdart.dart';

enum ActivityState {
  stationary,
  walking,
  running,
}

/// Servicio que utiliza sensors_plus para detectar actividad física
/// y posibles caídas utilizando magnitudes y promedio móvil.
class ActivityDetectorService {
  final _activityController = BehaviorSubject<ActivityState>.seeded(ActivityState.stationary);
  final _fallController = PublishSubject<void>();

  StreamSubscription? _accelerometerSubscription;
  
  // Para la ventana de señal (Peak Detection)
  final List<double> _magnitudeHistory = [];
  // Usamos una ventana más amplia (~2 a 3 segundos) para englobar el tiempo entre pasos
  final int _historySize = 25; 
  
  // Configuración de umbrales (buscando el pico máximo, no el promedio)
  static const double _walkingThreshold = 10.5;
  static const double _runningThreshold = 14.0;
  static const double _fallThreshold = 25.0; // Impacto anómalo

  Stream<void> get fallStream => _fallController.stream;

  void startDetection() {
    if (_accelerometerSubscription != null) return;

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      
      // Detección de caída (Impacto en fuerza G extrema)
      if (magnitude > _fallThreshold) {
        _fallController.add(null);
      }

      // Ventana de señal
      _magnitudeHistory.add(magnitude);
      if (_magnitudeHistory.length > _historySize) {
        _magnitudeHistory.removeAt(0);
      }

      // En lugar de promedio, buscamos el pico (máximo) en la ventana actual.
      // Esto evita que entre cada paso la magnitud caiga a 9.8 y el estado oscile a "Quieto".
      final peakMagnitude = _magnitudeHistory.reduce((a, b) => max(a, b));

      // Clasificación de actividad basada en el pico reciente
      ActivityState newState;
      if (peakMagnitude < _walkingThreshold) {
        newState = ActivityState.stationary;
      } else if (peakMagnitude < _runningThreshold) {
        newState = ActivityState.walking;
      } else {
        newState = ActivityState.running;
      }

      // Si el stream aún no contiene el nuevo estado, lo agregamos (el debounce manejará el resto)
      if (_activityController.value != newState) {
        _activityController.add(newState);
      }
    });
  }

  void stopDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _magnitudeHistory.clear();
  }

  /// Retorna un stream de actividad que implementa un debounce de 3 segundos
  /// para evitar reportar falsos positivos de forma repetitiva.
  Stream<ActivityState> get debouncedActivityStream {
    return _activityController.stream
        // RxDart debounceTime: Solo emite el estado si se mantiene estable por 3 segundos
        .debounceTime(const Duration(seconds: 3))
        // distinct: Evita repetir el estado si no ha cambiado
        .distinct();
  }
}
