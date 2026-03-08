// =============================================================================
// WALKS CONTROLLER — StateNotifier para Riverpod
// =============================================================================
// Orquesta programar/reprogramar paseos y actualizar estado (completado/cancelado).
// Inyectado por [walksControllerProvider]; el detalle de paseo puede usar
// [updateWalkStatusUseCaseProvider] directo para cancelar y evitar dispose.
// =============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_pet.dart';
import '../../domain/repositories/walks_repository.dart';
import '../../domain/use_cases/update_walk_status_use_case.dart';

class WalksController extends StateNotifier<AsyncValue<void>> {
  WalksController(this._repository, this._updateWalkStatusUseCase) : super(const AsyncValue.data(null));

  final WalksRepository _repository;
  final UpdateWalkStatusUseCase _updateWalkStatusUseCase;

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

      // Armamos el ID del paseo (único para Firestore)
      final walkId = FirebaseFirestore.instance
          .collection('paseadores')
          .doc(paseadorId)
          .collection('paseos')
          .doc()
          .id;

      // Armamos el paseo con todos los datos
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

      // Guardamos el paseo en Firestore
      await _repository.saveWalk(walk);

      // Guardamos qué caninos van en este paseo
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

      // Primero marcamos listo para no trabar la pantalla
      state = const AsyncValue.data(null);

      // Las notificaciones las programamos después (en segundo plano) para no bloquear
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

  /// Actualiza el estado del paseo (ej. completado, cancelado) en Firestore y cancela notificaciones si aplica.
  Future<void> updateWalkStatus({
    required String paseadorId,
    required String walkId,
    required String estado,
    String? motivoCancelacion,
  }) async {
    try {
      state = const AsyncValue.loading();

      await _updateWalkStatusUseCase.execute(
        paseadorId: paseadorId,
        walkId: walkId,
        estado: estado,
        motivoCancelacion: motivoCancelacion,
      );

      // Si canceló o completó, sacamos las notificaciones programadas
      if (estado == 'cancelado' || estado == 'completado') {
        try {
          final notificationService = LocalNotificationService();
          await notificationService.cancelNotification(walkId.hashCode.abs());
          await notificationService.cancelNotification(walkId.hashCode.abs() + 1);
        } catch (e) {
          // Si falla no tiramos todo el proceso
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

      // Traemos el paseo para actualizarlo
      final walk = await _repository.getWalkById(paseadorId, walkId);
      if (walk == null) {
        throw Exception('Paseo no encontrado');
      }

      // Armamos el paseo con los datos nuevos (fecha, hora, precio, etc.)
      final updatedWalk = walk.copyWith(
        fechaPaseo: nuevaFechaPaseo,
        horaInicio: nuevaHoraInicio,
        horaFin: nuevaHoraFin,
        duracionMinutos: nuevaDuracionMinutos,
        direccionRecogida: nuevaDireccionRecogida,
        precio: nuevoPrecio ?? walk.precio,
        estado: 'programado',
        fechaModificacion: DateTime.now(),
        notificacionEnviada: false, // Para que se envíen de nuevo las notis
      );

      // Guardamos el paseo actualizado
      await _repository.saveWalk(updatedWalk);

      state = const AsyncValue.data(null);

      // Notificaciones viejas las cancelamos y programamos las nuevas en segundo plano
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

  /// Programa las notificaciones del paseo (hora de inicio y recordatorio 15 min antes).
  /// Se corre en segundo plano para no trabar la pantalla.
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
      
      if (!notificationService.isInitialized) {
        await notificationService.initialize();
      }
      
      // Noti para la hora del paseo
      await notificationService.scheduleWalkStartNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: fechaPaseo,
        horaInicio: horaInicio,
        direccion: direccionRecogida,
      );

      // Recordatorio 15 min antes
      await notificationService.scheduleWalkReminderNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: fechaPaseo,
        horaInicio: horaInicio,
      );
    } catch (e) {
      // Si falla no tiramos el flujo, solo no se programan las notis
    }
  }

  /// Cancela las notis viejas y programa las nuevas (reprogramación de paseo).
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
      
      await notificationService.cancelNotification(walkId.hashCode.abs());
      await notificationService.cancelNotification(walkId.hashCode.abs() + 1);
      
      // Programamos de nuevo la noti de la hora del paseo
      await notificationService.scheduleWalkStartNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: nuevaFechaPaseo,
        horaInicio: nuevaHoraInicio,
        direccion: nuevaDireccionRecogida,
      );

      // Recordatorio 15 min antes
      await notificationService.scheduleWalkReminderNotification(
        walkId: walkId,
        propietarioNombre: propietarioNombre,
        caninoNombres: caninoNombres,
        fechaPaseo: nuevaFechaPaseo,
        horaInicio: nuevaHoraInicio,
      );
    } catch (e) {
      print('Error al reprogramar notificaciones: $e');
    }
  }
}

