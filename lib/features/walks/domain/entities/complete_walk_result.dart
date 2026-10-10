// =============================================================================
// COMPLETE WALK RESULT
// =============================================================================
// Resultado de guardar la ruta y cerrar el paseo. Sin conexión la escritura
// queda en la cola local de la base de datos y se sube sola al volver internet.
// =============================================================================

class CompleteWalkResult {
  /// true si el servidor confirmó en el momento; false si quedó en cola sin conexión.
  final bool synced;

  /// Se completa cuando el servidor confirma (de inmediato si [synced]).
  /// Da error si el servidor rechaza la escritura.
  final Future<void> whenSynced;

  const CompleteWalkResult({required this.synced, required this.whenSynced});
}
