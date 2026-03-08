import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/local_notification_service.dart';

class NotificationsTestPage extends StatefulWidget {
  const NotificationsTestPage({super.key});

  @override
  State<NotificationsTestPage> createState() => _NotificationsTestPageState();
}

class _NotificationsTestPageState extends State<NotificationsTestPage> {
  final LocalNotificationService _notificationService = LocalNotificationService();
  Map<String, dynamic>? _serviceStatus;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final status = await _notificationService.getServiceStatus();
      setState(() {
        _serviceStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar estado: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _testImmediateNotification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _notificationService.showTestNotification();
      setState(() {
        _successMessage = 'Notificación de prueba enviada. Deberías verla ahora.';
        _isLoading = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al mostrar notificación: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _testScheduledNotification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _notificationService.scheduleTestNotification(seconds: 5);
      setState(() {
        _successMessage = 'Notificación programada para dentro de 5 segundos.';
        _isLoading = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
      // Recargar estado después de 6 segundos para ver la notificación programada
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          _loadStatus();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al programar notificación: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final hasPermission = await _notificationService.checkPermissions();
      setState(() {
        _successMessage = hasPermission
            ? 'Permisos de notificaciones concedidos ✓'
            : 'Permisos de notificaciones denegados ✗';
        _isLoading = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
      _loadStatus();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al verificar permisos: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prueba de Notificaciones',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mensajes de éxito/error
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),

              // Estado del servicio
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado del Servicio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_serviceStatus != null) ...[
                      _buildStatusRow(
                        'Inicializado',
                        _serviceStatus!['initialized'] ? '✓ Sí' : '✗ No',
                        _serviceStatus!['initialized'] ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow(
                        'Permisos',
                        _serviceStatus!['hasPermission'] ? '✓ Concedidos' : '✗ Denegados',
                        _serviceStatus!['hasPermission'] ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow(
                        'Notificaciones Pendientes',
                        '${_serviceStatus!['pendingNotifications']}',
                        AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botones de prueba
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pruebas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _checkPermissions,
                      icon: const Icon(Icons.security),
                      label: const Text('Verificar Permisos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testImmediateNotification,
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Probar Notificación Inmediata'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testScheduledNotification,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Probar Notificación Programada (5 seg)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loadStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar Estado'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Lista de notificaciones pendientes
              if (_serviceStatus != null &&
                  (_serviceStatus!['notifications'] as List).isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notificaciones Programadas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...(_serviceStatus!['notifications'] as List).map((notification) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['title'] ?? 'Sin título',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification['body'] ?? '',
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

