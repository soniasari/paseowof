import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Diálogo de confirmación para cancelar un paseo.
/// Pide motivo de cancelación (obligatorio) y notifica por [onConfirm] con el texto
/// o por [onCancel] si el usuario desiste.
class CancelWalkDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onConfirm;

  const CancelWalkDialog({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<CancelWalkDialog> createState() => _CancelWalkDialogState();
}

class _CancelWalkDialogState extends State<CancelWalkDialog> {
  late final TextEditingController _motivoController;

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar Paseo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas cancelar este paseo?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo de cancelación',
                hintText: 'Ingresa el motivo de la cancelación',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () {
            final motivoText = _motivoController.text.trim();
            if (motivoText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor, ingresa el motivo de cancelación'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            widget.onConfirm(motivoText);
          },
          child: const Text('Sí, cancelar'),
        ),
      ],
    );
  }
}
