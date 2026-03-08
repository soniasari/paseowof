import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_input.dart';
import 'package:paseowof/features/walks/domain/entities/walk.dart';
import 'controllers/walks_history_form_controller.dart';
import 'providers/walks_providers.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';

class WalksHistoryPage extends ConsumerStatefulWidget {
  const WalksHistoryPage({super.key});

  @override
  ConsumerState<WalksHistoryPage> createState() => _WalksHistoryPageState();
}

class _WalksHistoryPageState extends ConsumerState<WalksHistoryPage> {
  final TextEditingController _fechaInicioController = TextEditingController();
  final TextEditingController _fechaFinController = TextEditingController();

  @override
  void dispose() {
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    super.dispose();
  }

  Future<void> _selectFechaInicio() async {
    if (!mounted) return;
    
    final formState = ref.read(walksHistoryFormControllerProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: formState.fechaInicio ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      final controller = ref.read(walksHistoryFormControllerProvider.notifier);
      controller.setFechaInicio(picked);
      _fechaInicioController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _selectFechaFin() async {
    if (!mounted) return;
    
    final formState = ref.read(walksHistoryFormControllerProvider);
    final now = DateTime.now();
    final initialDate = formState.fechaFin ?? formState.fechaInicio ?? now;
    // Permitir seleccionar fechas futuras (hasta 1 año desde hoy)
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: formState.fechaInicio ?? now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      final controller = ref.read(walksHistoryFormControllerProvider.notifier);
      controller.setFechaFin(picked);
      _fechaFinController.text = DateFormat('dd/MM/yyyy').format(picked);
      
      // Validar y buscar automáticamente si ambas fechas están seleccionadas
      if (formState.fechaInicio != null) {
        if (picked.isBefore(formState.fechaInicio!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La fecha de fin debe ser posterior a la fecha de inicio'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        
        // Ejecutar búsqueda automáticamente
        _executeSearch();
      }
    }
  }
  
  void _executeSearch() {
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    final formState = ref.read(walksHistoryFormControllerProvider);
    if (user != null && formState.fechaInicio != null && formState.fechaFin != null) {
      ref.invalidate(walksByDateRangeProvider(
        WalksByDateRangeParams(
          paseadorId: user.uid,
          fechaInicio: formState.fechaInicio!,
          fechaFin: formState.fechaFin!,
        ),
      ));
    }
  }

  Future<void> _generatePDF(List<Walk> walks, String paseadorId) async {
    try {
      final formState = ref.read(walksHistoryFormControllerProvider);
      // Obtener información de propietarios
      final ownersAsync = ref.read(ownersListProvider(paseadorId));
      final owners = ownersAsync.value ?? [];
      
      final pdf = pw.Document();
      
      // Agregar contenido al PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Encabezado
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Historial de Paseos',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${DateFormat('dd/MM/yyyy').format(formState.fechaInicio!)} - ${DateFormat('dd/MM/yyyy').format(formState.fechaFin!)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Resumen
              pw.Text(
                'Total de paseos: ${walks.length}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Lista de paseos
              ...walks.map((walk) {
                final owner = owners.firstWhere(
                  (o) => o.id == walk.propietarioId,
                  orElse: () => Owner(
                    id: '',
                    paseadorId: '',
                    nombre: 'No encontrado',
                    ci: '',
                    telefono: '',
                    direccion: '',
                    email: '',
                    activo: true,
                    fechaRegistro: DateTime.now(),
                  ),
                );
                
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            DateFormat('dd/MM/yyyy').format(walk.fechaPaseo),
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: pw.BoxDecoration(
                              color: _getEstadoPDFColor(walk.estado),
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              walk.estado.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Horario: ${walk.horaInicio} - ${walk.horaFin ?? "N/A"}'),
                      pw.Text('Propietario: ${owner.nombre}'),
                      if (walk.direccionRecogida != null && walk.direccionRecogida!.isNotEmpty)
                        pw.Text('Dirección: ${walk.direccionRecogida}'),
                      if (walk.precio != null)
                        pw.Text(
                          'Precio: \$${walk.precio!.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ];
          },
        ),
      );
      
      // Guardar el PDF y compartirlo
      try {
        // Intentar usar printing primero
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generado exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        // Si printing falla, guardar el archivo y compartirlo
        final bytes = await pdf.save();
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/historial_paseos_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Historial de Paseos',
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generado y compartido exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  PdfColor _getEstadoPDFColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'programado':
        return PdfColors.blue;
      case 'completado':
        return PdfColors.green;
      case 'cancelado':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            text: 'Paseo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: AppColors.white,
            ),
            children: <TextSpan>[
              TextSpan(
                text: 'Woow',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.button,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'images/dog.png',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Historial de Paseos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Campo de Fecha de Inicio
                GestureDetector(
                  onTap: _selectFechaInicio,
                  child: AbsorbPointer(
                    child: AppInput(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha de Inicio',
                      controller: _fechaInicioController,
                      enabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Campo de Fecha de Fin
                GestureDetector(
                  onTap: _selectFechaFin,
                  child: AbsorbPointer(
                    child: AppInput(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha de Fin',
                      controller: _fechaFinController,
                      enabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Lista de paseos
                Consumer(
                  builder: (context, ref, child) {
                    final formStateDisplay = ref.watch(walksHistoryFormControllerProvider);
                    if (formStateDisplay.fechaInicio != null && formStateDisplay.fechaFin != null) {
                      return _buildWalksList(paseadorId);
                    } else {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Selecciona las fechas para buscar el historial',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalksList(String paseadorId) {
    final formState = ref.watch(walksHistoryFormControllerProvider);
    final walksAsync = ref.watch(walksByDateRangeProvider(
      WalksByDateRangeParams(
        paseadorId: paseadorId,
        fechaInicio: formState.fechaInicio!,
        fechaFin: formState.fechaFin!,
      ),
    ));

    return walksAsync.when(
      data: (walks) {
        if (walks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No se encontraron paseos en el rango de fechas seleccionado',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Ordenar por fecha (más recientes primero)
        final sortedWalks = List<Walk>.from(walks)
          ..sort((a, b) {
            if (a.fechaPaseo.isBefore(b.fechaPaseo)) {
              return 1;
            } else if (a.fechaPaseo.isAfter(b.fechaPaseo)) {
              return -1;
            }
            return 0;
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resultados: ${sortedWalks.length} paseo(s)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  onPressed: () => _generatePDF(sortedWalks, paseadorId),
                  icon: const Icon(Icons.picture_as_pdf),
                  color: AppColors.button,
                  tooltip: 'Generar PDF',
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedWalks.map((walk) => _buildWalkCard(walk, paseadorId)),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar el historial',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalkCard(Walk walk, String paseadorId) {
    final ownersAsync = ref.watch(ownersListProvider(paseadorId));
    final walkPetsAsync = ref.watch(walkPetsProvider(
      WalkPetsParams(paseadorId: paseadorId, walkId: walk.id),
    ));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha y estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy').format(walk.fechaPaseo),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getEstadoColor(walk.estado).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getEstadoColor(walk.estado)),
                ),
                child: Text(
                  walk.estado.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getEstadoColor(walk.estado),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horario
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 8),
              Text(
                '${walk.horaInicio} - ${walk.horaFin ?? "N/A"}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Propietario
          ownersAsync.when(
            data: (owners) {
              final owner = owners.firstWhere(
                (o) => o.id == walk.propietarioId,
                orElse: () => owners.isNotEmpty ? owners.first : Owner(
                  id: '',
                  paseadorId: '',
                  nombre: 'Propietario no encontrado',
                  ci: '',
                  telefono: '',
                  direccion: '',
                  email: '',
                  activo: true,
                  fechaRegistro: DateTime.now(),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          owner.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (walk.direccionRecogida != null && walk.direccionRecogida!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            walk.direccionRecogida!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          // Perros
          walkPetsAsync.when(
            data: (walkPets) {
              if (walkPets.isEmpty) {
                return const SizedBox.shrink();
              }
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: walkPets.map((walkPet) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pets,
                        size: 16,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        walkPet.nombreCanino,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (walk.precio != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Precio: ${walk.precio!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'programado':
        return Colors.blue;
      case 'completado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.textGrey;
    }
  }
}

