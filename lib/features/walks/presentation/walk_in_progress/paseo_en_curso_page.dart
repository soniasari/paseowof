// =============================================================================
// PASEO EN CURSO PAGE
// =============================================================================
// Pantalla activa durante el paseo: tiempo, distancia, estado del GPS,
// ritmo y velocidad media; botones Pausar y Finalizar paseo.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/walk.dart';
import '../providers/walks_providers.dart';
import 'walk_in_progress_notifier.dart';
import 'walk_in_progress_state.dart';

class PaseoEnCursoPage extends ConsumerStatefulWidget {
  final Walk walk;
  final String paseadorId;

  const PaseoEnCursoPage({
    super.key,
    required this.walk,
    required this.paseadorId,
  });

  @override
  ConsumerState<PaseoEnCursoPage> createState() => _PaseoEnCursoPageState();
}

class _PaseoEnCursoPageState extends ConsumerState<PaseoEnCursoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(walkInProgressProvider.notifier).startTracking(widget.walk, widget.paseadorId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al iniciar el seguimiento. Intenta de nuevo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      try {
        final currentState = ref.read(walkInProgressProvider);
        if (!currentState.isFinishing) {
          ref.read(walkInProgressProvider.notifier).cancel();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String? _formatPace(double? minPerKm) {
    if (minPerKm == null || minPerKm <= 0) return null;
    final min = minPerKm.floor();
    final sec = ((minPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}'' /km";
  }

  static Future<void> _showPaseoCompletadoDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.button.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.button,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Paseo completado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ruta guardada correctamente',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo', style: TextStyle(color: AppColors.button, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walkInProgressProvider);
    final notifier = ref.read(walkInProgressProvider.notifier);

    if (state.isFinishing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.button),
              const SizedBox(height: 24),
              Text(
                'Guardando ruta y finalizando paseo...',
                style: TextStyle(color: AppColors.textGrey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final gpsLabel = state.gpsStatus == GpsStatus.capturing
        ? 'GPS ACTIVO • CAPTURANDO PUNTOS'
        : state.gpsStatus == GpsStatus.error
            ? 'GPS CON ERROR'
            : 'GPS INACTIVO';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final exit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Salir del paseo'),
                content: const Text(
                  'Si sales ahora no se guardará la ruta. ¿Quieres cancelar el seguimiento?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Seguir'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Salir', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
            if (exit == true && mounted) {
              notifier.cancel();
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Paseo en curso',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: state.gpsStatus == GpsStatus.capturing
                        ? AppColors.button
                        : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  gpsLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: state.gpsStatus == GpsStatus.capturing
                        ? AppColors.button
                        : AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (state.gpsPointsCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Puntos: ${state.gpsPointsCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              'TIEMPO DE PASEO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.button,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatElapsed(state.elapsedSeconds),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distancia (km)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.distanceKm.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.button,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Ritmo actual',
                    value: _formatPace(state.currentPaceMinPerKm) ?? '—',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Velocidad media',
                    value: state.averageSpeedKmh != null
                        ? '${state.averageSpeedKmh!.toStringAsFixed(1)} km/h'
                        : '—',
                  ),
                ),
              ],
            ),
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isPaused
                        ? () => notifier.resume()
                        : () => notifier.pause(),
                    icon: Icon(
                      state.isPaused ? Icons.play_arrow : Icons.pause,
                      size: 20,
                      color: AppColors.button,
                    ),
                    label: Text(
                      state.isPaused ? 'Reanudar' : 'Pausar',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.button,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.button, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final paseadorId = widget.paseadorId;
                      final fechaPaseo = widget.walk.fechaPaseo;
                      final nav = Navigator.of(context);
                      try {
                        await notifier.finishWalk();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al guardar: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return;
                      }
                      if (!mounted) return;
                      if (!ref.read(walkInProgressProvider).hasWalk) {
                        ref.invalidate(walksByDateProvider(WalksByDateParams(paseadorId: paseadorId, date: fechaPaseo)));
                        ref.invalidate(walksByDateAllStatusProvider(WalksByDateParams(paseadorId: paseadorId, date: fechaPaseo)));
                        await _showPaseoCompletadoDialog(context);
                        if (!mounted) return;
                        nav.popUntil((route) => route.isFirst);
                      }
                    },
                    icon: const Icon(Icons.stop_rounded, size: 20, color: Colors.white),
                    label: const Text(
                      'FINALIZAR PASEO',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
