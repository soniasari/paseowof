import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_pet.dart';
import '../../domain/repositories/walks_repository.dart';
import '../providers/walks_providers.dart';

class WalksController extends StateNotifier<AsyncValue<void>> {
  WalksController(this._repository) : super(const AsyncValue.data(null));

  final WalksRepository _repository;

  Future<void> scheduleWalk({
    required String paseadorId,
    required String propietarioId,
    required String propietarioNombre,
    required DateTime fechaPaseo,
    required String horaInicio,
    required String horaFin,
    required int duracionMinutos,
    required String direccionRecogida,
    required List<String> caninoIds,
    required List<String> caninoNombres,
    String? observaciones,
    double? precio,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Generar ID único para el paseo
      final walkId = FirebaseFirestore.instance
          .collection('paseadores')
          .doc(paseadorId)
          .collection('paseos')
          .doc()
          .id;

      // Crear objeto Walk
      final walk = Walk(
        id: walkId,
        paseadorId: paseadorId,
        propietarioId: propietarioId,
        fechaPaseo: fechaPaseo,
        horaInicio: horaInicio,
        horaFin: horaFin,
        duracionMinutos: duracionMinutos,
        estado: 'programado',
        direccionRecogida: direccionRecogida,
        observaciones: observaciones,
        precio: precio,
        notificacionEnviada: false,
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
      );

      // Guardar el paseo
      await _repository.saveWalk(walk);

      // Guardar las relaciones paseo-canino
      for (int i = 0; i < caninoIds.length; i++) {
        final walkPetId = FirebaseFirestore.instance
            .collection('paseadores')
            .doc(paseadorId)
            .collection('paseos')
            .doc(walkId)
            .collection('paseos_caninos')
            .doc()
            .id;

        final walkPet = WalkPet(
          id: walkPetId,
          paseoId: walkId,
          caninoId: caninoIds[i],
          nombreCanino: caninoNombres[i],
        );

        await _repository.saveWalkPet(paseadorId, walkId, walkPet);
      }

      // Marcar como completado ANTES de programar notificaciones para no bloquear la UI
      state = const AsyncValue.data(null);

      // Programar notificaciones locales de forma asíncrona (no bloquear el flujo principal)
      // IMPORTANTE: Usar Future.microtask para asegurar que se ejecute después del build
      Future.microtask(() async {
        await _scheduleNotificationsAsync(
          walkId: walkId,
          propietarioNombre: propietarioNombre,
          caninoNombres: caninoNombres,
          fechaPaseo: fechaPaseo,
          horaInicio: horaInicio,
          direccionRecogida: direccionRecogida,
        );
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateWalkStatus({
    required String paseadorId,
    required String walkId,
    required String estado,
    String? motivoCancelacion,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Obtener el paseo actual
      final walk = await _repository.getWalkById(paseadorId, walkId);
      if (walk == null) {
        throw Exception('Paseo no encontrado');
      }

      // Actualizar el estado
      final updatedWalk = walk.copyWith(
        estado: estado,
        fechaModificacion: DateTime.now(),
        motivoCancelacion: motivoCancelacion,
      );

      // Guardar el paseo actualizado
      await _repository.saveWalk(updatedWalk);

      // Cancelar notificaciones si el paseo fue cancelado o completado
      if (estado == 'cancelado' || estado == 'completado') {
        try {
          final notificationService = LocalNotificationService();
          // Cancelar notificación principal (usando hash del walkId)
          await notificationService.cancelNotification(walkId.hashCode.abs());
          // Cancelar notificación de recordatorio (hash + 1)
          await notificationService.cancelNotification(walkId.hashCode.abs() + 1);
        } catch (e) {
          // Si falla la cancelación, no fallar todo el proceso
          print('Error al cancelar notificaciones: $e');
        }
      }

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> rescheduleWalk({
    required String paseadorId,
    required String walkId,
    required String propietarioNombre,
    required DateTime nuevaFechaPaseo,
    required String nuevaHoraInicio,
    required String nuevaHoraFin,
    required int nuevaDuracionMinutos,
    required String nuevaDireccionRecogida,
    required List<String> caninoNombres,
    double? nuevoPrecio,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Obtener el paseo actual
      final walk = await _repository.getWalkById(paseadorId, walkId);
      if (walk == null) {
        throw Exception('Paseo no encontrado');
      }

      // Actualizar el paseo con los nuevos datos
      final updatedWalk = walk.copyWith(
        fechaPaseo: nuevaFechaPaseo,
        horaInicio: nuevaHoraInicio,
        horaFin: nuevaHoraFin,
        duracionMinutos: nuevaDuracionMinutos,
        direccionRecogida: nuevaDireccionRecogida,
        precio: nuevoPrecio ?? walk.precio,
        estado: 'programado', // Mantener como programado
        fechaModificacion: DateTime.now(),
        notificacionEnviada: false, // Resetear para enviar nuevas notificaciones
      );

      // Guardar el paseo actualizado
      await _repository.saveWalk(updatedWalk);

      // Marcar como completado primero para no bloquear la UI
      state = const AsyncValue.data(null);

      // Cancelar notificaciones antiguas y programar nuevas de forma asíncrona
      // IMPORTANTE: Usar Future.microtask para asegurar que se ejecute después del build
      Future.microtask(() async {
        await _rescheduleNotificationsAsync(
          walkId: walkId,
          propietarioNombre: propietarioNombre,
          caninoNombres: caninoNombres,
          nuevaFechaPaseo: nuevaFechaPaseo,
          nuevaHoraInicio: nuevaHoraInicio,
          nuevaDireccionRecogida: nuevaDireccionRecogida,
        );
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  /// Programa notificaciones de forma asíncrona sin bloquear el flujo principal
  /// Este método se ejecuta en segundo plano después de que el paseo se haya guardado
  /// Respeta la arquitectura Riverpod al no modificar el estado del StateNotifier
  Future<void> _scheduleNotificationsAsync({
    required String walkId,
    required String propietarioNombre,
    required List<String> caninoNombres,
    required DateTime fechaPaseo,
    required String horaInicio,
    required String direccionRecogida,
  }) async {
    try {
      final notificationService = LocalNotificationService();
      
      // Verificar que el servicio esté inicializado
      if (!notificationService.isInitialized) {
        await notificationService.initialize();
      }
      
      // Programar notificación para cuando toque el paseo
      await notificationService.scheduleWalkStartNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: fechaPaseo,
        horaInicio: horaInicio,
        direccion: direccionRecogida,
      );

      // Programar recordatorio 15 minutos antes
      await notificationService.scheduleWalkReminderNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: fechaPaseo,
        horaInicio: horaInicio,
      );
    } catch (e) {
      // Si falla la programación de notificaciones, no fallar todo el proceso
      // Solo loguear el error sin bloquear
    }
  }

  /// Cancela notificaciones antiguas y programa nuevas de forma asíncrona
  /// Este método se ejecuta en segundo plano después de que el paseo se haya actualizado
  /// Respeta la arquitectura Riverpod al no modificar el estado del StateNotifier
  Future<void> _rescheduleNotificationsAsync({
    required String walkId,
    required String propietarioNombre,
    required List<String> caninoNombres,
    required DateTime nuevaFechaPaseo,
    required String nuevaHoraInicio,
    required String nuevaDireccionRecogida,
  }) async {
    try {
      final notificationService = LocalNotificationService();
      
      // Cancelar notificaciones antiguas
      await notificationService.cancelNotification(walkId.hashCode.abs());
      await notificationService.cancelNotification(walkId.hashCode.abs() + 1);
      
      // Programar notificación para cuando toque el paseo
      await notificationService.scheduleWalkStartNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: nuevaFechaPaseo,
        horaInicio: nuevaHoraInicio,
        direccion: nuevaDireccionRecogida,
      );

      // Programar recordatorio 15 minutos antes
      await notificationService.scheduleWalkReminderNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: nuevaFechaPaseo,
        horaInicio: nuevaHoraInicio,
      );
    } catch (e) {
      // Si falla la programación de notificaciones, no fallar todo el proceso
      print('Error al reprogramar notificaciones: $e');
    }
  }
}

final walksControllerProvider = StateNotifierProvider.autoDispose<WalksController, AsyncValue<void>>((ref) {
  final repository = ref.watch(walksRepositoryProvider);
  return WalksController(repository);
});
