import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppInput extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final String? hint;
  final TextInputType? keyboardType;

  const AppInput({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType ?? (isPassword ? TextInputType.text : TextInputType.emailAddress),
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
          ),
            decoration: InputDecoration(
            hintText: hint,
            // Icono a la izquierda
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                icon,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            
            // Etiqueta flotante
            labelText: label,
            labelStyle: TextStyle(
              color: value.text.isEmpty
                  ? Colors.grey.shade500
                  : AppColors.button.withOpacity(0.8),
              fontSize: value.text.isEmpty ? 16 : 12,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            
            // Padding del contenido
            contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
            
            // Estilo de borde: solo línea inferior
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.button,
                width: 2.0,
              ),
            ),
            disabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.error,
                width: 1.0,
              ),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
            ),
            
            // Quitar el relleno y el comportamiento denso
            isDense: true,
          ),
        );
      },
    );
  }
}
