import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/pressable_card.dart';
import '../../owners_pets/presentation/pets_report_page.dart';
import '../../owners_pets/presentation/owners_report_page.dart';
import '../../owners_pets/presentation/owners_pets_report_page.dart';
import '../../walks/presentation/walks_by_client_page.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reportes',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF0A8F68),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grid de 3 opciones
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
                children: [
                  _buildReportCard(
                    context: context,
                    ref: ref,
                    cardId: 'lista_caninos',
                    icon: Icons.pets,
                    iconColor: AppColors.primary,
                    title: 'Lista de Caninos',
                    description: 'Ver todos los perros registrados.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PetsReportPage(),
                        ),
                      );
                    },
                  ),
                  _buildReportCard(
                    context: context,
                    ref: ref,
                    cardId: 'lista_propietarios',
                    icon: Icons.people,
                    iconColor: AppColors.primary,
                    title: 'Lista de Propietarios',
                    description: 'Ver todos los propietarios registrados.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OwnersReportPage(),
                        ),
                      );
                    },
                  ),
                  _buildReportCard(
                    context: context,
                    ref: ref,
                    cardId: 'propietarios_mascotas',
                    icon: Icons.group,
                    iconColor: AppColors.primary,
                    title: 'Propietarios y Mascotas',
                    description: 'Ver propietarios con sus mascotas asociadas.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OwnersPetsReportPage(),
                        ),
                      );
                    },
                  ),
                  _buildReportCard(
                    context: context,
                    ref: ref,
                    cardId: 'paseos_por_cliente',
                    icon: Icons.person_outline,
                    iconColor: AppColors.primary,
                    title: 'Paseos por Cliente',
                    description: 'Ver paseos por cliente, fecha y duración.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalksByClientPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required WidgetRef ref,
    required String cardId,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return PressableCard(
      cardId: cardId,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

