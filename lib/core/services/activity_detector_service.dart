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
  
  // Histéresis basada en tiempo (Timeouts absolutos)
  DateTime? _lastRunTime;
  DateTime? _lastWalkTime;
  
  // Configuración de umbrales
  static const double _walkingThreshold = 13.0;
  static const double _runningThreshold = 19.0;
  // Umbral de caída subido considerablemente para que correr no se sobreponga
  static const double _fallThreshold = 55.0; 

  // Estado interno para el debounce asimétrico
  ActivityState _lastEmittedState = ActivityState.stationary;
  ActivityState _pendingState = ActivityState.stationary;
  Timer? _debounceTimer;

  Stream<void> get fallStream => _fallController.stream;

  void startDetection() {
    if (_accelerometerSubscription != null) return;

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      final now = DateTime.now();
      
      // Detección de caída (Impacto en fuerza G extrema)
      if (magnitude > _fallThreshold) {
        _fallController.add(null);
      }

      // Actualizar marcas de tiempo basadas en impactos crudos
      if (magnitude > _runningThreshold) {
        _lastRunTime = now;
        _lastWalkTime = now; // Si la fuerza supera correr, automáticamente supera caminar
      } else if (magnitude > _walkingThreshold) {
        _lastWalkTime = now;
      }

      // Clasificación de actividad por cercanía temporal (Histéresis)
      ActivityState calculatedState;
      if (_lastRunTime != null && now.difference(_lastRunTime!).inMilliseconds < 1500) {
        // Si el último impacto fuerte fue hace menos de 1.5 segundos
        calculatedState = ActivityState.running;
      } else if (_lastWalkTime != null && now.difference(_lastWalkTime!).inMilliseconds < 2000) {
        // Si el último impacto moderado fue hace menos de 2.0 segundos
        calculatedState = ActivityState.walking;
      } else {
        // Ha pasado más de 2 segundos sin registrar ningún impacto por encima del umbral
        calculatedState = ActivityState.stationary;
      }

      _handleStateTransition(calculatedState);
    });
  }

  // Opción 3: Debounce asimétrico
  void _handleStateTransition(ActivityState newState) {
    if (newState == _pendingState) return; 
    
    _pendingState = newState;
    _debounceTimer?.cancel(); 

    if (newState == _lastEmittedState) return;

    // Evaluamos si sube o baja la intensidad (stationary=0, walking=1, running=2)
    int oldIntensity = _lastEmittedState.index;
    int newIntensity = newState.index;

    Duration delay = const Duration(milliseconds: 1500); // 1.5 segundos unificados

    _debounceTimer = Timer(delay, () {
      _lastEmittedState = newState;
      _activityController.add(newState);
    });
  }

  void stopDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _lastRunTime = null;
    _lastWalkTime = null;
    _debounceTimer?.cancel();
  }

  /// Retorna un stream de actividad ya debounced internamente
  Stream<ActivityState> get debouncedActivityStream {
    return _activityController.stream.distinct();
  }
}
