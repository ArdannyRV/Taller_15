import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/activity_detector_service.dart';
import '../../../../core/services/voice_service.dart';

class ActivityMonitorWidget extends StatefulWidget {
  const ActivityMonitorWidget({super.key});

  @override
  State<ActivityMonitorWidget> createState() => _ActivityMonitorWidgetState();
}

class _ActivityMonitorWidgetState extends State<ActivityMonitorWidget> {
  final ActivityDetectorService _activityService = ActivityDetectorService();
  final VoiceService _voiceService = VoiceService();

  StreamSubscription<ActivityState>? _activitySub;
  StreamSubscription<void>? _fallSub;

  ActivityState _currentState = ActivityState.stationary;
  bool _isMonitoring = false;
  bool _isEmergencyActive = false;

  @override
  void initState() {
    super.initState();
    _voiceService.init();
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _activityService.startDetection();

    // Escuchar cambios de actividad con DEBOUNCE
    _activitySub = _activityService.debouncedActivityStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
        
        // Mute normal announcements if fall emergency is active
        if (!_isEmergencyActive) {
          _voiceService.announceActivity(state);
        }
      }
    });

    // Escuchar caídas
    _fallSub = _activityService.fallStream.listen((_) {
      _handleFallDetected();
    });

    setState(() {
      _isMonitoring = true;
    });
  }

  void _stopMonitoring() {
    _activityService.stopDetection();
    _activitySub?.cancel();
    _fallSub?.cancel();

    setState(() {
      _isMonitoring = false;
      _currentState = ActivityState.stationary;
    });
  }

  Future<void> _handleFallDetected() async {
    // Evitar múltiples diálogos
    if (_isEmergencyActive) return;

    setState(() {
      _isEmergencyActive = true;
    });

    _voiceService.announceFall();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const FallEmergencyDialog();
      },
    );

    if (mounted) {
      setState(() {
        _isEmergencyActive = false;
      });
    }
  }

  String _getActivityName(ActivityState state) {
    switch (state) {
      case ActivityState.stationary:
        return "Quieto";
      case ActivityState.walking:
        return "Caminando";
      case ActivityState.running:
        return "Corriendo";
    }
  }

  IconData _getActivityIcon(ActivityState state) {
    switch (state) {
      case ActivityState.stationary:
        return Icons.accessibility_new;
      case ActivityState.walking:
        return Icons.directions_walk;
      case ActivityState.running:
        return Icons.directions_run;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monitor de Actividad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleMonitoring,
                  icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                  label: Text(_isMonitoring ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMonitoring ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Icon(
              _getActivityIcon(_currentState),
              size: 64,
              color: _isMonitoring ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 10),
            Text(
              _isMonitoring ? _getActivityName(_currentState) : 'Inactivo',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FallEmergencyDialog extends StatefulWidget {
  const FallEmergencyDialog({super.key});

  @override
  State<FallEmergencyDialog> createState() => _FallEmergencyDialogState();
}

class _FallEmergencyDialogState extends State<FallEmergencyDialog> {
  Timer? _timer;
  int _secondsLeft = 15;
  bool _isEmergency = false;
  final VoiceService _voiceService = VoiceService();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _timer?.cancel();
          _triggerEmergency();
        }
      });
    });
  }

  void _triggerEmergency() {
    setState(() {
      _isEmergency = true;
    });
    _voiceService.announceFallEmergency();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEmergency ? "¡EMERGENCIA!" : "¿Estás bien?",
        style: TextStyle(
          color: _isEmergency ? Colors.red : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: _isEmergency ? Colors.red : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            _isEmergency
                ? "Llamando a contacto de emergencia..."
                : "Se detectó una posible caída. ¿Necesitas ayuda?",
            textAlign: TextAlign.center,
          ),
          if (!_isEmergency) ...[
            const SizedBox(height: 16),
            Text(
              "$_secondsLeft s",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
      actions: [
        if (!_isEmergency)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Estoy bien"),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Lógica adicional para llamar emergencia
          },
          child: Text(
            _isEmergency ? "Cerrar" : "Llamar ahora",
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
